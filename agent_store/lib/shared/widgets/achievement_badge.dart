import 'package:flutter/material.dart';

// ── Achievement model ────────────────────────────────────────────────────────

class Achievement {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final bool unlocked;

  const Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.unlocked,
  });

  /// Computes the full list of achievements based on user stats.
  static List<Achievement> compute({
    required int agentCount,
    required int totalSaves,
    required int totalUses,
    required int libraryCount,
    required int credits,
  }) {
    return [
      Achievement(
        id: 'first_agent',
        title: 'First Agent',
        description: 'Created your first agent',
        icon: Icons.auto_fix_high,
        color: const Color(0xFF6366F1),
        unlocked: agentCount >= 1,
      ),
      Achievement(
        id: 'creator_5',
        title: 'Prolific Creator',
        description: 'Created 5 agents',
        icon: Icons.rocket_launch_outlined,
        color: const Color(0xFF8B5CF6),
        unlocked: agentCount >= 5,
      ),
      Achievement(
        id: 'saves_10',
        title: 'Popular',
        description: 'Your agents saved 10 times',
        icon: Icons.bookmark,
        color: const Color(0xFF10B981),
        unlocked: totalSaves >= 10,
      ),
      Achievement(
        id: 'saves_50',
        title: 'Influencer',
        description: 'Your agents saved 50 times',
        icon: Icons.star,
        color: const Color(0xFFF59E0B),
        unlocked: totalSaves >= 50,
      ),
      Achievement(
        id: 'uses_100',
        title: 'Utility Master',
        description: 'Agents used 100 times',
        icon: Icons.bolt,
        color: const Color(0xFFEAB308),
        unlocked: totalUses >= 100,
      ),
      Achievement(
        id: 'collector_10',
        title: 'Collector',
        description: 'Saved 10 agents to library',
        icon: Icons.collections_bookmark,
        color: const Color(0xFF3B82F6),
        unlocked: libraryCount >= 10,
      ),
      Achievement(
        id: 'wealthy',
        title: 'Wealthy',
        description: 'Earned 100+ credits',
        icon: Icons.monetization_on_outlined,
        color: const Color(0xFFD97706),
        unlocked: credits >= 100,
      ),
      const Achievement(
        id: 'legendary',
        title: 'Legend',
        description: 'Created a legendary agent',
        icon: Icons.workspace_premium,
        color: Color(0xFFF59E0B),
        unlocked: false, // requires backend rarity check
      ),
    ];
  }
}

// ── AchievementBadge widget ──────────────────────────────────────────────────

class AchievementBadge extends StatelessWidget {
  final Achievement achievement;

  const AchievementBadge({super.key, required this.achievement});

  @override
  Widget build(BuildContext context) {
    final unlocked = achievement.unlocked;
    final color = unlocked ? achievement.color : const Color(0xFF4B5563);
    final opacity = unlocked ? 1.0 : 0.4;

    return Tooltip(
      message: '${achievement.title}\n${achievement.description}',
      preferBelow: false,
      textStyle: const TextStyle(color: Colors.white, fontSize: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF374151)),
      ),
      child: Opacity(
        opacity: opacity,
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withAlpha(unlocked ? 30 : 20),
            border: Border.all(
              color: color.withAlpha(unlocked ? 153 : 77),
              width: unlocked ? 2.0 : 1.0,
            ),
            boxShadow: unlocked
                ? [
                    BoxShadow(
                      color: color.withAlpha(77),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: Icon(
            achievement.icon,
            color: color,
            size: 20,
          ),
        ),
      ),
    );
  }
}

// ── AchievementRow widget ────────────────────────────────────────────────────

class AchievementRow extends StatelessWidget {
  final List<Achievement> achievements;

  const AchievementRow({super.key, required this.achievements});

  @override
  Widget build(BuildContext context) {
    final unlockedCount = achievements.where((a) => a.unlocked).length;
    final total = achievements.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Achievements',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withAlpha(30),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFF6366F1).withAlpha(77),
                ),
              ),
              child: Text(
                '$unlockedCount / $total unlocked',
                style: const TextStyle(
                  color: Color(0xFF6366F1),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: achievements
              .map((a) => AchievementBadge(achievement: a))
              .toList(),
        ),
      ],
    );
  }
}
