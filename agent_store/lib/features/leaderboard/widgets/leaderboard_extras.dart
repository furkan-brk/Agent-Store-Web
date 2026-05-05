// v3.11.4: Leaderboard extension widgets — kept separate from the
// 1005-LOC leaderboard_screen.dart so the new functionality can ship
// without churning the existing layout.
//
// Three independent widgets:
//   * CategoryLeaderboardSection — dropdown + top 10 per category
//   * YouAreHereRail              — wallet's rank + 4 neighbors
//   * WeeklyRewardsTab            — recent 4 weeks of leader payouts
//
// Each widget owns its own fetch + state and accepts an override for tests.

import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../shared/services/api_service.dart';
import '../../character/character_types.dart';

// ─── Category leaderboard ────────────────────────────────────────────────

typedef CategoryLeaderboardFetcher =
    Future<List<Map<String, dynamic>>> Function(String category, String window);

class CategoryLeaderboardSection extends StatefulWidget {
  /// Optional initial category — defaults to "backend" (Wizard's domain).
  final String initialCategory;
  final String window;
  final CategoryLeaderboardFetcher? fetchOverride;

  const CategoryLeaderboardSection({
    super.key,
    this.initialCategory = 'backend',
    this.window = 'all',
    this.fetchOverride,
  });

  @override
  State<CategoryLeaderboardSection> createState() => _CategoryLeaderboardSectionState();
}

class _CategoryLeaderboardSectionState extends State<CategoryLeaderboardSection> {
  late String _category;
  bool _loading = true;
  List<Map<String, dynamic>> _rows = const [];

  // Categories aligned with backend categoryLabels (services/agent/service.go).
  // Keys are lowercase strings sent to /leaderboard/category/:cat.
  static const _categories = <(String, String)>[
    ('backend', 'Backend'),
    ('frontend', 'Frontend'),
    ('data', 'Data'),
    ('security', 'Security'),
    ('design', 'Design'),
    ('writing', 'Writing'),
    ('research', 'Research'),
    ('business', 'Business'),
  ];

  @override
  void initState() {
    super.initState();
    _category = widget.initialCategory;
    _load();
  }

  @override
  void didUpdateWidget(CategoryLeaderboardSection old) {
    super.didUpdateWidget(old);
    if (old.window != widget.window) _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final fn = widget.fetchOverride ??
        (cat, win) => ApiService.instance.getLeaderboardByCategory(cat, window: win);
    final rows = await fn(_category, widget.window);
    if (!mounted) return;
    setState(() {
      _rows = rows;
      _loading = false;
    });
  }

