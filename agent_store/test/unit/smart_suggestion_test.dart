// v3.11.4: covers the pure-Dart heuristics behind SmartSuggestionButton.

import 'package:agent_store/features/character/character_types.dart';
import 'package:agent_store/features/create_agent/widgets/smart_suggestion_button.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('suggestTitle', () {
    test('extracts top tokens and capitalizes them', () {
      final out = suggestTitle('Build a database migration tool with rollback support');
      // Top meaningful tokens in order: build, database (top 2). Stopwords
      // 'with' filtered out; tokens shorter than 4 chars skipped.
      expect(out, equals('Build Database Agent'));
    });

    test('falls back to "Custom Agent" on empty / sparse prompt', () {
      expect(suggestTitle(''), equals('Custom Agent'));
      expect(suggestTitle('a b c'), equals('Custom Agent'));
    });
  });

  group('suggestTraits', () {
    test('biases toward character type keywords when present', () {
      // CharacterType.merchant keyword list contains "pricing", "sales",
      // "campaign" — at least one of which lives in this prompt.
      final out = suggest(
        type: SuggestionType.traits,
        promptText: 'help with pricing strategy and customer retention',
        characterType: CharacterType.merchant,
      );
      expect(out, isNotEmpty);
      expect(out.contains('Pricing') || out.contains('Customer'), isTrue,
          reason: 'expected at least one merchant keyword to surface, got: $out');
    });

    test('falls back to generic traits when no keyword hits', () {
      final out = suggestTraits('zzz qqq', null);
      // Generic fallback string when no hits and no character type.
      expect(out.split(' · ').length, greaterThanOrEqualTo(2));
    });
  });

  group('profile mood', () {
    test('returns a wizard-flavoured mood for the wizard type', () {
      final out = suggest(
        type: SuggestionType.profileMood,
        promptText: 'irrelevant',
        characterType: CharacterType.wizard,
      );
      expect(out.toLowerCase(), contains('mysterious'));
    });

    test('safe default when no character type is supplied', () {
      final out = suggest(
        type: SuggestionType.profileMood,
        promptText: 'x',
      );
      expect(out, equals('Steady · Approachable'));
    });
  });
}
