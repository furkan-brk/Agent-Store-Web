// Pure-Dart tests for the prompt preview/full toggle helpers.
//
// The actual Obx-driven UI lives in agent_detail_screen.dart which is
// blocked from `flutter test` by dart:js_interop. We exercise the
// helpers directly here.

import 'package:agent_store/features/agent_detail/widgets/prompt_redaction.dart';
import 'package:flutter_test/flutter_test.dart';

String _make(int n, {String char = 'a'}) => char * n;

void main() {
  group('shouldOfferPromptToggle', () {
    test('false when prompt is shorter than threshold', () {
      expect(shouldOfferPromptToggle(_make(0)), isFalse);
      expect(shouldOfferPromptToggle(_make(499)), isFalse);
      expect(shouldOfferPromptToggle(_make(500)), isFalse,
          reason: 'exactly 500 chars should NOT trigger toggle');
    });

    test('true when prompt is longer than threshold', () {
      expect(shouldOfferPromptToggle(_make(501)), isTrue);
      expect(shouldOfferPromptToggle(_make(2000)), isTrue);
    });
  });

  group('displayedPromptBody', () {
    test('short prompt: returns verbatim regardless of toggle', () {
      final s = _make(100);
      expect(displayedPromptBody(s, showFull: false), s);
      expect(displayedPromptBody(s, showFull: true), s);
    });

    test('long prompt + showFull=false: returns truncated preview + ellipsis',
        () {
      final long = _make(900);
      final result = displayedPromptBody(long, showFull: false);
      // 500 chars + ellipsis sigil
      expect(result.endsWith('…'), isTrue);
      expect(result.length, lessThanOrEqualTo(kPromptPreviewThreshold + 1));
    });

    test('long prompt + showFull=true: returns full body', () {
      final long = _make(900);
      expect(displayedPromptBody(long, showFull: true), long);
    });

    test('preview trims trailing whitespace before ellipsis', () {
      // 480 'a' + 20 ' ' = 500 char prompt + tail. Truncation at 500 will
      // grab the 480 a's + 20 spaces; trim should drop the spaces before
      // the ellipsis joins.
      final s = '${_make(480)}${_make(20, char: ' ')}${_make(100)}';
      expect(s.length, 600);
      final result = displayedPromptBody(s, showFull: false);
      expect(result.endsWith(' …'), isFalse,
          reason: 'no whitespace immediately before the ellipsis');
      expect(result.endsWith('a…'), isTrue);
    });
  });
}
