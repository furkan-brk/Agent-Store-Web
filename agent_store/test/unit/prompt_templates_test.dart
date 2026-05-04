// Pure-Dart tests for the Create Agent prompt template gallery.
//
// Lives in test/unit/ so we don't pull MaterialApp / canvas widgets.
// The dialog widget itself is exercised at the integration level later;
// here we lock in the data contract that the dialog reads.

import 'package:agent_store/features/create_agent/data/prompt_templates.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('promptTemplates', () {
    test('contains exactly 10 templates', () {
      expect(promptTemplates, hasLength(10));
    });

    test('every template id is unique', () {
      final ids = promptTemplates.map((t) => t.id).toList();
      expect(ids.toSet(), hasLength(ids.length),
          reason: 'duplicate template ids would break analytics + dialog state');
    });

    test('every promptBody is at least 50 chars', () {
      for (final t in promptTemplates) {
        expect(t.promptBody.length, greaterThanOrEqualTo(50),
            reason: 'template ${t.id} promptBody too short — '
                'keyword detection + character match need substance');
      }
    });

    test('every template has at least 1 tag suggestion', () {
      for (final t in promptTemplates) {
        expect(t.tagSuggestions, isNotEmpty,
            reason: 'template ${t.id} has no tag suggestions');
      }
    });

    test('filter by category returns only matching templates', () {
      final cats = promptTemplates.map((t) => t.category).toSet();
      expect(cats, isNotEmpty);
      for (final cat in cats) {
        final filtered =
            promptTemplates.where((t) => t.category == cat).toList();
        expect(filtered, isNotEmpty,
            reason: 'category $cat has no matching templates');
        for (final t in filtered) {
          expect(t.category, cat);
        }
      }
    });
  });
}