  void _selectCategory(String cat) {
    if (cat == _category) return;
    setState(() => _category = cat);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.category_outlined, color: AppTheme.gold, size: 18),
            const SizedBox(width: 8),
            const Text(
              'Top by category',
              style: TextStyle(
                color: AppTheme.textH,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 16),
            Flexible(
              child: DropdownButton<String>(
                value: _category,
                isDense: true,
                underline: const SizedBox.shrink(),
                items: _categories
                    .map((p) => DropdownMenuItem(value: p.$1, child: Text(p.$2)))
                    .toList(),
                onChanged: (v) => _selectCategory(v ?? _category),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          )
        else if (_rows.isEmpty)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              'No creators ranked in this category yet.',
              style: TextStyle(color: AppTheme.textM.withValues(alpha: 0.85), fontSize: 12),
            ),
          )
        else
          Column(children: _rows.map(_buildRow).toList()),
      ],
    );
  }

  Widget _buildRow(Map<String, dynamic> row) {
    final rank = row['rank'] ?? 0;
    final wallet = row['wallet']?.toString() ?? '';
    final saves = row['total_saves'] ?? 0;
    final agents = row['total_agents'] ?? 0;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.card.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '#$rank',
              style: TextStyle(
                color: rank == 1 ? AppTheme.gold : AppTheme.textM,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              _truncWallet(wallet),
              style: const TextStyle(color: AppTheme.textH, fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            '$saves saves · $agents agents',
            style: const TextStyle(color: AppTheme.textM, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

String _truncWallet(String w) {
  if (w.length <= 12) return w;
  return '${w.substring(0, 6)}…${w.substring(w.length - 4)}';
}

// ─── You are here rail ───────────────────────────────────────────────────

typedef UserRankFetcher = Future<Map<String, dynamic>?> Function(String window);

class YouAreHereRail extends StatefulWidget {
  final String window;
  final UserRankFetcher? fetchOverride;

  const YouAreHereRail({super.key, this.window = 'all', this.fetchOverride});

  @override
  State<YouAreHereRail> createState() => _YouAreHereRailState();
}

class _YouAreHereRailState extends State<YouAreHereRail> {
  Map<String, dynamic>? _data;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(YouAreHereRail old) {
    super.didUpdateWidget(old);
    if (old.window != widget.window) _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final fn = widget.fetchOverride ??
        (w) => ApiService.instance.getUserRank(window: w);
    final data = await fn(widget.window);
    if (!mounted) return;
    setState(() {
      _data = data;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    final data = _data;
    if (data == null) return const SizedBox.shrink();

    final rank = data['rank'] ?? 0;
    final total = data['total_creators'] ?? 0;
    final neighbors = (data['neighbors'] as List? ?? const [])
        .cast<Map<String, dynamic>>();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.gold.withValues(alpha: 0.08),
        border: Border.all(color: AppTheme.gold.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.my_location, color: AppTheme.gold, size: 18),
              const SizedBox(width: 8),
              Text(
                rank > 0 ? 'Your rank: #$rank of $total' : 'Not ranked yet — keep creating!',
                style: const TextStyle(
                  color: AppTheme.textH,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...neighbors.map(_buildNeighborRow),
        ],
      ),
    );
  }

  Widget _buildNeighborRow(Map<String, dynamic> n) {
    final rank = n['rank'] ?? 0;
    final wallet = n['wallet']?.toString() ?? '';
    final saves = n['total_saves'] ?? 0;
    final isMe = n['is_me'] == true;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isMe ? AppTheme.gold.withValues(alpha: 0.15) : Colors.transparent,
        borderRadius: BorderRadius.circular(4),
        border: isMe
            ? Border.all(color: AppTheme.gold.withValues(alpha: 0.6))
            : null,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text('#$rank',
                style: TextStyle(
                  color: isMe ? AppTheme.gold : AppTheme.textM,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                )),
          ),
          Expanded(
            child: Text(
              isMe ? 'You · ${_truncWallet(wallet)}' : _truncWallet(wallet),
              style: TextStyle(
                color: isMe ? AppTheme.textH : AppTheme.textM,
                fontSize: 12,
                fontWeight: isMe ? FontWeight.w600 : FontWeight.normal,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text('$saves saves',
              style: const TextStyle(color: AppTheme.textM, fontSize: 11)),
        ],
      ),
    );
  }
}

// ─── Weekly rewards tab ──────────────────────────────────────────────────

typedef WeeklyRewardsFetcher = Future<List<Map<String, dynamic>>> Function(int weeks);

class WeeklyRewardsList extends StatefulWidget {
  final int weeks;
  final WeeklyRewardsFetcher? fetchOverride;

  const WeeklyRewardsList({
    super.key,
    this.weeks = 4,
    this.fetchOverride,
  });

  @override
  State<WeeklyRewardsList> createState() => _WeeklyRewardsListState();
}

class _WeeklyRewardsListState extends State<WeeklyRewardsList> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = (widget.fetchOverride ??
        (w) => ApiService.instance.getWeeklyRewards(weeks: w))(widget.weeks);
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
            padding: const EdgeInsets.all(12),
            child: Text(
              'No weekly rewards distributed yet — admin awards every Monday.',
              style: TextStyle(color: AppTheme.textM.withValues(alpha: 0.85), fontSize: 12),
            ),
          );
        }
        // Group by week for a cleaner section view.
        final byWeek = <String, List<Map<String, dynamic>>>{};
        for (final r in rows) {
          (byWeek[r['week']?.toString() ?? ''] ??= []).add(r);
        }
        final weeks = byWeek.keys.toList()..sort((a, b) => b.compareTo(a));
        return Column(
          children: weeks.map((wk) => _buildWeekBlock(wk, byWeek[wk]!)).toList(),
        );
      },
    );
  }

  Widget _buildWeekBlock(String week, List<Map<String, dynamic>> rewards) {
    rewards.sort((a, b) => (a['rank'] as int? ?? 99).compareTo(b['rank'] as int? ?? 99));
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.card.withValues(alpha: 0.5),
        border: Border.all(color: AppTheme.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(week,
              style: const TextStyle(
                color: AppTheme.gold, fontSize: 13, fontWeight: FontWeight.w700,
              )),
          const SizedBox(height: 6),
          ...rewards.map((r) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    SizedBox(
                      width: 30,
                      child: Text('#${r['rank']}',
                          style: const TextStyle(
                              color: AppTheme.textM, fontSize: 12, fontWeight: FontWeight.w600)),
                    ),
                    Expanded(
                      child: Text(_truncWallet(r['wallet']?.toString() ?? ''),
                          style: const TextStyle(color: AppTheme.textH, fontSize: 12)),
                    ),
                    Text('+${r['credits']} credits',
                        style: const TextStyle(color: AppTheme.gold, fontSize: 12)),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

// Helper for unused CharacterType import (will be needed for category↔type mapping in v3.11.5).
// Suppresses tree-shake warnings in case this section is mounted standalone.
// ignore: unused_element
CharacterType _placeholder() => CharacterType.wizard;
