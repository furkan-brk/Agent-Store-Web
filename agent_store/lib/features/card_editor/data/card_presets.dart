// lib/features/card_editor/data/card_presets.dart
//
// v3.11.3 — T9a — Stat/trait packages applied via the Card Editor toolbar.
//
// Each [CardPreset] bundles a stat boost map plus a curated trait list. When
// applied via [CardEditorController.applyPreset] the boost adds to existing
// stats (clamped 1..10) and traits append (deduped). character_type / subclass
// are advisory: a preset whose `characterType` doesn't match the current
// agent still applies, but the UI groups by character type for filterability.

import '../../character/character_types.dart';

class CardPreset {
  final String id;
  final String name;
  final String description;
  final CharacterType? characterType;
  final CharacterSubclass? subclass;
  final Map<String, int> statsBoost;
  final List<String> traits;

  const CardPreset({
    required this.id,
    required this.name,
    required this.description,
    this.characterType,
    this.subclass,
    required this.statsBoost,
    required this.traits,
  });
}

/// Top-level catalogue. Add carefully — the unit tests assert `id` uniqueness
/// and that every preset is non-empty.
const List<CardPreset> kCardPresets = <CardPreset>[
  // ── Wizard (backend / code) ───────────────────────────────────────────────
  CardPreset(
    id: 'wizard-archmage-senior',
    name: 'Senior Archmage',
    description: 'Battle-hardened backend wizard with deep system knowledge.',
    characterType: CharacterType.wizard,
    subclass: CharacterSubclass.archmage,
    statsBoost: {'power': 2, 'wisdom': 2, 'defense': 1},
    traits: ['systems-thinker', 'pragmatic', 'mentor'],
  ),
  CardPreset(
    id: 'wizard-sorcerer-fast',
    name: 'Quick Sorcerer',
    description: 'Speed-first coder for prototypes & spikes.',
    characterType: CharacterType.wizard,
    subclass: CharacterSubclass.sorcerer,
    statsBoost: {'speed': 3, 'power': 1},
    traits: ['rapid', 'experimental'],
  ),
  CardPreset(
    id: 'wizard-hexmaster-debug',
    name: 'Debug Hex Master',
    description: 'Ruthless bug hunter with arcane stack-trace insight.',
    characterType: CharacterType.wizard,
    subclass: CharacterSubclass.hexMaster,
    statsBoost: {'wisdom': 3, 'defense': 1},
    traits: ['analytical', 'patient', 'thorough'],
  ),

  // ── Strategist (planning / PM) ────────────────────────────────────────────
  CardPreset(
    id: 'strategist-warcommander-decisive',
    name: 'Decisive War Commander',
    description: 'Pulls trigger on hard calls; thrives in firefights.',
    characterType: CharacterType.strategist,
    subclass: CharacterSubclass.warCommander,
    statsBoost: {'power': 2, 'speed': 2},
    traits: ['decisive', 'high-conviction'],
  ),
  CardPreset(
    id: 'strategist-tactician-roadmap',
    name: 'Roadmap Tactician',
    description: 'Quarterly planner who keeps everyone in lock-step.',
    characterType: CharacterType.strategist,
    subclass: CharacterSubclass.tactician,
    statsBoost: {'wisdom': 2, 'defense': 2},
    traits: ['organized', 'long-horizon'],
  ),

  // ── Oracle (data / analytics) ─────────────────────────────────────────────
  CardPreset(
    id: 'oracle-analyst-data',
    name: 'Data Analyst',
    description: 'Story-with-numbers translator for execs.',
    characterType: CharacterType.oracle,
    subclass: CharacterSubclass.analyst,
    statsBoost: {'wisdom': 3, 'speed': 1},
    traits: ['curious', 'evidence-driven'],
  ),
  CardPreset(
    id: 'oracle-prophet-forecast',
    name: 'Forecast Prophet',
    description: 'Long-range model owner — seasonality & decay specialist.',
    characterType: CharacterType.oracle,
    subclass: CharacterSubclass.prophet,
    statsBoost: {'wisdom': 3, 'power': 1},
    traits: ['forward-looking', 'rigorous'],
  ),

  // ── Guardian (security / infra) ───────────────────────────────────────────
  CardPreset(
    id: 'guardian-sentinel-incident',
    name: 'Incident Sentinel',
    description: 'On-call hardener who keeps the lights on.',
    characterType: CharacterType.guardian,
    subclass: CharacterSubclass.sentinel,
    statsBoost: {'defense': 3, 'speed': 1},
    traits: ['vigilant', 'cool-under-fire'],
  ),
  CardPreset(
    id: 'guardian-paladin-compliance',
    name: 'Compliance Paladin',
    description: 'Audit-ready, policy-savvy gatekeeper.',
    characterType: CharacterType.guardian,
    subclass: CharacterSubclass.paladin,
    statsBoost: {'defense': 2, 'wisdom': 2},
    traits: ['principled', 'thorough'],
  ),

  // ── Artisan (frontend / UX) ───────────────────────────────────────────────
  CardPreset(
    id: 'artisan-painter-polish',
    name: 'Polish Painter',
    description: 'Pixel-perfect detail obsessive for shipping screens.',
    characterType: CharacterType.artisan,
    subclass: CharacterSubclass.painter,
    statsBoost: {'speed': 2, 'wisdom': 1, 'power': 1},
    traits: ['detail-oriented', 'visual'],
  ),
  CardPreset(
    id: 'artisan-weaver-ds',
    name: 'Design System Weaver',
    description: 'Component-architecture weaver for design-system scale.',
    characterType: CharacterType.artisan,
    subclass: CharacterSubclass.weaver,
    statsBoost: {'wisdom': 2, 'defense': 2},
    traits: ['systematic', 'reusable'],
  ),

  // ── Bard (creative / writing) ─────────────────────────────────────────────
  CardPreset(
    id: 'bard-storyteller-marketing',
    name: 'Marketing Storyteller',
    description: 'Brand voice + landing-page copy specialist.',
    characterType: CharacterType.bard,
    subclass: CharacterSubclass.storyteller,
    statsBoost: {'power': 2, 'speed': 2},
    traits: ['persuasive', 'on-brand'],
  ),
  CardPreset(
    id: 'bard-lyricist-script',
    name: 'Lyricist Scriptwriter',
    description: 'Punchy, rhythmic micro-copy for product surfaces.',
    characterType: CharacterType.bard,
    subclass: CharacterSubclass.lyricist,
    statsBoost: {'speed': 3, 'power': 1},
    traits: ['concise', 'rhythmic'],
  ),

  // ── Scholar (research / education) ────────────────────────────────────────
  CardPreset(
    id: 'scholar-professor-tutor',
    name: 'Tutor Professor',
    description: 'Clear, patient explainer for any audience.',
    characterType: CharacterType.scholar,
    subclass: CharacterSubclass.professor,
    statsBoost: {'wisdom': 3, 'defense': 1},
    traits: ['patient', 'pedagogical'],
  ),
  CardPreset(
    id: 'scholar-sage-research',
    name: 'Research Sage',
    description: 'Deep-dive synthesist — citations, summaries, citations.',
    characterType: CharacterType.scholar,
    subclass: CharacterSubclass.sage,
    statsBoost: {'wisdom': 4},
    traits: ['scholarly', 'cite-heavy'],
  ),

  // ── Merchant (business / sales) ───────────────────────────────────────────
  CardPreset(
    id: 'merchant-entrepreneur-launch',
    name: 'Launch Entrepreneur',
    description: 'Zero-to-one go-to-market generalist.',
    characterType: CharacterType.merchant,
    subclass: CharacterSubclass.entrepreneur,
    statsBoost: {'speed': 2, 'power': 2},
    traits: ['scrappy', 'opportunistic'],
  ),
  CardPreset(
    id: 'merchant-trader-pricing',
    name: 'Pricing Trader',
    description: 'Quantitative pricing & monetization specialist.',
    characterType: CharacterType.merchant,
    subclass: CharacterSubclass.trader,
    statsBoost: {'wisdom': 3, 'speed': 1},
    traits: ['quantitative', 'sharp'],
  ),

  // ── Universal (no character match required) ───────────────────────────────
  CardPreset(
    id: 'any-balanced',
    name: 'Balanced Generalist',
    description: 'Even +1 across all stats — safe baseline tune-up.',
    statsBoost: {'power': 1, 'wisdom': 1, 'speed': 1, 'defense': 1},
    traits: ['well-rounded'],
  ),
  CardPreset(
    id: 'any-high-charisma',
    name: 'High Charisma',
    description: 'Communication-first boost; works with any class.',
    statsBoost: {'power': 2, 'speed': 2},
    traits: ['communicator', 'collaborative'],
  ),
];

