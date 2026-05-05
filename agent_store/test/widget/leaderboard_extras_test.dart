// v3.11.4: covers CategoryLeaderboardSection / YouAreHereRail / WeeklyRewardsList
// render contracts via fetchOverride seams.

import 'package:agent_store/features/leaderboard/widgets/leaderboard_extras.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(
        body: SizedBox(width: 1000, child: SingleChildScrollView(child: child)),
      ),
    );

void main() {
  testWidgets('CategoryLeaderboardSection renders rows from mocked fetch',
      (tester) async {
    await tester.pumpWidget(_wrap(CategoryLeaderboardSection(
      fetchOverride: (cat, win) async => [
        {'rank': 1, 'wallet': '0xa', 'total_saves': 200, 'total_agents': 5},
        {'rank': 2, 'wallet': '0xb', 'total_saves': 150, 'total_agents': 3},
      ],
    )));
    await tester.pump();
    await tester.pump();
    expect(find.text('Top by category'), findsOneWidget);
    expect(find.textContaining('200 saves'), findsOneWidget);
    expect(find.textContaining('150 saves'), findsOneWidget);
  });

  testWidgets('YouAreHereRail renders rank pill + neighbors',
      (tester) async {
    await tester.pumpWidget(_wrap(YouAreHereRail(
      fetchOverride: (_) async => {
        'rank': 7,
        'total_creators': 42,
        'window': 'all',
        'neighbors': [
          {'rank': 5, 'wallet': '0xother1', 'total_saves': 80, 'is_me': false},
          {'rank': 6, 'wallet': '0xother2', 'total_saves': 70, 'is_me': false},
          {'rank': 7, 'wallet': '0xme', 'total_saves': 60, 'is_me': true},
          {'rank': 8, 'wallet': '0xother3', 'total_saves': 50, 'is_me': false},
          {'rank': 9, 'wallet': '0xother4', 'total_saves': 40, 'is_me': false},
        ],
      },
    )));
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('Your rank: #7 of 42'), findsOneWidget);
    expect(find.textContaining('You ·'), findsOneWidget,
        reason: 'me row should be prefixed with "You ·"');
  });

  testWidgets('WeeklyRewardsList groups rewards by week newest-first',
      (tester) async {
    await tester.pumpWidget(_wrap(WeeklyRewardsList(
      fetchOverride: (_) async => [
        {'week': '2026-W18', 'rank': 1, 'wallet': '0xa', 'credits': 100},
        {'week': '2026-W18', 'rank': 2, 'wallet': '0xb', 'credits': 50},
        {'week': '2026-W17', 'rank': 1, 'wallet': '0xc', 'credits': 100},
      ],
    )));
    await tester.pump();
    await tester.pump();
    expect(find.text('2026-W18'), findsOneWidget);
    expect(find.text('2026-W17'), findsOneWidget);
    expect(find.textContaining('+100 credits'), findsAtLeastNWidgets(2));
  });

  testWidgets('YouAreHereRail shows "Not ranked" when rank is 0',
      (tester) async {
    await tester.pumpWidget(_wrap(YouAreHereRail(
      fetchOverride: (_) async => {
        'rank': 0,
        'total_creators': 42,
        'neighbors': [],
      },
    )));
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('Not ranked yet'), findsOneWidget);
  });
}
