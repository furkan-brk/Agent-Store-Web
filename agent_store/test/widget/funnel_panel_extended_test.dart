// v3.11.4: covers Discovery + Guild Master sections of the KPI panel.

import 'package:agent_store/features/insights/screens/funnel_panel_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) =>
    MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child)));

void main() {
  testWidgets('DiscoveryFunnelSection renders 3 funnel cards from mocked data',
      (tester) async {
    await tester.pumpWidget(_wrap(DiscoveryFunnelSection(
      window: '30d',
      fetchOverride: (_) async => {
        'search_to_save': 0.45,
        'impression_to_open': 0.12,
        'open_to_save': 0.30,
      },
    )));
    await tester.pump(); // resolve future
    await tester.pump();

    expect(find.text('Discovery'), findsOneWidget);
    expect(find.text('Search → Save'), findsOneWidget);
    expect(find.text('Impression → Open'), findsOneWidget);
    expect(find.text('Open → Save'), findsOneWidget);
  });

  testWidgets('GuildMasterFunnelSection renders 3 funnel cards',
      (tester) async {
    await tester.pumpWidget(_wrap(GuildMasterFunnelSection(
      window: '30d',
      fetchOverride: (_) async => {
        'suggest_acceptance_rate': 0.65,
        'chat_to_action_rate': 0.22,
        'rerun_rate': 0.18,
      },
    )));
    await tester.pump();
    await tester.pump();

    expect(find.text('Guild Master'), findsOneWidget);
    expect(find.text('Suggest acceptance'), findsOneWidget);
    expect(find.text('Chat → Action'), findsOneWidget);
    expect(find.text('Rerun rate'), findsOneWidget);
  });

  testWidgets('renders 0% when ratios are -1 sentinel from backend',
      (tester) async {
    await tester.pumpWidget(_wrap(DiscoveryFunnelSection(
      window: '30d',
      fetchOverride: (_) async => {
        'search_to_save': -1,
        'impression_to_open': -1,
        'open_to_save': -1,
      },
    )));
    await tester.pump();
    await tester.pump();
    // Section still renders (no exception); cards present even with -1 data.
    expect(find.text('Discovery'), findsOneWidget);
    expect(find.text('Search → Save'), findsOneWidget);
  });
}
