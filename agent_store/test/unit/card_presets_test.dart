// Unit tests for the card preset catalogue + applier (v3.11.3 — T9a).
//
// The catalogue is hand-edited by humans; these tests guard against
// duplicate ids, empty bodies, off-range stat boosts after merge, and
// trait dedup case-folding.

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_store/features/card_editor/data/card_presets.dart';
import 'package:agent_store/features/character/character_types.dart';

void main() {
  group('kCardPresets catalogue', () {
    test('all preset ids are unique', () {
      final ids = kCardPresets.map((p) => p.id).toList();
      expect(ids.length, ids.toSet().length,
          reason: 'duplicate preset ids found');
    });

    test('every preset is non-empty (name + description + boosts or traits)',
        () {
      for (final p in kCardPresets) {
        expect(p.name.trim(), isNotEmpty,
            reason: '${p.id} has an empty name');
        expect(p.description.trim(), isNotEmpty,
            reason: '${p.id} has an empty description');
        expect(p.statsBoost.isNotEmpty || p.traits.isNotEmpty, isTrue,
            reason: '${p.id} provides nothing to apply');
      }
    });
  });

  group('presetsForCharacter', () {
    test('wizard returns wizard-typed presets and the universal "any" set',
        () {
      final picks = presetsForCharacter(CharacterType.wizard);
      // Must include at least one wizard-tagged preset.
      expect(
        picks.where((p) => p.characterType == CharacterType.wizard).length,
        greaterThan(0),
      );
      // Must also include every type==null universal preset.
      final universalCount = kCardPresets.where((p) => p.characterType == null).length;
      expect(picks.where((p) => p.characterType == null).length, universalCount);
      // Must NOT include presets bound to a different type.
      expect(
        picks.where((p) =>
            p.characterType != null &&
            p.characterType != CharacterType.wizard),
        isEmpty,
      );
    });

    test('null filter returns only universal presets', () {
      final picks = presetsForCharacter(null);
      expect(picks.every((p) => p.characterType == null), isTrue);
    });
  });

  group('applyPresetToDraft', () {
    test('merges stat boosts and clamps the result to 1..10', () {
      const preset = CardPreset(
        id: 'test-clamp',
        name: 'Clamp',
        description: 'd',
        statsBoost: {'power': 5},
        traits: [],
      );
      // Existing power 8 + boost 5 should clamp to 10 (not 13).
      final r = applyPresetToDraft(
        preset: preset,
        existingStats: {'power': 8, 'wisdom': 4},
        existingTraits: [],
      );
      expect(r.stats['power'], 10);
      expect(r.stats['wisdom'], 4);
    });

    test('appends traits and dedups case-insensitively', () {
      const preset = CardPreset(
        id: 'test-traits',
        name: 'Traits',
        description: 'd',
        statsBoost: {},
        traits: ['Pragmatic', 'mentor', 'NEW-TRAIT'],
      );
      final r = applyPresetToDraft(
        preset: preset,
        existingStats: {},
        existingTraits: ['pragmatic'], // lowercase already present
      );
      // 'pragmatic' should not double-up despite the title-case version.
      expect(r.traits.where((t) => t.toLowerCase() == 'pragmatic').length, 1);
      expect(r.traits, contains('mentor'));
      expect(r.traits, contains('NEW-TRAIT'));
    });
  });
}
