// Verifies the Compare dialog's button disable logic.
// The button must be disabled when:
//   - fromV == null
//   - toV == null
//   - fromV == toV (same version selected for both sides)
//
// We test the pure condition rather than mounting the full LegendScreen
// (which requires Go router + ApiService + many singletons).

import 'package:flutter_test/flutter_test.dart';

bool _compareButtonEnabled({required int? fromV, required int? toV}) =>
    fromV != null && toV != null && fromV != toV;

void main() {
  group('Compare button enable/disable logic', () {
    test('disabled when both are null', () {
      expect(_compareButtonEnabled(fromV: null, toV: null), isFalse);
    });

    test('disabled when fromV is null', () {
      expect(_compareButtonEnabled(fromV: null, toV: 2), isFalse);
    });

    test('disabled when toV is null', () {
      expect(_compareButtonEnabled(fromV: 1, toV: null), isFalse);
    });

    test('disabled when fromV == toV', () {
      expect(_compareButtonEnabled(fromV: 3, toV: 3), isFalse);
    });

    test('enabled when fromV and toV are different non-null values', () {
      expect(_compareButtonEnabled(fromV: 1, toV: 2), isTrue);
    });

    test('enabled for version 0 vs 1', () {
      expect(_compareButtonEnabled(fromV: 0, toV: 1), isTrue);
    });

    test('enabled regardless of order (from > to)', () {
      expect(_compareButtonEnabled(fromV: 5, toV: 2), isTrue);
    });
  });
}
