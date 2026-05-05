// lib/features/legend/models/workflow_models.dart

import 'package:flutter/foundation.dart';

enum WorkflowNodeType { start, agent, mission, guild, end }

extension WorkflowNodeTypeX on WorkflowNodeType {
  String get label {
    switch (this) {
      case WorkflowNodeType.start:   return 'START';
      case WorkflowNodeType.agent:   return 'Agent';
      case WorkflowNodeType.mission: return 'Mission';
      case WorkflowNodeType.guild:   return 'Guild';
      case WorkflowNodeType.end:     return 'END';
    }
  }
}

class WorkflowNode {
  final String id;
  final WorkflowNodeType type;
  final String label;
  double x;
  double y;
  /// For agent nodes: agentId as string. For mission nodes: mission slug.
  final String? refId;
  final Map<String, dynamic>? metadata;

  WorkflowNode({
    required this.id,
    required this.type,
    required this.label,
    required this.x,
    required this.y,
    this.refId,
    this.metadata,
  });

  WorkflowNode copyWith({String? label, double? x, double? y, Map<String, dynamic>? metadata}) => WorkflowNode(
    id: id,
    type: type,
    label: label ?? this.label,
    x: x ?? this.x,
    y: y ?? this.y,
    refId: refId,
    metadata: metadata ?? this.metadata,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'label': label,
    'x': x,
    'y': y,
    'ref_id': refId,
    if (metadata != null) 'metadata': metadata,
  };

  factory WorkflowNode.fromJson(Map<String, dynamic> j) => WorkflowNode(
    id: j['id'] as String? ?? '',
    type: WorkflowNodeType.values.firstWhere(
      (t) => t.name == j['type'],
      orElse: () => WorkflowNodeType.agent,
    ),
    label: j['label'] as String? ?? '',
    x: (j['x'] as num?)?.toDouble() ?? 0,
    y: (j['y'] as num?)?.toDouble() ?? 0,
    refId: j['ref_id'] as String?,
    metadata: (j['metadata'] as Map<String, dynamic>?),
  );
}

class WorkflowEdge {
  final String id;
  final String fromId;
  final String toId;
  final String? label;

  const WorkflowEdge({
    required this.id,
    required this.fromId,
    required this.toId,
    this.label,
  });

  WorkflowEdge copyWith({String? label}) => WorkflowEdge(
        id: id,
        fromId: fromId,
        toId: toId,
        label: label ?? this.label,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'from': fromId,
        'to': toId,
        if (label != null && label!.isNotEmpty) 'label': label,
      };

  factory WorkflowEdge.fromJson(Map<String, dynamic> j) => WorkflowEdge(
        id: j['id'] as String? ?? '',
        fromId: j['from'] as String? ?? '',
        toId: j['to'] as String? ?? '',
        label: j['label'] as String?,
      );
}

class LegendWorkflow {
  final String id;
  String name;
  final List<WorkflowNode> nodes;
  final List<WorkflowEdge> edges;
  final DateTime updatedAt;

  /// Server-issued optimistic-concurrency revision. Bumped on every successful
  /// PATCH/POST. Defaults to 0 for newly-created local workflows that haven't
  /// hit the backend yet — backend treats 0 as "no If-Match" (last-write-wins).
  final int revisionId;

