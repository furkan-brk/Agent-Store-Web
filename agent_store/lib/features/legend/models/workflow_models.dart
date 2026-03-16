// lib/features/legend/models/workflow_models.dart

enum WorkflowNodeType { start, agent, mission, end }

extension WorkflowNodeTypeX on WorkflowNodeType {
  String get label {
    switch (this) {
      case WorkflowNodeType.start:   return 'START';
      case WorkflowNodeType.agent:   return 'Agent';
      case WorkflowNodeType.mission: return 'Mission';
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

  WorkflowNode({
    required this.id,
    required this.type,
    required this.label,
    required this.x,
    required this.y,
    this.refId,
  });

  WorkflowNode copyWith({String? label, double? x, double? y}) => WorkflowNode(
    id: id,
    type: type,
    label: label ?? this.label,
    x: x ?? this.x,
    y: y ?? this.y,
    refId: refId,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'label': label,
    'x': x,
    'y': y,
    'ref_id': refId,
  };

  factory WorkflowNode.fromJson(Map<String, dynamic> j) => WorkflowNode(
    id: j['id'] as String,
    type: WorkflowNodeType.values.firstWhere(
      (t) => t.name == j['type'],
      orElse: () => WorkflowNodeType.agent,
    ),
    label: j['label'] as String? ?? '',
    x: (j['x'] as num?)?.toDouble() ?? 0,
    y: (j['y'] as num?)?.toDouble() ?? 0,
    refId: j['ref_id'] as String?,
  );
}

class WorkflowEdge {
  final String id;
  final String fromId;
  final String toId;

  const WorkflowEdge({
    required this.id,
    required this.fromId,
    required this.toId,
  });

  Map<String, dynamic> toJson() => {'id': id, 'from': fromId, 'to': toId};

  factory WorkflowEdge.fromJson(Map<String, dynamic> j) => WorkflowEdge(
    id: j['id'] as String,
    fromId: j['from'] as String,
    toId: j['to'] as String,
  );
}

class LegendWorkflow {
  final String id;
  String name;
  final List<WorkflowNode> nodes;
  final List<WorkflowEdge> edges;
  final DateTime updatedAt;

  LegendWorkflow({
    required this.id,
    required this.name,
    required this.nodes,
    required this.edges,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'nodes': nodes.map((n) => n.toJson()).toList(),
    'edges': edges.map((e) => e.toJson()).toList(),
    'updated_at': updatedAt.toIso8601String(),
  };

  factory LegendWorkflow.fromJson(Map<String, dynamic> j) => LegendWorkflow(
    id: j['id'] as String,
    name: j['name'] as String? ?? 'Untitled',
    nodes: (j['nodes'] as List<dynamic>? ?? [])
        .map((n) => WorkflowNode.fromJson(n as Map<String, dynamic>))
        .toList(),
    edges: (j['edges'] as List<dynamic>? ?? [])
        .map((e) => WorkflowEdge.fromJson(e as Map<String, dynamic>))
        .toList(),
    updatedAt:
        DateTime.tryParse(j['updated_at'] as String? ?? '') ?? DateTime.now(),
  );

  LegendWorkflow copyWithNodes(
          List<WorkflowNode> nodes, List<WorkflowEdge> edges) =>
      LegendWorkflow(
        id: id,
        name: name,
        nodes: nodes,
        edges: edges,
        updatedAt: DateTime.now(),
      );
}
