import 'package:flutter/material.dart';

enum CharacterType { wizard, strategist, oracle, guardian, artisan, bard, scholar, merchant }

enum CharacterRarity { common, uncommon, rare, epic, legendary }

// 24 subclasses — 3 per base type
enum CharacterSubclass {
  // Wizard
  archmage, sorcerer, hexMaster,
  // Strategist
  warCommander, tactician, diplomat,
  // Oracle
  prophet, analyst, seer,
  // Guardian
  sentinel, warden, paladin,
  // Artisan
  sculptor, weaver, painter,
  // Bard
  storyteller, lyricist, chronicler,
  // Scholar
  sage, professor, librarian,
  // Merchant
  entrepreneur, trader, ambassador,
}

extension CharacterTypeExt on CharacterType {
  String get displayName => const {
    CharacterType.wizard: 'Wizard', CharacterType.strategist: 'Strategist',
    CharacterType.oracle: 'Oracle', CharacterType.guardian: 'Guardian',
    CharacterType.artisan: 'Artisan', CharacterType.bard: 'Bard',
    CharacterType.scholar: 'Scholar', CharacterType.merchant: 'Merchant',
  }[this]!;

  String get description => const {
    CharacterType.wizard:     'Master of code and backend sorcery',
    CharacterType.strategist: 'Commander of plans and roadmaps',
    CharacterType.oracle:     'Seer of data and hidden insights',
    CharacterType.guardian:   'Defender of systems and security',
    CharacterType.artisan:    'Crafter of beautiful interfaces',
    CharacterType.bard:       'Weaver of words and stories',
    CharacterType.scholar:    'Seeker of knowledge and wisdom',
    CharacterType.merchant:   'Dealer of growth and strategy',
  }[this]!;

  Color get primaryColor => const {
    CharacterType.wizard:     Color(0xFF7C3AED),
    CharacterType.strategist: Color(0xFFDC2626),
    CharacterType.oracle:     Color(0xFFD97706),
    CharacterType.guardian:   Color(0xFF1D4ED8),
    CharacterType.artisan:    Color(0xFFEC4899),
    CharacterType.bard:       Color(0xFF16A34A),
    CharacterType.scholar:    Color(0xFF92400E),
    CharacterType.merchant:   Color(0xFFB45309),
  }[this]!;

  Color get secondaryColor => const {
    CharacterType.wizard:     Color(0xFF1E1B4B),
    CharacterType.strategist: Color(0xFF78350F),
    CharacterType.oracle:     Color(0xFF7C2D12),
    CharacterType.guardian:   Color(0xFF1E3A5F),
    CharacterType.artisan:    Color(0xFF0E7490),
    CharacterType.bard:       Color(0xFF713F12),
    CharacterType.scholar:    Color(0xFF44403C),
    CharacterType.merchant:   Color(0xFF1E3A5F),
  }[this]!;

  Color get accentColor => const {
    CharacterType.wizard:     Color(0xFFA78BFA),
    CharacterType.strategist: Color(0xFFFCD34D),
    CharacterType.oracle:     Color(0xFFFDE68A),
    CharacterType.guardian:   Color(0xFF93C5FD),
    CharacterType.artisan:    Color(0xFF67E8F9),
    CharacterType.bard:       Color(0xFFBEF264),
    CharacterType.scholar:    Color(0xFFFEF3C7),
    CharacterType.merchant:   Color(0xFFFCD34D),
  }[this]!;

  /// Subclasses belonging to this type
  List<CharacterSubclass> get subclasses => const {
    CharacterType.wizard:     [CharacterSubclass.archmage, CharacterSubclass.sorcerer, CharacterSubclass.hexMaster],
    CharacterType.strategist: [CharacterSubclass.warCommander, CharacterSubclass.tactician, CharacterSubclass.diplomat],
    CharacterType.oracle:     [CharacterSubclass.prophet, CharacterSubclass.analyst, CharacterSubclass.seer],
    CharacterType.guardian:   [CharacterSubclass.sentinel, CharacterSubclass.warden, CharacterSubclass.paladin],
    CharacterType.artisan:    [CharacterSubclass.sculptor, CharacterSubclass.weaver, CharacterSubclass.painter],
    CharacterType.bard:       [CharacterSubclass.storyteller, CharacterSubclass.lyricist, CharacterSubclass.chronicler],
    CharacterType.scholar:    [CharacterSubclass.sage, CharacterSubclass.professor, CharacterSubclass.librarian],
    CharacterType.merchant:   [CharacterSubclass.entrepreneur, CharacterSubclass.trader, CharacterSubclass.ambassador],
  }[this]!;
}