  LegendWorkflow({
    required this.id,
    required this.name,
    required this.nodes,
    required this.edges,
    required this.updatedAt,
    this.revisionId = 0,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'nodes': nodes.map((n) => n.toJson()).toList(),
    'edges': edges.map((e) => e.toJson()).toList(),
    'updated_at': updatedAt.toUtc().toIso8601String(),
    'revision_id': revisionId,
  };

  factory LegendWorkflow.fromJson(Map<String, dynamic> j) {
    final nodes = <WorkflowNode>[];
    for (final raw in (j['nodes'] as List<dynamic>? ?? [])) {
      try {
        nodes.add(WorkflowNode.fromJson(raw as Map<String, dynamic>));
      } catch (e) {
        debugPrint('[LegendWorkflow] skipping bad node: $e');
      }
    }
    final edges = <WorkflowEdge>[];
    for (final raw in (j['edges'] as List<dynamic>? ?? [])) {
      try {
        final edge = WorkflowEdge.fromJson(raw as Map<String, dynamic>);
        if (edge.fromId.isNotEmpty && edge.toId.isNotEmpty) {
          edges.add(edge);
        } else {
          debugPrint('[LegendWorkflow] skipping edge with empty from/to: ${edge.id}');
        }
      } catch (e) {
        debugPrint('[LegendWorkflow] skipping bad edge: $e');
      }
    }
    return LegendWorkflow(
      id: j['id'] as String? ?? '',
      name: j['name'] as String? ?? 'Untitled',
      nodes: nodes,
      edges: edges,
      updatedAt: DateTime.tryParse(j['updated_at'] as String? ?? '') ?? DateTime.now(),
      revisionId: (j['revision_id'] as num?)?.toInt() ?? 0,
    );
  }

  LegendWorkflow copyWithNodes(
          List<WorkflowNode> nodes, List<WorkflowEdge> edges) =>
      LegendWorkflow(
        id: id,
        name: name,
        nodes: nodes,
        edges: edges,
        updatedAt: DateTime.now(),
        revisionId: revisionId,
      );

  /// Returns a copy with [revisionId] overridden — used when reconciling a
  /// successful save response or after a take-theirs conflict resolution.
  LegendWorkflow withRevisionId(int newRevision) => LegendWorkflow(
        id: id,
        name: name,
        nodes: nodes,
        edges: edges,
        updatedAt: updatedAt,
        revisionId: newRevision,
      );
}

// ── Execution Models ────────────────────────────────────────────────────────

class NodeExecutionResult {
  final String nodeId;
  final String nodeType;
  final String nodeLabel;
  final String input;
  final String output;
  final int? agentId;
  final int durationMs;
  final String? error;

  const NodeExecutionResult({
    required this.nodeId,
    required this.nodeType,
    required this.nodeLabel,
    required this.input,
    required this.output,
    this.agentId,
    required this.durationMs,
    this.error,
  });

  factory NodeExecutionResult.fromJson(Map<String, dynamic> j) =>
      NodeExecutionResult(
        nodeId: j['node_id'] as String? ?? '',
        nodeType: j['node_type'] as String? ?? '',
        nodeLabel: j['node_label'] as String? ?? '',
        input: j['input'] as String? ?? '',
        output: j['output'] as String? ?? '',
        agentId: j['agent_id'] as int?,
        durationMs: j['duration_ms'] as int? ?? 0,
        error: j['error'] as String?,
      );

  bool get hasError => error != null && error!.isNotEmpty;
}

class WorkflowExecution {
  final int id;
  final String workflowId;
  final String workflowName;
  final String status;
  final String inputMessage;
  final String finalOutput;
  final List<NodeExecutionResult> nodeResults;
  final int totalNodes;
  final int completedNodes;
  final int creditsUsed;
  final String? errorMessage;
  final DateTime startedAt;
  final DateTime? finishedAt;

  const WorkflowExecution({
    required this.id,
    required this.workflowId,
    required this.workflowName,
    required this.status,
    required this.inputMessage,
    required this.finalOutput,
    required this.nodeResults,
    required this.totalNodes,
    required this.completedNodes,
    required this.creditsUsed,
    this.errorMessage,
    required this.startedAt,
    this.finishedAt,
  });

  factory WorkflowExecution.fromJson(Map<String, dynamic> j) =>
      WorkflowExecution(
        id: j['id'] as int? ?? 0,
        workflowId: j['workflow_id'] as String? ?? '',
        workflowName: j['workflow_name'] as String? ?? '',
        status: j['status'] as String? ?? 'unknown',
        inputMessage: j['input_message'] as String? ?? '',
        finalOutput: j['final_output'] as String? ?? '',
        nodeResults: (j['node_results'] as List<dynamic>? ?? [])
            .map((e) =>
                NodeExecutionResult.fromJson(e as Map<String, dynamic>))
            .toList(),
        totalNodes: j['total_nodes'] as int? ?? 0,
        completedNodes: j['completed_nodes'] as int? ?? 0,
        creditsUsed: j['credits_used'] as int? ?? 0,
        errorMessage: j['error_message'] as String?,
        startedAt: DateTime.tryParse(j['started_at'] as String? ?? '') ??
            DateTime.now(),
        finishedAt: j['finished_at'] != null
            ? DateTime.tryParse(j['finished_at'] as String)
            : null,
      );

  bool get isCompleted => status == 'completed';
  bool get isFailed => status == 'failed';
  bool get isRunning => status == 'running';

  Duration? get duration =>
      finishedAt?.difference(startedAt);
}
