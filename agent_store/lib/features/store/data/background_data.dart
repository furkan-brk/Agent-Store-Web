// lib/features/store/data/background_data.dart

class BackgroundInfo {
  final String id;
  final String name;
  final String assetPath;
  final List<String> tags;

  const BackgroundInfo({
    required this.id,
    required this.name,
    required this.assetPath,
    required this.tags,
  });
}

const backgrounds = <BackgroundInfo>[
  BackgroundInfo(
    id: 'arcane_library',
    name: 'Arcane Library',
    assetPath: 'assets/backgrounds/arcane_library.png',
    tags: ['backend', 'wizard', 'scholar', 'research'],
  ),
  BackgroundInfo(
    id: 'wizard_tower',
    name: 'Wizard Tower',
    assetPath: 'assets/backgrounds/wizard_tower.png',
    tags: ['backend', 'wizard', 'general'],
  ),
  BackgroundInfo(
    id: 'throne_room',
    name: 'Throne Room',
    assetPath: 'assets/backgrounds/throne_room.png',
    tags: ['strategist', 'business', 'general'],
  ),
  BackgroundInfo(
    id: 'war_tent',
    name: 'War Command Tent',
    assetPath: 'assets/backgrounds/war_tent.png',
    tags: ['strategist', 'general'],
  ),
  BackgroundInfo(
    id: 'observatory',
    name: 'Celestial Observatory',
    assetPath: 'assets/backgrounds/observatory.png',
    tags: ['oracle', 'data', 'research'],
  ),
  BackgroundInfo(
    id: 'crystal_cave',
    name: 'Crystal Cavern',
    assetPath: 'assets/backgrounds/crystal_cave.png',
    tags: ['oracle', 'data'],
  ),
  BackgroundInfo(
    id: 'fortress_wall',
    name: 'Fortress Battlements',
    assetPath: 'assets/backgrounds/fortress_wall.png',
    tags: ['guardian', 'security', 'general'],
  ),
  BackgroundInfo(
    id: 'castle_gate',
    name: 'Castle Gatehouse',
    assetPath: 'assets/backgrounds/castle_gate.png',
    tags: ['guardian', 'security'],
  ),
  BackgroundInfo(
    id: 'artisan_workshop',
    name: 'Artisan Workshop',
    assetPath: 'assets/backgrounds/artisan_workshop.png',
    tags: ['artisan', 'frontend', 'creative'],
  ),
  BackgroundInfo(
    id: 'gallery_hall',
    name: 'Royal Gallery',
    assetPath: 'assets/backgrounds/gallery_hall.png',
    tags: ['artisan', 'frontend'],
  ),
  BackgroundInfo(
    id: 'tavern_hearth',
    name: 'Tavern Hearth',
    assetPath: 'assets/backgrounds/tavern_hearth.png',
    tags: ['bard', 'creative', 'general'],
  ),
  BackgroundInfo(
    id: 'forest_clearing',
    name: 'Enchanted Forest',
    assetPath: 'assets/backgrounds/forest_clearing.png',
    tags: ['bard', 'creative'],
  ),
  BackgroundInfo(
    id: 'monastery',
    name: 'Monastery Scriptorium',
    assetPath: 'assets/backgrounds/monastery.png',
    tags: ['scholar', 'research'],
  ),
  BackgroundInfo(
    id: 'ancient_archive',
    name: 'Ancient Archive',
    assetPath: 'assets/backgrounds/ancient_archive.png',
    tags: ['scholar', 'research', 'data'],
  ),
  BackgroundInfo(
    id: 'market_square',
    name: 'Market Square',
    assetPath: 'assets/backgrounds/market_square.png',
    tags: ['merchant', 'business'],
  ),
  BackgroundInfo(
    id: 'trading_port',
    name: 'Trading Harbor',
    assetPath: 'assets/backgrounds/trading_port.png',
    tags: ['merchant', 'business'],
  ),
  BackgroundInfo(
    id: 'alchemy_lab',
    name: 'Alchemist Lab',
    assetPath: 'assets/backgrounds/alchemy_lab.png',
    tags: ['wizard', 'oracle', 'backend', 'data'],
  ),
  BackgroundInfo(
    id: 'training_grounds',
    name: 'Training Grounds',
    assetPath: 'assets/backgrounds/training_grounds.png',
    tags: ['strategist', 'guardian', 'general'],
  ),
  BackgroundInfo(
    id: 'royal_court',
    name: 'Royal Court',
    assetPath: 'assets/backgrounds/royal_court.png',
    tags: ['strategist', 'merchant', 'business'],
  ),
  BackgroundInfo(
    id: 'enchanted_garden',
    name: 'Enchanted Garden',
    assetPath: 'assets/backgrounds/enchanted_garden.png',
    tags: ['artisan', 'bard', 'creative', 'general'],
  ),
];

/// Set of background IDs that have actual generated PNG assets.
/// If a matched background is not in this set, use gradient fallback instead.
const generatedBackgrounds = <String>{
  'arcane_library', 'castle_gate', 'crystal_cave', 'enchanted_garden',
  'fortress_wall', 'gallery_hall', 'observatory', 'royal_court',
  'tavern_hearth', 'throne_room', 'forest_clearing', 'monastery',
  'ancient_archive', 'war_tent', 'trading_port', 'wizard_tower', 'alchemy_lab',
};

/// Find the best matching background for an agent based on its category and character type.
/// Character type match (score +3) is weighted higher than category (score +2).
/// Falls back to a "general" tagged background if no specific match is found.
BackgroundInfo matchBackground(String category, String characterType) {
  int bestScore = -1;
  BackgroundInfo best = backgrounds.first;

  for (final bg in backgrounds) {
    int score = 0;
    if (bg.tags.contains(category.toLowerCase())) score += 2;
    if (bg.tags.contains(characterType.toLowerCase())) score += 3;
    if (bg.tags.contains('general')) score += 1;
    if (score > bestScore) {
      bestScore = score;
      best = bg;
    }
  }
  return best;
}
