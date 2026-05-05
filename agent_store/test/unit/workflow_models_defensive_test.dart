// Tests for defensive parsing in workflow_models.dart.
// Verifies that single bad nodes/edges are skipped rather than tanking the
// entire workflow parse, and that null id fields fall back to ''.

import 'package:agent_store/features/legend/models/workflow_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WorkflowNode.fromJson defensive parsing', () {
    test('null id falls back to empty string', () {
      final node = WorkflowNode.fromJson({'id': null, 'type': 'agent', 'x': 0, 'y': 0});
      expect(node.id, '');
    });

    test('missing id field falls back to empty string', () {
      final node = WorkflowNode.fromJson({'type': 'agent', 'x': 0, 'y': 0});
      expect(node.id, '');
    });

    test('unknown type defaults to agent', () {
      final node = WorkflowNode.fromJson({'id': 'n1', 'type': 'unknown_xyz', 'x': 0, 'y': 0});
      expect(node.type, WorkflowNodeType.agent);
    });
  });

  group('WorkflowEdge.fromJson defensive parsing', () {
    test('null id falls back to empty string', () {
      final edge = WorkflowEdge.fromJson({'id': null, 'from': 'a', 'to': 'b'});
      expect(edge.id, '');
    });

    test('null from falls back to empty string', () {
      final edge = WorkflowEdge.fromJson({'id': 'e1', 'from': null, 'to': 'b'});
      expect(edge.fromId, '');
    });

    test('null to falls back to empty string', () {
      final edge = WorkflowEdge.fromJson({'id': 'e1', 'from': 'a', 'to': null});
      expect(edge.toId, '');
    });
  });

  group('LegendWorkflow.fromJson — skip bad nodes/edges', () {
    test('single bad node is skipped, rest parse successfully', () {
      final json = {
        'id': 'wf1',
        'name': 'Test',
        'nodes': [
          {'id': 'n1', 'type': 'agent', 'x': 0.0, 'y': 0.0},
          42, // invalid — not a Map
          {'id': 'n2', 'type': 'start', 'x': 100.0, 'y': 0.0},
        ],
        'edges': <dynamic>[],
        'updated_at': '2026-01-01T00:00:00Z',
      };
      final wf = LegendWorkflow.fromJson(json);
      expect(wf.nodes.length, 2);
      expect(wf.nodes.map((n) => n.id), containsAll(['n1', 'n2']));
    });

    test('edge with empty fromId is skipped', () {
      final json = {
        'id': 'wf2',
        'name': 'Test',
        'nodes': <dynamic>[],
        'edges': [
          {'id': 'e1', 'from': 'n1', 'to': 'n2'},
          {'id': 'e2', 'from': '', 'to': 'n2'},  // empty from — should skip
          {'id': 'e3', 'from': 'n1', 'to': ''},  // empty to — should skip
        ],
        'updated_at': '2026-01-01T00:00:00Z',
      };
      final wf = LegendWorkflow.fromJson(json);
      expect(wf.edges.length, 1);
      expect(wf.edges.first.id, 'e1');
    });

    test('entirely invalid edge entry is skipped without throwing', () {
      final json = {
        'id': 'wf3',
        'name': 'Test',
        'nodes': <dynamic>[],
        'edges': [
          {'id': 'e1', 'from': 'n1', 'to': 'n2'},
          'not-a-map',  // will fail cast — should be skipped
        ],
        'updated_at': '2026-01-01T00:00:00Z',
      };
      expect(() => LegendWorkflow.fromJson(json), returnsNormally);
      final wf = LegendWorkflow.fromJson(json);
      // Only the valid edge parsed; the bad string entry is skipped.
      expect(wf.edges.length, 1);
    });

    test('null id on workflow falls back to empty string', () {
      final json = {
        'id': null,
        'name': 'No ID',
        'nodes': <dynamic>[],
        'edges': <dynamic>[],
        'updated_at': '2026-01-01T00:00:00Z',
      };
      final wf = LegendWorkflow.fromJson(json);
      expect(wf.id, '');
    });

    test('completely empty nodes/edges lists parse fine', () {
      final json = {
        'id': 'wf4',
        'name': 'Empty',
        'nodes': <dynamic>[],
        'edges': <dynamic>[],
        'updated_at': '2026-01-01T00:00:00Z',
      };
      final wf = LegendWorkflow.fromJson(json);
      expect(wf.nodes, isEmpty);
      expect(wf.edges, isEmpty);
    });
  });
}
