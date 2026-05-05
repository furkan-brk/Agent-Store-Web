// Widget tests for FunnelPanelScreen (v3.11.3 — T11).
//
// Uses the screen's `fetchOverride` test seam to inject canned KPI data
// and pin the FunnelCard rendering, the window selector state, and the
// empty-state fallback.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_store/features/insights/screens/funnel_panel_screen.dart';

Widget _wrap(Widget child) => MaterialApp(home: child);

void main() {
  testWidgets('renders four funnel cards with the seeded percentages',
      (tester) async {
    await tester.pumpWidget(_wrap(FunnelPanelScreen(
      fetchOverride: (window) async => {
        'suggest_to_execute': 0.42,
        'edit_to_publish': 0.78,
        'publish_to_first_save': 0.15,
        'trial_to_purchase': 0.09,
      },
    )));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));

    expect(find.text('Suggest → Execute'), findsOneWidget);
    expect(find.text('Edit → Publish'), findsOneWidget);
    expect(find.text('Publish → First Save'), findsOneWidget);
    expect(find.text('Trial → Purchase'), findsOneWidget);
    // 0.42 → 42%
    expect(find.text('42%'), findsOneWidget);
    // 0.78 → 78%
    expect(find.text('78%'), findsOneWidget);
  });

  testWidgets('window selector flips selected chip when tapped',
      (tester) async {
    var lastWindow = '30d';
    await tester.pumpWidget(_wrap(FunnelPanelScreen(
      fetchOverride: (window) async {
        lastWindow = window;
        return {'suggest_to_execute': 0.5};
      },
    )));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
    expect(lastWindow, '30d');
    // 7 Days chip
    await tester.tap(find.text('7 Days'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
    expect(lastWindow, '7d');
  });

  testWidgets('null backend response renders the empty state', (tester) async {
    await tester.pumpWidget(_wrap(FunnelPanelScreen(
      fetchOverride: (_) async => null,
    )));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
    expect(find.text('No KPI data yet'), findsOneWidget);
  });
}
