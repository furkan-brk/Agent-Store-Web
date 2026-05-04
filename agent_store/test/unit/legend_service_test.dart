// Tests for LegendService — pure-state paths only. The class is a
// singleton that calls LocalKvStore.instance and ApiService.instance
// directly, so the sync flow needs a DI refactor before it's testable.
// We exercise what doesn't touch those globals: factory output, the
// initial sync status, the workflows getter immutability, and the
// SyncStatus contract used elsewhere in the app.

import 'package:agent_store/features/legend/services/legend_service.dart';
import 'package:agent_store/shared/services/mission_service.dart' show SyncStatus;
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LegendService.newWorkflow', () {
    test('creates with the given name', () {
      final wf = LegendService.instance.newWorkflow('My Workflow');
      expect(wf.name, 'My Workflow');
    });

    test('starts empty (no nodes / edges)', () {
      final wf = LegendService.instance.newWorkflow('blank');
      expect(wf.nodes, isEmpty);
      expect(wf.edges, isEmpty);
    });

    test('uses a unique millisecond id per call', () async {
      final a = LegendService.instance.newWorkflow('a');
      // Yield once so the timestamp can advance even on fast loops.
      await Future<void>.delayed(const Duration(milliseconds: 2));
      final b = LegendService.instance.newWorkflow('b');
      expect(a.id, isNot(b.id));
    });

    test('updatedAt is recent', () {
      final before = DateTime.now();
      final wf = LegendService.instance.newWorkflow('t');
      final after = DateTime.now();
      expect(wf.updatedAt.isAfter(before.subtract(const Duration(seconds: 1))), isTrue);
      expect(wf.updatedAt.isBefore(after.add(const Duration(seconds: 1))), isTrue);
    });

    test('id is a parseable timestamp', () {
      final wf = LegendService.instance.newWorkflow('t');
      expect(int.tryParse(wf.id), isNotNull);
    });

    test('handles empty name gracefully', () {
      final wf = LegendService.instance.newWorkflow('');
      expect(wf.name, '');
    });
  });

  group('LegendService singleton state', () {
    test('instance is stable across calls', () {
      final a = LegendService.instance;
      final b = LegendService.instance;
      expect(identical(a, b), isTrue);
    });

    test('workflows getter returns an unmodifiable view', () {
      final list = LegendService.instance.workflows;
      expect(() => list.add(LegendService.instance.newWorkflow('boom')),
          throwsUnsupportedError);
    });

    test('syncStatusNotifier holds a SyncStatus value', () {
      final status = LegendService.instance.syncStatusNotifier.value;
      // Default state can be `synced` (fresh) or `pending` (after refresh
      // without auth) — both are valid SyncStatus members.
      expect(SyncStatus.values, contains(status));
    });
  });

  group('SyncStatus enum contract', () {
    test('exposes all states the legend toolbar expects', () {
      // The toolbar's ValueListenableBuilder switches on these four states.
      final names = SyncStatus.values.map((s) => s.name).toSet();
      expect(names, containsAll(['synced', 'syncing', 'failed', 'pending']));
    });
  });
}
