// Unit tests for BulkSelectState (v3.11.3 — T10).
//
// The state machine is the wire between the Library UI's "Select" toggle
// and the bottom action bar. Test the public surface so the visual
// integration can lean on these guarantees.

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_store/shared/state/bulk_select_state.dart';

void main() {
  test('starts inactive with an empty selection', () {
    final s = BulkSelectState();
    expect(s.isActive, isFalse);
    expect(s.selectedCount, 0);
    expect(s.isSelected(1), isFalse);
  });

  test('toggle adds to and removes from the selection set', () {
    final s = BulkSelectState();
    s.toggle(7);
    expect(s.isActive, isTrue);
    expect(s.isSelected(7), isTrue);
    expect(s.selectedCount, 1);
    s.toggle(7);
    expect(s.isSelected(7), isFalse);
    expect(s.selectedCount, 0);
  });

  test('selectAll fills the set and exit clears it back to empty', () {
    final s = BulkSelectState()..selectAll([1, 2, 3, 4]);
    expect(s.selectedCount, 4);
    expect(s.selectedIds.contains(2), isTrue);
    s.exit();
    expect(s.isActive, isFalse);
    expect(s.selectedCount, 0);
  });
}