extension CharacterSubclassExt on CharacterSubclass {
  String get displayName => const {
    CharacterSubclass.archmage:     'Archmage',
    CharacterSubclass.sorcerer:     'Sorcerer',
    CharacterSubclass.hexMaster:    'Hex Master',
    CharacterSubclass.warCommander: 'War Commander',
    CharacterSubclass.tactician:    'Tactician',
    CharacterSubclass.diplomat:     'Diplomat',
    CharacterSubclass.prophet:      'Prophet',
    CharacterSubclass.analyst:      'Analyst',
    CharacterSubclass.seer:         'Seer',
    CharacterSubclass.sentinel:     'Sentinel',
    CharacterSubclass.warden:       'Warden',
    CharacterSubclass.paladin:      'Paladin',
    CharacterSubclass.sculptor:     'Sculptor',
    CharacterSubclass.weaver:       'Weaver',
    CharacterSubclass.painter:      'Painter',
    CharacterSubclass.storyteller:  'Storyteller',
    CharacterSubclass.lyricist:     'Lyricist',
    CharacterSubclass.chronicler:   'Chronicler',
    CharacterSubclass.sage:         'Sage',
    CharacterSubclass.professor:    'Professor',
    CharacterSubclass.librarian:    'Librarian',
    CharacterSubclass.entrepreneur: 'Entrepreneur',
    CharacterSubclass.trader:       'Trader',
    CharacterSubclass.ambassador:   'Ambassador',
  }[this]!;

  /// Internal key matching backend subclass value
  String get key => const {
    CharacterSubclass.archmage:     'archmage',
    CharacterSubclass.sorcerer:     'sorcerer',
    CharacterSubclass.hexMaster:    'hex_master',
    CharacterSubclass.warCommander: 'war_commander',
    CharacterSubclass.tactician:    'tactician',
    CharacterSubclass.diplomat:     'diplomat',
    CharacterSubclass.prophet:      'prophet',
    CharacterSubclass.analyst:      'analyst',
    CharacterSubclass.seer:         'seer',
    CharacterSubclass.sentinel:     'sentinel',
    CharacterSubclass.warden:       'warden',
    CharacterSubclass.paladin:      'paladin',
    CharacterSubclass.sculptor:     'sculptor',
    CharacterSubclass.weaver:       'weaver',
    CharacterSubclass.painter:      'painter',
    CharacterSubclass.storyteller:  'storyteller',
    CharacterSubclass.lyricist:     'lyricist',
    CharacterSubclass.chronicler:   'chronicler',
    CharacterSubclass.sage:         'sage',
    CharacterSubclass.professor:    'professor',
    CharacterSubclass.librarian:    'librarian',
    CharacterSubclass.entrepreneur: 'entrepreneur',
    CharacterSubclass.trader:       'trader',
    CharacterSubclass.ambassador:   'ambassador',
  }[this]!;

  String get itemDescription => const {
    CharacterSubclass.archmage:     'Crown · Crystal staff',
    CharacterSubclass.sorcerer:     'Wide hat · Fireball',
    CharacterSubclass.hexMaster:    'Hood · Grimoire',
    CharacterSubclass.warCommander: 'Warhelm · Sword',
    CharacterSubclass.tactician:    'Beret · Map scroll',
    CharacterSubclass.diplomat:     'Top hat · Fan',
    CharacterSubclass.prophet:      'Halo · Crystal ball',
    CharacterSubclass.analyst:      'Visor · Data tablet',
    CharacterSubclass.seer:         'Diadem · Orb',
    CharacterSubclass.sentinel:     'Combat helm · Dagger',
    CharacterSubclass.warden:       'Monitor helm · Shield',
    CharacterSubclass.paladin:      'Crown · Scales',
    CharacterSubclass.sculptor:     'Goggle frames · Brush',
    CharacterSubclass.weaver:       'Headband · Component grid',
    CharacterSubclass.painter:      'Beret · Palette',
    CharacterSubclass.storyteller:  'Feathered hat · Quill',
    CharacterSubclass.lyricist:     'Headset · Notepad',
    CharacterSubclass.chronicler:   'Glasses · Scroll',
    CharacterSubclass.sage:         'Flowing hair · Ancient tome',
    CharacterSubclass.professor:    'Mortarboard · Chalk',
    CharacterSubclass.librarian:    'Reading glasses · File box',
    CharacterSubclass.entrepreneur: 'Hoodie · Rocket',
    CharacterSubclass.trader:       'Fedora · Coin stack',
    CharacterSubclass.ambassador:   'Crown · Flag',
  }[this]!;
}

