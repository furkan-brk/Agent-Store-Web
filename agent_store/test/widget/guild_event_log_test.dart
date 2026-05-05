// v3.11.4: covers GuildEventLog rendering paths via fetchOverride seam.

import 'package:agent_store/features/guild/widgets/guild_event_log.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(child: child),
      ),
    );

void main() {
  testWidgets('renders rows with truncated wallet + event label',
      (tester) async {
    await tester.pumpWidget(_wrap(GuildEventLog(
      guildId: 7,
      fetchOverride: () async => [
        {
          'wallet': '0xabcdef1234567890abcdef',
          'event_type': 'joined',
          'created_at': DateTime.now().toIso8601String(),
        },
        {
          'wallet': '0xfeedface',
          'event_type': 'left',
          'created_at': DateTime.now().toIso8601String(),
        },
      ],
    )));
    await tester.pump(); // resolve future
    await tester.pump();

    expect(find.textContaining('joined the guild'), findsOneWidget);
    expect(find.textContaining('left the guild'), findsOneWidget);
  });

  testWidgets('renders empty-state copy when fetch returns []',
      (tester) async {
    await tester.pumpWidget(_wrap(GuildEventLog(
      guildId: 7,
      fetchOverride: () async => const <Map<String, dynamic>>[],
    )));
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('No activity yet'), findsOneWidget);
  });
}
