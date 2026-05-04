// Widget tests for TxTimeline.
//
// The 4-step rail is visual contract — confirmed all-green / failed
// red-X / step labels — and relatively cheap to render under
// flutter_test (no JS interop, no platform plugins). Tests pin down
// the four legs the user is most likely to see on screen.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// tx_timeline.dart re-exports TxState/TxStateX for ergonomic single-import.
import 'package:agent_store/features/agent_detail/widgets/tx_timeline.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('renders all four step labels', (tester) async {
    await tester.pumpWidget(_wrap(const TxTimeline(state: TxState.idle)));
    expect(find.text('Signed'), findsOneWidget);
    expect(find.text('Broadcast'), findsOneWidget);
    expect(find.text('Mined'), findsOneWidget);
    expect(find.text('Confirmed'), findsOneWidget);
  });

  testWidgets('signing state shows the active state label in header', (tester) async {
    await tester.pumpWidget(_wrap(
      const TxTimeline(state: TxState.signingPending),
    ));
    // Header shows the human-readable label of the active state.
    expect(find.text(TxState.signingPending.label), findsOneWidget);
  });

  testWidgets('confirmed state renders all four check marks', (tester) async {
    await tester.pumpWidget(_wrap(const TxTimeline(state: TxState.confirmed)));
    // Every step rail shows a check icon (Icons.check_rounded) — 4 total.
    expect(find.byIcon(Icons.check_rounded), findsNWidgets(4));
  });

  testWidgets('failed state shows close icon and surfaces failureReason', (tester) async {
    await tester.pumpWidget(_wrap(const TxTimeline(
      state: TxState.failed,
      failureReason: 'Backend rejected the tx hash',
    )));
    expect(find.byIcon(Icons.close_rounded), findsWidgets);
    expect(find.text('Backend rejected the tx hash'), findsOneWidget);
  });

  testWidgets('txHash row appears when a hash is provided', (tester) async {
    await tester.pumpWidget(_wrap(const TxTimeline(
      state: TxState.confirming,
      txHash: '0xabcdef0123456789feedfacecafe1234',
    )));
    // Rendered as a short hash with ellipsis between prefix and suffix.
    expect(find.byIcon(Icons.link_rounded), findsOneWidget);
    expect(find.text('Tx'), findsOneWidget);
  });
}
