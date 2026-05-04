// Unit tests for the v3.7 purchase tx state machine.
//
// The widget itself is web-only (uses package:web for the explorer link),
// but TxState + TxStateX are pure Dart and are the load-bearing piece of
// the state machine — every UI decision (button enabled, pill colour,
// icon, label) is derived from these. Locking them down here means the
// AgentDetailController tests don't need to render widgets to verify
// behaviour transitions.

import 'package:flutter_test/flutter_test.dart';
import 'package:agent_store/features/agent_detail/widgets/tx_state.dart';

void main() {
  group('TxState.isInFlight', () {
    test('idle / confirmed / failed are NOT in flight', () {
      // These three are the "user can act now" states — buttons must enable.
      expect(TxState.idle.isInFlight, isFalse);
      expect(TxState.confirmed.isInFlight, isFalse);
      expect(TxState.failed.isInFlight, isFalse);
    });

    test('signingPending / txPending / confirming ARE in flight', () {
      // These three suppress repeat clicks — multi-click during a tx must
      // not spawn a second wallet popup or duplicate backend reconcile call.
      expect(TxState.signingPending.isInFlight, isTrue);
      expect(TxState.txPending.isInFlight, isTrue);
      expect(TxState.confirming.isInFlight, isTrue);
    });
  });

  group('TxState.label', () {
    test('every state has a non-empty label', () {
      // Empty labels would render an invisible pill — guard against silent
      // copy regressions when adding new states.
      for (final s in TxState.values) {
        expect(s.label, isNotEmpty, reason: '${s.name} must have a user-facing label');
      }
    });

    test('idle reads as "Purchase"', () {
      // The idle label is what the button shows pre-click; the screen
      // overrides it with the price-bearing variant, but the bare default
      // is still expected to be a purchase verb.
      expect(TxState.idle.label, 'Purchase');
    });

    test('failed label hints at retry', () {
      // The failure pill must communicate that the action is recoverable —
      // "Failed" alone is dead-end; "Failed — retry" sets expectation.
      expect(TxState.failed.label.toLowerCase(), contains('retry'));
    });
  });

  group('TxState.pillColor', () {
    test('every state has a pill colour', () {
      // Defensive: enum extension shouldn't throw on any value.
      for (final s in TxState.values) {
        expect(() => s.pillColor, returnsNormally);
      }
    });

    test('confirmed and failed use distinct colours', () {
      // Same colour for success + error would be a colour-blindness trap.
      expect(TxState.confirmed.pillColor, isNot(equals(TxState.failed.pillColor)));
    });
  });

  group('TxState.icon', () {
    test('every state has a Material icon', () {
      for (final s in TxState.values) {
        expect(() => s.icon, returnsNormally);
      }
    });
  });
}
