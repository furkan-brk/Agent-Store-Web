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

  // Vintage / Fairy Tales character palette — saturated enough to stay distinct
  Color get primaryColor => const {
    CharacterType.wizard:     Color(0xFF6B3A8C), // muted violet
    CharacterType.strategist: Color(0xFF81231E), // crimson (matches app primary)
    CharacterType.oracle:     Color(0xFF9B7B1A), // antique gold
    CharacterType.guardian:   Color(0xFF2A4A5A), // steel teal
    CharacterType.artisan:    Color(0xFF8A3D62), // dusty rose
    CharacterType.bard:       Color(0xFF4A6A28), // forest green
    CharacterType.scholar:    Color(0xFF7A5028), // warm brown
    CharacterType.merchant:   Color(0xFF8B6A14), // antique amber
  }[this]!;

  Color get secondaryColor => const {
    CharacterType.wizard:     Color(0xFF2A1A3A), // deep purple-black
    CharacterType.strategist: Color(0xFF3A1010), // deep crimson-black
    CharacterType.oracle:     Color(0xFF2A1A08), // deep amber-black
    CharacterType.guardian:   Color(0xFF0E2028), // deep teal-black
    CharacterType.artisan:    Color(0xFF2A1020), // deep rose-black
    CharacterType.bard:       Color(0xFF1A2A08), // deep forest-black
    CharacterType.scholar:    Color(0xFF2A1E0E), // deep brown-black
    CharacterType.merchant:   Color(0xFF1E1808), // deep gold-black
  }[this]!;

  Color get accentColor => const {
    CharacterType.wizard:     Color(0xFFB09AC0), // muted lavender
    CharacterType.strategist: Color(0xFFD4A87A), // dusty warm gold
    CharacterType.oracle:     Color(0xFFD4B870), // antique yellow
    CharacterType.guardian:   Color(0xFF8AB0C0), // steel blue-grey
    CharacterType.artisan:    Color(0xFFC490A0), // blush rose
    CharacterType.bard:       Color(0xFF8AB068), // sage olive
    CharacterType.scholar:    Color(0xFFD8C090), // warm parchment
    CharacterType.merchant:   Color(0xFFCAB891), // parchment gold
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

  // Vintage rarity colors
  Color get color => const {
    CharacterRarity.common:    Color(0xFF8B8070), // warm parchment-grey
    CharacterRarity.uncommon:  Color(0xFF5F6A54), // sage green
    CharacterRarity.rare:      Color(0xFF4A6080), // steel blue
    CharacterRarity.epic:      Color(0xFF6B3A7A), // deep violet
    CharacterRarity.legendary: Color(0xFF9B7B1A), // antique gold
  }[this]!;

  List<Color> get gradientColors => {
    CharacterRarity.common:    [const Color(0xFF6B5E4A), const Color(0xFF3A3020)],
    CharacterRarity.uncommon:  [const Color(0xFF4A6A28), const Color(0xFF1E3010)],
    CharacterRarity.rare:      [const Color(0xFF2A4A6A), const Color(0xFF0E1E2A)],
    CharacterRarity.epic:      [const Color(0xFF5A2A6A), const Color(0xFF220C34)],
    CharacterRarity.legendary: [const Color(0xFF9B7B1A), const Color(0xFF3A2808)],
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
