// Tests for CardEditorController — pure-logic paths (history, dirty
// tracking, prompt re-detection). The save flow is intentionally not
// exercised here because the controller calls ApiService.instance directly
// (no DI), and the debounce timer never fires inside synchronous tests.

import 'package:agent_store/features/card_editor/controllers/card_editor_controller.dart';
import 'package:agent_store/features/character/character_types.dart';
import 'package:agent_store/shared/models/agent_model.dart';
import 'package:flutter_test/flutter_test.dart';

AgentModel _seed({
  String title = 'Initial',
  String prompt = 'You are a basic agent.',
  CharacterType type = CharacterType.bard,
  CharacterSubclass sub = CharacterSubclass.storyteller,
}) =>
    AgentModel(
      id: 1,
      title: title,
      description: 'd',
      prompt: prompt,
      category: 'general',
      creatorWallet: '0xowner',
      characterType: type,
      subclass: sub,
      rarity: CharacterRarity.common,
      stats: const {'int': 5},
      traits: const ['curious'],
      tags: const ['initial'],
      useCount: 0,
      saveCount: 0,
      price: 0,
      createdAt: DateTime(2026, 1, 1),
    );

void main() {
  group('updateField + dirty tracking', () {
    test('starts idle and not dirty', () {
      final c = CardEditorController(initial: _seed());
      expect(c.syncStatus.value, SyncStatus.idle);
      expect(c.isDirty, isFalse);
    });

    test('updateField with new title flips to dirty', () {
      final c = CardEditorController(initial: _seed());
      c.updateField((a) => a.copyWith(title: 'Renamed'));
      expect(c.draft.value.title, 'Renamed');
      expect(c.isDirty, isTrue);
      expect(c.syncStatus.value, SyncStatus.dirty);
    });

    test('updateField with same content is a no-op', () {
      final c = CardEditorController(initial: _seed(title: 'Same'));
      c.updateField((a) => a.copyWith(title: 'Same'));
      expect(c.isDirty, isFalse);
      expect(c.syncStatus.value, SyncStatus.idle);
    });

    test('mutating tags list flips dirty', () {
      final c = CardEditorController(initial: _seed());
      c.updateField((a) => a.copyWith(tags: const ['a', 'b']));
      expect(c.draft.value.tags, const ['a', 'b']);
      expect(c.isDirty, isTrue);
    });
  });

  group('undo / redo', () {
    test('canUndo/canRedo start false', () {
      final c = CardEditorController(initial: _seed());
      expect(c.canUndo, isFalse);
      expect(c.canRedo, isFalse);
    });

    test('after one edit canUndo=true canRedo=false', () {
      final c = CardEditorController(initial: _seed(title: 'A'));
      c.updateField((a) => a.copyWith(title: 'B'));
      expect(c.canUndo, isTrue);
      expect(c.canRedo, isFalse);
    });

    test('undo restores previous draft', () {
      final c = CardEditorController(initial: _seed(title: 'A'));
      c.updateField((a) => a.copyWith(title: 'B'));
      c.undo();
      expect(c.draft.value.title, 'A');
      expect(c.canUndo, isFalse);
      expect(c.canRedo, isTrue);
    });

    test('redo replays after undo', () {
      final c = CardEditorController(initial: _seed(title: 'A'));
      c.updateField((a) => a.copyWith(title: 'B'));
      c.undo();
      c.redo();
      expect(c.draft.value.title, 'B');
      expect(c.canRedo, isFalse);
    });

    test('new edit after undo drops the redo tail', () {
      final c = CardEditorController(initial: _seed(title: 'A'));
      c.updateField((a) => a.copyWith(title: 'B'));
      c.updateField((a) => a.copyWith(title: 'C'));
      c.undo(); // back to B
      expect(c.canRedo, isTrue);
      c.updateField((a) => a.copyWith(title: 'D'));
      expect(c.canRedo, isFalse, reason: 'fresh edit kills redo tail');
      expect(c.draft.value.title, 'D');
    });

    test('undo on empty history is a no-op', () {
      final c = CardEditorController(initial: _seed());
      c.undo();
      expect(c.canUndo, isFalse);
      expect(c.draft.value.title, 'Initial');
    });

    test('redo when no future is a no-op', () {
      final c = CardEditorController(initial: _seed());
      c.updateField((a) => a.copyWith(title: 'B'));
      c.redo();
      expect(c.draft.value.title, 'B');
    });

    test('history caps at 50 entries (oldest dropped)', () {
      final c = CardEditorController(initial: _seed(title: 'v0'));
      for (var i = 1; i <= 60; i++) {
        c.updateField((a) => a.copyWith(title: 'v$i'));
      }
      // Walk all the way back; the oldest reachable should be at most 50 steps away.
      var steps = 0;
      while (c.canUndo) {
        c.undo();
        steps++;
        if (steps > 60) break;
      }
      expect(steps, lessThanOrEqualTo(50));
      // The pre-edit "v0" was the 61st-oldest entry, so it must have been evicted.
      expect(c.draft.value.title, isNot('v0'));
    });
  });

  group('reDetectFromPrompt', () {
    test('switches type when prompt clearly matches another keyword set', () {
      final c = CardEditorController(
        initial: _seed(
          prompt: 'old prompt',
          type: CharacterType.bard,
          sub: CharacterSubclass.storyteller,
        ),
      );
      c.updateField((a) => a.copyWith(
            prompt:
                'You are an expert backend python golang api developer working with sql databases.',
          ));
      c.reDetectFromPrompt();
      expect(c.draft.value.characterType, CharacterType.wizard,
          reason: 'backend keywords should map to wizard');
      expect(
        c.draft.value.characterType.subclasses,
        contains(c.draft.value.subclass),
        reason: 'subclass must reset to a valid variant of the new type',
      );
    });

    test('no-op when re-detected type matches current type', () {
      final c = CardEditorController(
        initial: _seed(
          prompt:
              'You write creative blog content and stories with a strong narrative voice.',
          type: CharacterType.bard,
          sub: CharacterSubclass.storyteller,
        ),
      );
      c.reDetectFromPrompt();
      expect(c.draft.value.characterType, CharacterType.bard);
      expect(c.draft.value.subclass, CharacterSubclass.storyteller);
      expect(c.isDirty, isFalse);
    });
  });

  group('isDirty edge cases', () {
    test('returns false after no-op update', () {
      final c = CardEditorController(initial: _seed());
      c.updateField((a) => a); // identity
      expect(c.isDirty, isFalse);
    });

    test('changing only price flips dirty', () {
      final c = CardEditorController(initial: _seed());
      c.updateField((a) => a.copyWith(price: 9.99));
      expect(c.isDirty, isTrue);
      expect(c.draft.value.price, 9.99);
    });

    test('changing description flips dirty', () {
      final c = CardEditorController(initial: _seed());
      c.updateField((a) => a.copyWith(description: 'new'));
      expect(c.isDirty, isTrue);
    });

    test('disposing controller cancels timer cleanly', () {
      final c = CardEditorController(initial: _seed());
      c.updateField((a) => a.copyWith(title: 'X'));
      c.onClose();
      // No exception means the debounce timer was cancelled safely.
      expect(c.isDirty, isTrue);
    });
  });
}