extension CharacterRarityExt on CharacterRarity {
  String get displayName => const {
    CharacterRarity.common: 'Common', CharacterRarity.uncommon: 'Uncommon',
    CharacterRarity.rare: 'Rare', CharacterRarity.epic: 'Epic',
    CharacterRarity.legendary: 'Legendary',
  }[this]!;

  Color get color => const {
    CharacterRarity.common:    Color(0xFF9CA3AF),
    CharacterRarity.uncommon:  Color(0xFF22C55E),
    CharacterRarity.rare:      Color(0xFF3B82F6),
    CharacterRarity.epic:      Color(0xFFA855F7),
    CharacterRarity.legendary: Color(0xFFF59E0B),
  }[this]!;

  List<Color> get gradientColors => {
    CharacterRarity.common:    [const Color(0xFF6B7280), const Color(0xFF374151)],
    CharacterRarity.uncommon:  [const Color(0xFF16A34A), const Color(0xFF065F46)],
    CharacterRarity.rare:      [const Color(0xFF2563EB), const Color(0xFF1E1B4B)],
    CharacterRarity.epic:      [const Color(0xFF9333EA), const Color(0xFF4C1D95)],
    CharacterRarity.legendary: [const Color(0xFFD97706), const Color(0xFF92400E)],
  }[this]!;

  static CharacterRarity fromString(String s) => switch (s.toLowerCase()) {
    'uncommon'  => CharacterRarity.uncommon,
    'rare'      => CharacterRarity.rare,
    'epic'      => CharacterRarity.epic,
    'legendary' => CharacterRarity.legendary,
    _           => CharacterRarity.common,
  };
}

CharacterType characterTypeFromString(String s) => switch (s.toLowerCase()) {
  'strategist' => CharacterType.strategist,
  'oracle'     => CharacterType.oracle,
  'guardian'   => CharacterType.guardian,
  'artisan'    => CharacterType.artisan,
  'bard'       => CharacterType.bard,
  'scholar'    => CharacterType.scholar,
  'merchant'   => CharacterType.merchant,
  _            => CharacterType.wizard,
};

CharacterSubclass subclassFromString(String s) => switch (s.toLowerCase().replaceAll(' ', '_')) {
  'archmage'      => CharacterSubclass.archmage,
  'sorcerer'      => CharacterSubclass.sorcerer,
  'hex_master'    => CharacterSubclass.hexMaster,
  'war_commander' => CharacterSubclass.warCommander,
  'tactician'     => CharacterSubclass.tactician,
  'diplomat'      => CharacterSubclass.diplomat,
  'prophet'       => CharacterSubclass.prophet,
  'analyst'       => CharacterSubclass.analyst,
  'seer'          => CharacterSubclass.seer,
  'sentinel'      => CharacterSubclass.sentinel,
  'warden'        => CharacterSubclass.warden,
  'paladin'       => CharacterSubclass.paladin,
  'sculptor'      => CharacterSubclass.sculptor,
  'weaver'        => CharacterSubclass.weaver,
  'painter'       => CharacterSubclass.painter,
  'storyteller'   => CharacterSubclass.storyteller,
  'lyricist'      => CharacterSubclass.lyricist,
  'chronicler'    => CharacterSubclass.chronicler,
  'sage'          => CharacterSubclass.sage,
  'professor'     => CharacterSubclass.professor,
  'librarian'     => CharacterSubclass.librarian,
  'entrepreneur'  => CharacterSubclass.entrepreneur,
  'trader'        => CharacterSubclass.trader,
  'ambassador'    => CharacterSubclass.ambassador,
  _               => CharacterSubclass.archmage,
};
