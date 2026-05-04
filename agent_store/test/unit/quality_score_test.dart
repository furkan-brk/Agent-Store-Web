// Unit tests for the v3.11.1 Create Agent quality score formula.

import 'package:agent_store/features/create_agent/data/quality_score.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('computeQualityScore — length brackets', () {
    test('<20 chars → 0 length pts', () {
      final s = computeQualityScore(
          promptCharCount: 10, tagCount: 5, characterPromptScore: 100);
      expect(s.lengthScore, 0);
    });
    test('20-99 chars → 15 length pts', () {
      expect(
          computeQualityScore(
                  promptCharCount: 50,
                  tagCount: 5,
                  characterPromptScore: 100)
              .lengthScore,
          15);
    });
    test('100-300 chars → 30 length pts', () {
      expect(
          computeQualityScore(
                  promptCharCount: 250,
                  tagCount: 5,
                  characterPromptScore: 100)
              .lengthScore,
          30);
    });
    test('>300 chars → 40 length pts', () {
      expect(
          computeQualityScore(
                  promptCharCount: 600,
                  tagCount: 5,
                  characterPromptScore: 100)
              .lengthScore,
          40);
    });
  });

  group('computeQualityScore — tags brackets', () {
    test('0 tags → 0 pts', () {
      expect(
          computeQualityScore(
                  promptCharCount: 200,
                  tagCount: 0,
                  characterPromptScore: 50)
              .tagsScore,
          0);
    });
    test('1-2 tags → 15 pts', () {
      expect(
          computeQualityScore(
                  promptCharCount: 200,
                  tagCount: 2,
                  characterPromptScore: 50)
              .tagsScore,
          15);
    });
    test('3-5 tags → 30 pts (sweet spot)', () {
      expect(
          computeQualityScore(
                  promptCharCount: 200,
                  tagCount: 4,
                  characterPromptScore: 50)
              .tagsScore,
          30);
    });
    test('>5 tags → 25 pts (over-tag penalty)', () {
      expect(
          computeQualityScore(
                  promptCharCount: 200,
                  tagCount: 8,
                  characterPromptScore: 50)
              .tagsScore,
          25);
    });
  });

  group('computeQualityScore — character match', () {
    test('promptScore 0 → 0 character pts', () {
      expect(
          computeQualityScore(
                  promptCharCount: 200,
                  tagCount: 4,
                  characterPromptScore: 0)
              .characterMatchScore,
          0);
    });
    test('promptScore 100 → 30 character pts', () {
      expect(
          computeQualityScore(
                  promptCharCount: 200,
                  tagCount: 4,
                  characterPromptScore: 100)
              .characterMatchScore,
          30);
    });
    test('linear interpolation: 50 → 15', () {
      expect(
          computeQualityScore(
                  promptCharCount: 200,
                  tagCount: 4,
                  characterPromptScore: 50)
              .characterMatchScore,
          15);
    });
  });

  group('computeQualityScore — band thresholds', () {
    test('total ≥ 80 → excellent', () {
      // 40 + 30 + 30 = 100
      final s = computeQualityScore(
          promptCharCount: 600, tagCount: 4, characterPromptScore: 100);
      expect(s.total, 100);
      expect(s.band, QualityBand.excellent);
      expect(s.suggestions, isEmpty);
    });
    test('total 50-79 → good', () {
      // 30 + 15 + 15 = 60
      final s = computeQualityScore(
          promptCharCount: 200, tagCount: 2, characterPromptScore: 50);
      expect(s.total, 60);
      expect(s.band, QualityBand.good);
    });
    test('total < 50 → needsWork + suggestions', () {
      // 0 + 0 + 0 = 0
      final s = computeQualityScore(
          promptCharCount: 5, tagCount: 0, characterPromptScore: 0);
      expect(s.band, QualityBand.needsWork);
      expect(s.suggestions, isNotEmpty);
    });
  });

  group('computeQualityScore — suggestions', () {
    test('over-tag triggers a focused suggestion', () {
      final s = computeQualityScore(
          promptCharCount: 600, tagCount: 9, characterPromptScore: 100);
      expect(s.suggestions.any((m) => m.contains('focus')), isTrue);
    });
    test('zero tags triggers add-tags suggestion', () {
      final s = computeQualityScore(
          promptCharCount: 600, tagCount: 0, characterPromptScore: 100);
      expect(s.suggestions.any((m) => m.contains('Add 3-5 tags')), isTrue);
    });
  });
}