/// Filters [kCardPresets] by character type. Pass `null` to include only the
/// universal "any" presets. Pass a [CharacterType] to include matching presets
/// AND the universal ones (so the UI always has at least the baseline two).
List<CardPreset> presetsForCharacter(CharacterType? type) {
  return kCardPresets.where((p) {
    if (type == null) return p.characterType == null;
    return p.characterType == type || p.characterType == null;
  }).toList();
}

/// Pure-Dart applier: given a preset and the existing draft (stats + traits),
/// returns the merged result. Stats are clamped to the standard 1..10 range
/// to keep the radar chart readable; traits dedup case-insensitively.
({Map<String, int> stats, List<String> traits}) applyPresetToDraft({
  required CardPreset preset,
  required Map<String, int> existingStats,
  required List<String> existingTraits,
}) {
  final mergedStats = Map<String, int>.from(existingStats);
  for (final entry in preset.statsBoost.entries) {
    final cur = mergedStats[entry.key] ?? 0;
    mergedStats[entry.key] = (cur + entry.value).clamp(1, 10);
  }
  final lowerTraits = existingTraits.map((t) => t.toLowerCase()).toSet();
  final mergedTraits = List<String>.from(existingTraits);
  for (final t in preset.traits) {
    if (!lowerTraits.contains(t.toLowerCase())) {
      mergedTraits.add(t);
      lowerTraits.add(t.toLowerCase());
    }
  }
  return (stats: mergedStats, traits: mergedTraits);
}
