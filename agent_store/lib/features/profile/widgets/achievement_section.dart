// v3.11.4: Backend-driven achievement section for the public profile.
//
// Renders the badges earned by [wallet]. Reuses lib/shared/widgets/
// achievement_badge.dart unchanged — this file is only the section that
// fetches the data and maps backend rows to the existing AchievementBadge
// model.
//
// Backend endpoint: GET /api/v1/users/:wallet/achievements (public).

import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../shared/services/api_service.dart';
import '../../../shared/widgets/achievement_badge.dart' as ach;

typedef AchievementsFetcher = Future<List<Map<String, dynamic>>> Function(String wallet);

class AchievementSection extends StatefulWidget {
  final String wallet;

  /// Test seam: inject a stub fetcher to bypass ApiService.instance.
  final AchievementsFetcher? fetchOverride;

  const AchievementSection({
    super.key,
    required this.wallet,
    this.fetchOverride,
  });

  @override
  State<AchievementSection> createState() => _AchievementSectionState();
}

class _AchievementSectionState extends State<AchievementSection> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = (widget.fetchOverride ??
        (w) => ApiService.instance.getAchievements(w))(widget.wallet);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        final rows = snap.data ?? const <Map<String, dynamic>>[];
        if (rows.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'No achievements yet — create an agent or fork one to earn your first badge.',
              style: TextStyle(color: AppTheme.textM.withValues(alpha: 0.85), fontSize: 12),
            ),
          );
        }

        // Map the backend rows ({wallet, type, earned_at}) to the static
        // catalogue of badge presentations defined in achievement_badge.dart.
        final earnedTypes = <String>{
          for (final r in rows) (r['type'] ?? '').toString(),
        };
        final all = _BadgeCatalogue.compute(earnedTypes);
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: ach.AchievementRow(achievements: all),
        );
      },
    );
  }
}

// ── Catalogue ─────────────────────────────────────────────────────────────

/// Maps the v3.11.4 backend achievement type constants to FE badge metadata.
/// Keep this list in sync with `pkg/models/achievement.go::Achievement*`.
class _BadgeCatalogue {
  static List<ach.Achievement> compute(Set<String> earnedTypes) {
    return _all.map((tpl) => ach.Achievement(
          id: tpl.id,
          title: tpl.title,
          description: tpl.description,
          icon: tpl.icon,
          color: tpl.color,
          unlocked: earnedTypes.contains(tpl.id),
        )).toList();
  }

  static const _all = [
    _BadgeTpl(
      id: 'first_agent',
      title: 'First Agent',
      description: 'Created your first agent.',
      icon: Icons.auto_fix_high,
      color: Color(0xFF81231E),
    ),
    _BadgeTpl(
      id: 'first_sale',
      title: 'First Sale',
      description: 'One of your agents was purchased.',
      icon: Icons.attach_money,
      color: Color(0xFF9B7B1A),
    ),
    _BadgeTpl(
      id: 'first_fork',
      title: 'First Fork',
      description: 'Forked an existing agent into your own.',
      icon: Icons.call_split,
      color: Color(0xFF5A8A48),
    ),
    _BadgeTpl(
      id: 'hundred_saves',
      title: 'Hundred Saves',
      description: 'Your agents accumulated 100+ library saves.',
      icon: Icons.bookmark,
      color: Color(0xFF9B7B1A),
    ),
    _BadgeTpl(
      id: 'top_creator',
      title: 'Top Creator',
      description: 'Reached the top 10 leaderboard window.',
      icon: Icons.workspace_premium,
      color: Color(0xFF9B7B1A),
    ),
  ];
}

class _BadgeTpl {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  const _BadgeTpl({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
  });
}
