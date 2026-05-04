// Widget tests for the MentionPreviewCard hover overlay payload.
// The card itself is a pure widget — no JS interop, no async fetches.

import 'package:agent_store/features/character/character_types.dart';
import 'package:agent_store/features/guild_master/widgets/mention_preview_card.dart';
import 'package:agent_store/shared/models/agent_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

AgentModel _agent({
  String title = 'Test Agent',
  String description = '',
  CharacterType characterType = CharacterType.bard,
  CharacterRarity rarity = CharacterRarity.common,
  int saveCount = 0,
  int useCount = 0,
}) =>
    AgentModel(
      id: 1,
      title: title,
      description: description,
      prompt: '',
      category: 'general',
      creatorWallet: '0x',
      characterType: characterType,
      subclass: CharacterSubclass.storyteller,
      rarity: rarity,
      stats: const {},
      traits: const [],
      tags: const [],
      useCount: useCount,
      saveCount: saveCount,
      price: 0,
      createdAt: DateTime(2026, 1, 1),
    );

Widget _wrap(Widget child) =>
    MaterialApp(home: Scaffold(body: Center(child: child)));

void main() {
  group('MentionPreviewCard', () {
    testWidgets('renders title + character type + rarity chips',
        (tester) async {
      await tester.pumpWidget(
        _wrap(MentionPreviewCard(
          agent: _agent(
            title: 'CodeWizard',
            characterType: CharacterType.wizard,
            rarity: CharacterRarity.epic,
          ),
        )),
      );
      expect(find.text('CodeWizard'), findsOneWidget);
      expect(find.text('Wizard'), findsOneWidget);
      expect(find.text('Epic'), findsOneWidget);
    });

    testWidgets('renders description when present', (tester) async {
      await tester.pumpWidget(
        _wrap(MentionPreviewCard(
          agent: _agent(description: 'Best in class code review.'),
        )),
      );
      expect(find.text('Best in class code review.'), findsOneWidget);
    });

    testWidgets('renders save and use counts in footer', (tester) async {
      await tester.pumpWidget(
        _wrap(MentionPreviewCard(
          agent: _agent(saveCount: 42, useCount: 7),
        )),
      );
      expect(find.text('42'), findsOneWidget);
      expect(find.text('7'), findsOneWidget);
    });
  });
}
