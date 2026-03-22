// lib/features/legend/utils/dag_utils.dart

import '../models/workflow_models.dart';

/// Topological sort using Kahn's algorithm.
/// Returns ordered node IDs or null if cycle detected.
List<String>? topologicalSort(List<WorkflowNode> nodes, List<WorkflowEdge> edges) {
  final adj = <String, List<String>>{};
  final inDegree = <String, int>{};
  for (final n in nodes) {
    adj[n.id] = [];
    inDegree[n.id] = 0;
  }
  for (final e in edges) {
    adj[e.fromId]?.add(e.toId);
    inDegree[e.toId] = (inDegree[e.toId] ?? 0) + 1;
  }
  // BFS queue starts with 0 in-degree nodes
  final queue = <String>[];
  for (final entry in inDegree.entries) {
    if (entry.value == 0) queue.add(entry.key);
  }
  final order = <String>[];
  while (queue.isNotEmpty) {
    final current = queue.removeAt(0);
    order.add(current);
    for (final neighbor in adj[current] ?? []) {
      inDegree[neighbor] = (inDegree[neighbor] ?? 1) - 1;
      if (inDegree[neighbor] == 0) queue.add(neighbor);
    }
  }
  return order.length == nodes.length ? order : null;
}

/// Detect workflow type based on graph structure.
/// "sequential" = linear chain, "parallel" = fan-out, "hierarchical" = mixed
String detectWorkflowType(List<WorkflowNode> nodes, List<WorkflowEdge> edges) {
  final successorCount = <String, int>{};
  final predecessorCount = <String, int>{};
  for (final e in edges) {
    successorCount[e.fromId] = (successorCount[e.fromId] ?? 0) + 1;
    predecessorCount[e.toId] = (predecessorCount[e.toId] ?? 0) + 1;
  }

  bool hasFanOut = successorCount.values.any((c) => c > 1);
  bool hasFanIn = predecessorCount.values.any((c) => c > 1);

  if (!hasFanOut && !hasFanIn) return 'sequential';
  if (hasFanOut && !hasFanIn) return 'parallel';
  return 'hierarchical';
}

/// Get ordered agent nodes (excluding start/end) in topological order.
List<WorkflowNode> getOrderedAgentNodes(List<WorkflowNode> nodes, List<WorkflowEdge> edges) {
  final order = topologicalSort(nodes, edges);
  if (order == null) return [];
  final nodeMap = {for (final n in nodes) n.id: n};
  return order
      .map((id) => nodeMap[id])
      .where((n) => n != null && n.type != WorkflowNodeType.start && n.type != WorkflowNodeType.end)
      .cast<WorkflowNode>()
      .toList();
}
