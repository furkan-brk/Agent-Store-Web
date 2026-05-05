// v3.11.4: covers AchievementSection backend-driven badge rendering.

import 'package:agent_store/features/profile/widgets/achievement_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

void main() {
  testWidgets('renders unlocked badges and dimmed locked ones',
      (tester) async {
    await tester.pumpWidget(_wrap(AchievementSection(
      wallet: '0xowner',
      fetchOverride: (_) async => [
        {'type': 'first_agent', 'wallet': '0xowner', 'earned_at': 'x'},
        {'type': 'first_fork',  'wallet': '0xowner', 'earned_at': 'x'},
      ],
    )));
    await tester.pump();
    await tester.pump();

    // AchievementRow renders the "X / Y unlocked" pill — verify count.
    expect(find.textContaining('2 / 5 unlocked'), findsOneWidget);
  });

  testWidgets('shows empty hint when wallet has no badges',
      (tester) async {
    await tester.pumpWidget(_wrap(AchievementSection(
      wallet: '0xfresh',
      fetchOverride: (_) async => const <Map<String, dynamic>>[],
    )));
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('No achievements yet'), findsOneWidget);
  });
}
