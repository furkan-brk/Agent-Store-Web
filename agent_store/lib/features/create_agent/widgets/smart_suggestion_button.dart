// v3.11.4: AI-suggestion button stub powered by pure-Dart heuristics.
//
// Three suggestion modes:
//   - title          → 3 keyword extract from prompt → "X Y Agent"
//   - traits         → 3 character keywords mapped to short trait labels
//   - profile_mood   → static map keyed by CharacterType
//
// Pure-Dart for v3.11.4. Server-side AI suggestion endpoint deferred to
// v3.11.5 — when it lands, this widget will swap to an async API call but
// keep the same callback contract.

import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../character/character_types.dart';
import '../../../controllers/create_agent_controller.dart';

/// Suggestion kind. Title produces a short string; Traits/ProfileMood
/// produce a single string the caller wires into the relevant form field.
enum SuggestionType { title, traits, profileMood }

class SmartSuggestionButton extends StatelessWidget {
  /// User's current prompt text — feeds the heuristic for title/traits.
  final String promptText;

  /// Currently-detected character type — feeds the profile-mood map.
  final CharacterType? characterType;

  /// What kind of suggestion to produce on tap.
  final SuggestionType type;

  /// Called with the produced string so the caller can patch their controller.
  final ValueChanged<String> onSuggested;

  const SmartSuggestionButton({
    super.key,
    required this.promptText,
    required this.type,
    required this.onSuggested,
    this.characterType,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      icon: const Icon(Icons.auto_awesome, size: 16),
      label: Text(_label, style: const TextStyle(fontSize: 12)),
      style: TextButton.styleFrom(
        foregroundColor: AppTheme.gold,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        minimumSize: const Size(0, 28),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      onPressed: () => onSuggested(suggest(
        type: type,
        promptText: promptText,
        characterType: characterType,
      )),
    );
  }

  String get _label {
    switch (type) {
      case SuggestionType.title:
        return 'Suggest title';
      case SuggestionType.traits:
        return 'Suggest traits';
      case SuggestionType.profileMood:
        return 'Suggest mood';
    }
  }
}

/// Pure-Dart suggestion entry point. Kept top-level (not a method) so unit
/// tests can exercise the heuristics without mounting any widget.
String suggest({
  required SuggestionType type,
  required String promptText,
  CharacterType? characterType,
}) {
  switch (type) {
    case SuggestionType.title:
      return suggestTitle(promptText);
    case SuggestionType.traits:
      return suggestTraits(promptText, characterType);
    case SuggestionType.profileMood:
      return _defaultMoodFor(characterType);
  }
}

/// Extracts up to 3 high-signal keywords from [promptText] and returns
/// them as a "Capitalized X Capitalized Y Agent" string. Returns
/// "Custom Agent" when the prompt is too sparse to derive anything.
String suggestTitle(String promptText) {
  final tokens = _meaningfulTokens(promptText);
  if (tokens.isEmpty) return 'Custom Agent';
  final top = tokens.take(2).map(_capitalize).toList();
  return '${top.join(' ')} Agent';
}

/// Maps the prompt's top-3 keyword matches back to short trait labels.
/// When [characterType] is known we bias the trait pool toward that type's
/// keyword list.
String suggestTraits(String promptText, CharacterType? characterType) {
  final hits = <String>{};
  final lower = promptText.toLowerCase();

  // Bias pool: this character's keywords come first.
  final pool = <String>[];
  if (characterType != null) {
    pool.addAll(CreateAgentController.keywordsFor(characterType));
  }
  // General fallback pool (small generic set).
  pool.addAll(_genericTraitTokens);

  for (final kw in pool) {
    if (lower.contains(kw)) {
      hits.add(_capitalize(kw));
      if (hits.length >= 3) break;
    }
  }
  if (hits.isEmpty) {
    return characterType != null
        ? '${_capitalize(characterType.name)} · Curious · Helpful'
        : 'Curious · Helpful · Adaptive';
  }
  return hits.join(' · ');
}

const _genericTraitTokens = <String>[
  'fast', 'creative', 'analytical', 'detailed', 'precise',
  'careful', 'helpful', 'curious', 'patient', 'friendly',
  'expert', 'critical', 'concise', 'thorough', 'adaptive',
];

/// Returns a profile-mood phrase keyed by character type. Private to this
/// file by convention so the canonical CharacterType enum stays untouched
/// (extension would force every call site to pull a new dependency).
String _defaultMoodFor(CharacterType? type) {
  if (type == null) return 'Steady · Approachable';
  switch (type) {
    case CharacterType.wizard:
      return 'Studious · Mysterious';
    case CharacterType.strategist:
      return 'Decisive · Composed';
    case CharacterType.oracle:
      return 'Insightful · Patient';
    case CharacterType.guardian:
      return 'Vigilant · Protective';
    case CharacterType.artisan:
      return 'Playful · Inventive';
    case CharacterType.bard:
      return 'Charismatic · Expressive';
    case CharacterType.scholar:
      return 'Curious · Methodical';
    case CharacterType.merchant:
      return 'Persuasive · Sharp';
  }
}

/// Splits prompt into lower-case word-tokens, drops stopwords + tokens
/// shorter than 4 chars, returns the remaining sequence in original order.
List<String> _meaningfulTokens(String s) {
  final raw = s.toLowerCase().split(RegExp(r'[^a-z0-9]+'));
  final out = <String>[];
  for (final t in raw) {
    if (t.length < 4) continue;
    if (_stopwords.contains(t)) continue;
    out.add(t);
  }
  return out;
}

const _stopwords = <String>{
  'the', 'and', 'for', 'with', 'that', 'this', 'will', 'have',
  'from', 'into', 'about', 'when', 'they', 'them', 'their',
  'your', 'should', 'would', 'could', 'shall',
};

String _capitalize(String s) {
  if (s.isEmpty) return s;
  return s[0].toUpperCase() + s.substring(1);
}
