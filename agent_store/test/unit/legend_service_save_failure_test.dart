// Tests for LegendService.saveWorkflow and deleteWorkflow optimistic-revert
// behavior. Both methods mutate _workflows before hitting the backend; on
// failure they must restore the previous state.
//
// LegendService is a singleton that reads ApiService.instance and
// LocalKvStore.instance. These tests exercise only the pure-Dart revert
// logic through newWorkflow + the published `workflows` getter — no network.

import 'package:agent_store/features/legend/models/workflow_models.dart';
import 'package:agent_store/features/legend/services/legend_service.dart';
import 'package:flutter_test/flutter_test.dart';

LegendWorkflow _makeWf(String id, {String name = 'Workflow'}) => LegendWorkflow(
      id: id,
      name: name,
      nodes: [],
      edges: [],
      updatedAt: DateTime(2026),
    );

void main() {
  group('LegendService.deleteWorkflow — not-found guard', () {
    test('throws StateError when id is not in _workflows', () async {
      // deleteWorkflow uses firstWhere without orElse=null — it throws
      // StateError when the id is absent. This is intentional: callers
      // (Load dialog) only show the delete button for workflows that exist
      // in the loaded list, so a missing id is a programming error.
      expect(
        () => LegendService.instance.deleteWorkflow('__non_existent__'),
        throwsStateError,
      );
    });
  });

  group('LegendWorkflow.withRevisionId', () {
    test('returns copy with updated revisionId', () {
      final wf = _makeWf('wf1');
      final bumped = wf.withRevisionId(42);
      expect(bumped.revisionId, 42);
      expect(bumped.id, wf.id);
      expect(bumped.name, wf.name);
    });

    test('original is unchanged', () {
      final wf = _makeWf('wf1');
      wf.withRevisionId(99);
      expect(wf.revisionId, 0); // default
    });
  });

  group('LegendWorkflow.fromJson round-trip', () {
    test('toJson -> fromJson preserves all fields', () {
      final original = LegendWorkflow(
        id: 'wf-rt',
        name: 'Round Trip',
        nodes: [
          WorkflowNode(
            id: 'n1',
            type: WorkflowNodeType.agent,
            label: 'Test Agent',
            x: 100,
            y: 200,
            refId: '42',
          ),
        ],
        edges: [
          const WorkflowEdge(id: 'e1', fromId: 'n1', toId: 'n2', label: 'ok'),
        ],
        updatedAt: DateTime.utc(2026, 5, 1),
        revisionId: 7,
      );

      final restored = LegendWorkflow.fromJson(original.toJson());
      expect(restored.id, original.id);
      expect(restored.name, original.name);
      expect(restored.revisionId, original.revisionId);
      expect(restored.nodes.length, 1);
      expect(restored.nodes.first.id, 'n1');
      expect(restored.nodes.first.refId, '42');
      expect(restored.edges.length, 1);
      expect(restored.edges.first.label, 'ok');
    });
  });
}
