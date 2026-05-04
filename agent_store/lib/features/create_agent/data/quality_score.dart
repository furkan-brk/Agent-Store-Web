// lib/features/create_agent/data/quality_score.dart
//
// Pure-Dart scorer for the Create Agent → Step 2 quality score card.
// Lives in /data so widget code stays test-friendly.

class QualityScore {
  /// 0–100 overall score (length 40 + tags 30 + character match 30).
  final int total;

  /// Sub-scores so the UI can show per-dimension feedback.
  final int lengthScore;
  final int tagsScore;
  final int characterMatchScore;

  /// Bullet-list of suggestions for fields that scored low. Empty when
  /// total ≥ 80.
  final List<String> suggestions;

  const QualityScore({
    required this.total,
    required this.lengthScore,
    required this.tagsScore,
    required this.characterMatchScore,
    required this.suggestions,
  });

  /// Bands map onto a color + label in the widget.
  QualityBand get band {
    if (total >= 80) return QualityBand.excellent;
    if (total >= 50) return QualityBand.good;
    return QualityBand.needsWork;
  }
}

enum QualityBand { excellent, good, needsWork }

/// Computes the composite quality score given the publishable inputs.
///
/// Scoring formula (codified in the plan):
///   - lengthScore  (40 pt): <20→0, 20-100→15, 100-300→30, >300→40
///   - tagsScore    (30 pt): 0→0, 1-2→15, 3-5→30, >5→25 (over-tag penalty)
///   - characterMatchScore (30 pt): promptScore 0-100 → 0-30 lineer
QualityScore computeQualityScore({
  required int promptCharCount,
  required int tagCount,
  required int characterPromptScore,
}) {
  final lengthScore = _scoreLength(promptCharCount);
  final tagsScore = _scoreTags(tagCount);
  final characterMatchScore = _scoreCharacterMatch(characterPromptScore);
  final total = lengthScore + tagsScore + characterMatchScore;

  final suggestions = <String>[];
  if (promptCharCount < 100) {
    suggestions.add(
      'Add detail to your prompt — define a clear role, domain, and behavior.',
    );
  }
  if (tagCount == 0) {
    suggestions.add(
      'Add 3-5 tags so users can discover this agent in the store.',
    );
  } else if (tagCount > 5) {
    suggestions.add(
      'You have $tagCount tags — focus to 3-5 strong ones for best discovery.',
    );
  }
  if (characterPromptScore < 40 && promptCharCount > 50) {
    suggestions.add(
      'Prompt keywords don\'t strongly match a character archetype yet — '
      'mention the agent\'s domain (code, data, design, security…).',
    );
  }

  return QualityScore(
    total: total,
    lengthScore: lengthScore,
    tagsScore: tagsScore,
    characterMatchScore: characterMatchScore,
    suggestions: suggestions,
  );
}

int _scoreLength(int chars) {
  if (chars < 20) return 0;
  if (chars < 100) return 15;
  if (chars <= 300) return 30;
  return 40;
}

int _scoreTags(int n) {
  if (n == 0) return 0;
  if (n <= 2) return 15;
  if (n <= 5) return 30;
  return 25; // over-tag penalty
}

int _scoreCharacterMatch(int promptScore) {
  // Linear 0..100 → 0..30, clamped just in case.
  final v = promptScore.clamp(0, 100);
  return ((v / 100) * 30).round();
}
