// Tests for the @-mention dropdown suggestion builder. The full
// MentionComposer widget pulls in MonacoEditorWidget via JS interop and
// can't mount in a Flutter unit test, so we exercise the pure-function
// filter directly via @visibleForTesting.

import 'package:agent_store/features/character/character_types.dart';
import 'package:agent_store/features/guild_master/widgets/mention_filter.dart';
import 'package:agent_store/shared/models/agent_model.dart';
import 'package:flutter_test/flutter_test.dart';

AgentModel _agent({
  required int id,
  required String title,
  required bool owned,
  int useCount = 0,
}) =>
    AgentModel(
      id: id,
      title: title,
      description: '',
      prompt: '',
      category: 'general',
      creatorWallet: '0x',
      characterType: CharacterType.bard,
      subclass: CharacterSubclass.storyteller,
      rarity: CharacterRarity.common,
      stats: const {},
      traits: const [],
      tags: const [],
      useCount: useCount,
      saveCount: 0,
      price: 0,
      createdAt: DateTime(2026, 1, 1),
      owned: owned,
    );

void main() {
  group('filterAgentSuggestions', () {
    test('empty input returns empty', () {
      expect(filterAgentSuggestions(const [], ''), isEmpty);
      expect(filterAgentSuggestions(const [], 'foo'), isEmpty);
    });

    test('library entries appear before store entries', () {
      final got = filterAgentSuggestions([
        _agent(id: 1, title: 'A', owned: false, useCount: 100),
        _agent(id: 2, title: 'B', owned: true, useCount: 1),
      ], '');
      expect(got.first.id, 2, reason: 'library wins regardless of useCount');
      expect(got[1].id, 1);
    });

    test('within a section, sorts by useCount desc', () {
      final got = filterAgentSuggestions([
        _agent(id: 1, title: 'low', owned: true, useCount: 5),
        _agent(id: 2, title: 'high', owned: true, useCount: 50),
        _agent(id: 3, title: 'mid', owned: true, useCount: 25),
      ], '');
      expect(got.map((a) => a.id).toList(), [2, 3, 1]);
    });

    test('library cap is enforced (max 6)', () {
      final lib = List.generate(
        10,
        (i) => _agent(id: i, title: 'l$i', owned: true, useCount: i),
      );
      final got = filterAgentSuggestions(lib, '');
      expect(got, hasLength(6));
      expect(got.every((a) => a.owned), isTrue);
    });

    test('store cap is enforced (max 8)', () {
      final store = List.generate(
        20,
        (i) => _agent(id: i, title: 's$i', owned: false, useCount: i),
      );
      final got = filterAgentSuggestions(store, '');
      expect(got, hasLength(8));
    });

    test('combined max 14 (6 library + 8 store)', () {
      final all = [
        ...List.generate(
          10,
          (i) => _agent(id: i, title: 'l$i', owned: true, useCount: i),
        ),
        ...List.generate(
          10,
          (i) => _agent(id: 100 + i, title: 's$i', owned: false, useCount: i),
        ),
      ];
      final got = filterAgentSuggestions(all, '');
      expect(got, hasLength(14));
      // Library entries occupy first 6 slots.
      for (var i = 0; i < 6; i++) {
        expect(got[i].owned, isTrue, reason: 'slot $i must be library');
      }
      for (var i = 6; i < 14; i++) {
        expect(got[i].owned, isFalse, reason: 'slot $i must be store');
      }
    });

    test('case-insensitive title filter', () {
      final got = filterAgentSuggestions([
        _agent(id: 1, title: 'CodeWizard', owned: true),
        _agent(id: 2, title: 'StoryBard', owned: false),
      ], 'CODE');
      expect(got, hasLength(1));
      expect(got.first.id, 1);
    });

    test('partial substring matches mid-title', () {
      final got = filterAgentSuggestions([
        _agent(id: 1, title: 'Quick Backend Helper', owned: false),
      ], 'back');
      expect(got, hasLength(1));
    });

    test('no match returns empty', () {
      final got = filterAgentSuggestions([
        _agent(id: 1, title: 'CodeWizard', owned: true),
      ], 'unrelated');
      expect(got, isEmpty);
    });

    test('filter applies independently to both sections', () {
      final got = filterAgentSuggestions([
        _agent(id: 1, title: 'data analyst', owned: true),
        _agent(id: 2, title: 'creative writer', owned: true),
        _agent(id: 3, title: 'data engineer', owned: false),
        _agent(id: 4, title: 'frontend dev', owned: false),
      ], 'data');
      expect(got.map((a) => a.id).toList(), [1, 3]);
    });

    test('mixed library/store result still respects library-first ordering', () {
      final got = filterAgentSuggestions([
        _agent(id: 10, title: 'store popular', owned: false, useCount: 1000),
        _agent(id: 20, title: 'library obscure', owned: true, useCount: 1),
      ], '');
      expect(got.first.owned, isTrue);
      expect(got[1].owned, isFalse);
    });

    test('library-only input shows only library', () {
      final got = filterAgentSuggestions([
        _agent(id: 1, title: 'a', owned: true),
        _agent(id: 2, title: 'b', owned: true),
      ], '');
      expect(got, hasLength(2));
      expect(got.every((a) => a.owned), isTrue);
    });

    test('store-only input shows only store', () {
      final got = filterAgentSuggestions([
        _agent(id: 1, title: 'a', owned: false),
        _agent(id: 2, title: 'b', owned: false),
      ], '');
      expect(got, hasLength(2));
      expect(got.every((a) => !a.owned), isTrue);
    });

    test('empty query returns all entries (within caps)', () {
      final got = filterAgentSuggestions([
        _agent(id: 1, title: 'anything', owned: true),
        _agent(id: 2, title: 'else', owned: false),
      ], '');
      expect(got, hasLength(2));
    });

    test('exposed cap constants match implementation', () {
      expect(kMentionLibraryLimit, 6);
      expect(kMentionStoreLimit, 8);
    });
  });
}
