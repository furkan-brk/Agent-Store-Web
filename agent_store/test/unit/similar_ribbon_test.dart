// Tests for SimilarAgentsRibbon — focuses on the load/empty/error contract
// rather than the visual AgentCard render. AgentCard's hover animations
// never settle in the test scheduler, so we verify the ribbon's *header*
// row instead, which is enough to prove the loaded path took.

import 'package:agent_store/features/agent_detail/widgets/similar_agents_ribbon.dart';
import 'package:agent_store/features/character/character_types.dart';
import 'package:agent_store/shared/models/agent_model.dart';
import 'package:agent_store/shared/widgets/skeleton_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

AgentModel _makeAgent(int id, String title) => AgentModel(
      id: id,
      title: title,
      description: 'd',
      prompt: '',
      category: 'general',
      creatorWallet: '0x',
      characterType: CharacterType.bard,
      subclass: CharacterSubclass.storyteller,
      rarity: CharacterRarity.common,
      stats: const {},
      traits: const [],
      tags: const [],
      useCount: 0,
      saveCount: 0,
      price: 0,
      createdAt: DateTime(2026, 1, 1),
    );

Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(child: child),
      ),
    );

void main() {
  group('SimilarAgentsRibbon', () {
    testWidgets('hides entirely when result is empty', (tester) async {
      Future<List<AgentModel>> emptyFetch(int _) async => const [];
      await tester.pumpWidget(
        _wrap(SimilarAgentsRibbon(agentId: 1, fetchOverride: emptyFetch)),
      );
      // Resolve the future + rebuild without pumping animation frames.
      await tester.pump();
      await tester.pump();
      // The ribbon collapses to SizedBox.shrink — no header text.
      expect(find.text('Similar agents'), findsNothing);
      expect(find.byType(ShimmerBox), findsNothing);
    });

    testWidgets('renders header + count badge when loaded', (tester) async {
      final mockAgents = [
        _makeAgent(10, 'A1'),
        _makeAgent(11, 'A2'),
        _makeAgent(12, 'A3'),
      ];
      Future<List<AgentModel>> okFetch(int _) async => mockAgents;
      // Use a tiny placeholder card so we don't pull AgentCard's hover
      // animations + render-flex layout (which overflow in 200x240 boxes).
      Widget testCard(BuildContext _, AgentModel a) =>
          KeyedSubtree(key: ValueKey('card-${a.id}'), child: const SizedBox.shrink());
      await tester.pumpWidget(
        _wrap(SimilarAgentsRibbon(
          agentId: 1,
          fetchOverride: okFetch,
          cardBuilder: testCard,
        )),
      );
      // Drain the resolved future + rebuild.
      await tester.pump();
      await tester.pump();
      expect(find.text('Similar agents'), findsOneWidget);
      // Count badge.
      expect(find.text('· 3'), findsOneWidget);
      expect(find.byKey(const ValueKey('card-10')), findsOneWidget);
      expect(find.byKey(const ValueKey('card-11')), findsOneWidget);
      expect(find.byKey(const ValueKey('card-12')), findsOneWidget);
    });

    testWidgets('hides cleanly on fetch error', (tester) async {
      Future<List<AgentModel>> errorFetch(int _) =>
          Future<List<AgentModel>>.error(Exception('boom'));
      await tester.pumpWidget(
        _wrap(SimilarAgentsRibbon(agentId: 1, fetchOverride: errorFetch)),
      );
      await tester.pump();
      await tester.pump();
      expect(find.text('Similar agents'), findsNothing,
          reason: 'errors should silent-hide the ribbon');
    });
  });
}
