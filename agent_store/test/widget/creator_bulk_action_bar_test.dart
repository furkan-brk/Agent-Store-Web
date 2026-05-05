// v3.11.4: covers CreatorBulkActionBar render contract.
//
// Test surface is intentionally minimal — the bar's complex multi-select
// dialog flow is exercised manually; here we lock down the render-time
// invariants (button enabled-ness, label, cost-per-agent constant).

import 'package:agent_store/features/character/character_types.dart';
import 'package:agent_store/features/creator/widgets/creator_bulk_action_bar.dart';
import 'package:agent_store/shared/models/agent_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

AgentModel _agent(int id, String title) => AgentModel(
      id: id,
      title: title,
      description: '',
      prompt: '',
      category: 'backend',
      creatorWallet: '0xowner',
      characterType: CharacterType.wizard,
      subclass: CharacterSubclass.archmage,
      rarity: CharacterRarity.common,
      stats: const {},
      traits: const [],
      tags: const [],
      useCount: 0,
      saveCount: 0,
      price: 0,
      createdAt: DateTime.now(),
    );

Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(
        body: SizedBox(width: 1200, height: 200, child: child),
      ),
    );

void main() {
  test('cost-per-agent constant matches backend bulkActionCost', () {
    expect(kBulkRegenerateCostPerAgent, equals(3));
  });

  testWidgets('Regenerate button is disabled when there are no agents',
      (tester) async {
    await tester.pumpWidget(_wrap(const CreatorBulkActionBar(
      agents: [],
      userCredits: 100,
    )));
    expect(find.text('Regenerate images…'), findsOneWidget);
    // Locate the button via its label and verify onPressed is null
    final btnFinder = find.ancestor(
      of: find.text('Regenerate images…'),
      matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
    );
    final button = tester.widget<ButtonStyleButton>(btnFinder.first);
    expect(button.onPressed, isNull, reason: 'no agents → disabled');
  });

  testWidgets('Bar renders agent count + cost label',
      (tester) async {
    await tester.pumpWidget(_wrap(CreatorBulkActionBar(
      agents: [_agent(1, 'A'), _agent(2, 'B'), _agent(3, 'C')],
      userCredits: 50,
    )));
    expect(find.text('Bulk actions'), findsOneWidget);
    expect(find.text('Regenerate images…'), findsOneWidget);
    expect(find.textContaining('3 owned'), findsOneWidget);
  });
}
