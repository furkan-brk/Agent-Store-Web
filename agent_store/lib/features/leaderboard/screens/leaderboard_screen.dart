// lib/features/leaderboard/screens/leaderboard_screen.dart

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../controllers/leaderboard_controller.dart';
import '../../../shared/widgets/skeleton_widgets.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// LeaderboardScreen — tabbed leaderboard with Top Creators, By Uses, By Rating.
// ═══════════════════════════════════════════════════════════════════════════════

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;
  late final LeaderboardController _ctrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _ctrl = Get.isRegistered<LeaderboardController>()
        ? Get.find<LeaderboardController>()
        : Get.put(LeaderboardController(), permanent: true);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Column(
        children: [
          // ── Header ───────────────────────────────────────────────────
          _buildHeader(context),
          // ── Tab bar ──────────────────────────────────────────────────
          _buildTabBar(),
          // ── Body ─────────────────────────────────────────────────────
          Expanded(
            child: Obx(() {
              if (_ctrl.isLoading.value) return _buildLoadingSkeleton();
              if (_ctrl.error.value != null) return _buildErrorState();

              final rankings = _ctrl.data.value?['rankings'] as List? ?? [];
              if (rankings.isEmpty) return _buildEmptyState();

              return TabBarView(
                controller: _tabCtrl,
                children: [
                  _buildRankingList(context, rankings, _SortMode.bySaves),
                  _buildRankingList(context, rankings, _SortMode.byUses),
                  _buildRankingList(context, rankings, _SortMode.byAgents),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  // ── Header with title + refresh ──────────────────────────────────────────

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
      ),
      child: Row(
        children: [
          // Crown icon
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.gold.withValues(alpha: 0.25),
                  AppTheme.gold.withValues(alpha: 0.08),
                ],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.workspace_premium_rounded,
              color: AppTheme.gold,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          // Title with gradient
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [AppTheme.textH, AppTheme.gold],
            ).createShader(bounds),
            child: const Text(
              'Leaderboard',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.3,
              ),
            ),
          ),
          const Spacer(),
          // Refresh button
          Obx(() => _HoverIconButton(
                icon: Icons.refresh_rounded,
                tooltip: 'Refresh',
                isLoading: _ctrl.isLoading.value,
                onPressed: () => _ctrl.load(),
              )),
        ],
      ),
    );
  }

  // ── Tab bar ──────────────────────────────────────────────────────────────

  Widget _buildTabBar() {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      child: TabBar(
        controller: _tabCtrl,
        labelColor: AppTheme.gold,
        unselectedLabelColor: AppTheme.textM,
        indicatorColor: AppTheme.gold,
        indicatorWeight: 2.5,
        labelStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 13,
          letterSpacing: 0.2,
        ),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 13,
        ),
        dividerColor: Colors.transparent,
        tabs: const [
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.bookmark_rounded, size: 15),
                SizedBox(width: 6),
                Text('Top by Saves'),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.play_circle_outline, size: 15),
                SizedBox(width: 6),
                Text('Top by Uses'),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.person_rounded, size: 15),
                SizedBox(width: 6),
                Text('Top Creators'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Loading skeleton ─────────────────────────────────────────────────────

  Widget _buildLoadingSkeleton() {
    return ShimmerScope(
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 8,
        itemBuilder: (_, i) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Container(
            height: 72,
            decoration: BoxDecoration(
              color: AppTheme.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.border),
            ),
            child: Row(
              children: [
                const SizedBox(width: 16),
                const ShimmerBox(
                  width: 36,
                  height: 36,
                  radius: 18,
                  color: AppTheme.card2,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ShimmerBox(
                        width: 120.0 + (i % 3) * 30.0,
                        height: 12,
                        radius: 4,
                        color: AppTheme.card2,
                      ),
                      const SizedBox(height: 8),
                      ShimmerBox(
                        width: 80.0 + (i % 2) * 20.0,
                        height: 9,
                        radius: 4,
                        color: AppTheme.card2,
                      ),
                    ],
                  ),
                ),
                const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    ShimmerBox(width: 50, height: 10, radius: 4, color: AppTheme.card2),
                    SizedBox(height: 6),
                    ShimmerBox(width: 70, height: 6, radius: 3, color: AppTheme.card2),
                  ],
                ),
                const SizedBox(width: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Error state ──────────────────────────────────────────────────────────

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.cloud_off_rounded,
            color: AppTheme.textM.withValues(alpha: 0.5),
            size: 48,
          ),
          const SizedBox(height: 16),
          Text(
            _ctrl.error.value ?? 'Something went wrong',
            style: const TextStyle(color: AppTheme.textM, fontSize: 14),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => _ctrl.load(),
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  // ── Empty state ──────────────────────────────────────────────────────────

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppTheme.gold.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.emoji_events_outlined,
              color: AppTheme.gold.withValues(alpha: 0.4),
              size: 36,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'No rankings yet',
            style: TextStyle(
              color: AppTheme.textH,
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Be the first to create an agent\nand climb the leaderboard!',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textM, fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => context.go('/create'),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Create Agent'),
          ),
        ],
      ),
    );
  }

  // ── Ranking list per sort mode ───────────────────────────────────────────

  Widget _buildRankingList(
    BuildContext context,
    List<dynamic> rankings,
    _SortMode mode,
  ) {
    // Sort a copy based on the selected tab
    final sorted = List<Map<String, dynamic>>.from(
      rankings.map((e) => e as Map<String, dynamic>),
    );
    switch (mode) {
      case _SortMode.bySaves:
        sorted.sort((a, b) =>
            ((b['total_saves'] as int?) ?? 0)
                .compareTo((a['total_saves'] as int?) ?? 0));
      case _SortMode.byUses:
        sorted.sort((a, b) =>
            ((b['total_uses'] as int?) ?? 0)
                .compareTo((a['total_uses'] as int?) ?? 0));
      case _SortMode.byAgents:
        sorted.sort((a, b) =>
            ((b['total_agents'] as int?) ?? 0)
                .compareTo((a['total_agents'] as int?) ?? 0));
    }

    // Find the max value for the progress bar normalization
    final maxVal = _maxValueForMode(sorted, mode);

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: sorted.length,
      itemBuilder: (context, index) {
        final entry = sorted[index];
        return _AnimatedRankRow(
          index: index,
          child: _RankCard(
            entry: entry,
            rank: index + 1,
            mode: mode,
            maxValue: maxVal,
          ),
        );
      },
    );
  }

  int _maxValueForMode(List<Map<String, dynamic>> sorted, _SortMode mode) {
    if (sorted.isEmpty) return 1;
    int max = 1;
    for (final e in sorted) {
      final v = switch (mode) {
        _SortMode.bySaves => (e['total_saves'] as int?) ?? 0,
        _SortMode.byUses => (e['total_uses'] as int?) ?? 0,
        _SortMode.byAgents => (e['total_agents'] as int?) ?? 0,
      };
      if (v > max) max = v;
    }
    return max;
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Sort mode enum
// ═══════════════════════════════════════════════════════════════════════════════

enum _SortMode { bySaves, byUses, byAgents }

// ═══════════════════════════════════════════════════════════════════════════════
// AnimatedRankRow — staggered fade-in + slide for each row.
// ═══════════════════════════════════════════════════════════════════════════════

class _AnimatedRankRow extends StatefulWidget {
  final int index;
  final Widget child;
  const _AnimatedRankRow({required this.index, required this.child});

  @override
  State<_AnimatedRankRow> createState() => _AnimatedRankRowState();
}

class _AnimatedRankRowState extends State<_AnimatedRankRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _opacity = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));

    // Stagger: each row delays by 60ms * index, capped at 600ms total
    final delay = Duration(milliseconds: math.min(widget.index * 60, 600));
    Future.delayed(delay, () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(
        position: _slide,
        child: widget.child,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// _RankCard — a single leaderboard row with rank badge, wallet info, stats,
// progress bar, and hover interaction.
// ═══════════════════════════════════════════════════════════════════════════════

class _RankCard extends StatefulWidget {
  final Map<String, dynamic> entry;
  final int rank;
  final _SortMode mode;
  final int maxValue;

  const _RankCard({
    required this.entry,
    required this.rank,
    required this.mode,
    required this.maxValue,
  });

  @override
  State<_RankCard> createState() => _RankCardState();
}

class _RankCardState extends State<_RankCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final rank = widget.rank;
    final wallet = widget.entry['wallet'] as String? ?? '';
    final totalAgents = widget.entry['total_agents'] as int? ?? 0;
    final totalSaves = widget.entry['total_saves'] as int? ?? 0;
    final totalUses = widget.entry['total_uses'] as int? ?? 0;

    final shortWallet = wallet.length > 10
        ? '${wallet.substring(0, 6)}...${wallet.substring(wallet.length - 4)}'
        : wallet;

    // Primary stat for the selected tab
    final primaryValue = switch (widget.mode) {
      _SortMode.bySaves => totalSaves,
      _SortMode.byUses => totalUses,
      _SortMode.byAgents => totalAgents,
    };
    final primaryLabel = switch (widget.mode) {
      _SortMode.bySaves => 'saves',
      _SortMode.byUses => 'uses',
      _SortMode.byAgents => 'agents',
    };
    final primaryIcon = switch (widget.mode) {
      _SortMode.bySaves => Icons.bookmark_rounded,
      _SortMode.byUses => Icons.play_circle_outline,
      _SortMode.byAgents => Icons.smart_toy_outlined,
    };

    final double progress =
        widget.maxValue > 0 ? primaryValue.toDouble() / widget.maxValue : 0.0;
    final isTopThree = rank <= 3;

    // Medal colors
    final (Color medalColor, Color medalBg) = switch (rank) {
      1 => (const Color(0xFFFFD700), const Color(0x30FFD700)),
      2 => (const Color(0xFFC0C0C0), const Color(0x25C0C0C0)),
      3 => (const Color(0xFFCD7F32), const Color(0x25CD7F32)),
      _ => (AppTheme.textM, Colors.transparent),
    };

    // Card border glow for top 3
    final borderColor =
        isTopThree ? medalColor.withValues(alpha: 0.45) : AppTheme.border;
    final cardGradient = isTopThree
        ? LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              medalColor.withValues(alpha: 0.07),
              Colors.transparent,
            ],
          )
        : null;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () {
          if (wallet.isNotEmpty) {
            context.go('/profile/$wallet');
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: _hovered ? AppTheme.card2 : AppTheme.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _hovered
                  ? (isTopThree
                      ? medalColor.withValues(alpha: 0.6)
                      : AppTheme.border2)
                  : borderColor,
            ),
            gradient: cardGradient,
            boxShadow: _hovered
                ? [
                    BoxShadow(
                      color: (isTopThree ? medalColor : AppTheme.primary)
                          .withValues(alpha: 0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              // ── Rank badge ──────────────────────────────────────────
              _buildRankBadge(rank, medalColor, medalBg),
              const SizedBox(width: 14),
              // ── Creator info ────────────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Wallet address
                    Row(
                      children: [
                        Icon(
                          Icons.person_rounded,
                          color: isTopThree ? medalColor : AppTheme.textM,
                          size: 14,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: SelectableText(
                            shortWallet,
                            style: TextStyle(
                              color: AppTheme.textH,
                              fontWeight:
                                  isTopThree ? FontWeight.w700 : FontWeight.w600,
                              fontSize: 14,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Stats row
                    Row(
                      children: [
                        _StatChip(
                          icon: Icons.smart_toy_outlined,
                          value: totalAgents,
                          label: 'agents',
                        ),
                        const SizedBox(width: 12),
                        _StatChip(
                          icon: Icons.bookmark_rounded,
                          value: totalSaves,
                          label: 'saves',
                        ),
                        const SizedBox(width: 12),
                        _StatChip(
                          icon: Icons.play_circle_outline,
                          value: totalUses,
                          label: 'uses',
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Progress bar for the active sort metric
                    _buildProgressBar(progress, medalColor, isTopThree),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              // ── Primary stat highlight ──────────────────────────────
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Icon(
                    primaryIcon,
                    color: isTopThree ? medalColor : AppTheme.primary,
                    size: 18,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$primaryValue',
                    style: TextStyle(
                      color: isTopThree ? medalColor : AppTheme.textH,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  Text(
                    primaryLabel,
                    style: const TextStyle(
                      color: AppTheme.textM,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
              // ── Chevron ─────────────────────────────────────────────
              const SizedBox(width: 8),
              AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: _hovered ? 1.0 : 0.3,
                child: const Icon(
                  Icons.chevron_right_rounded,
                  color: AppTheme.textM,
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Rank badge (medal for top 3, number for others) ──────────────────────

  Widget _buildRankBadge(int rank, Color medalColor, Color medalBg) {
    if (rank <= 3) {
      final medalIcon = switch (rank) {
        1 => Icons.looks_one_rounded,
        2 => Icons.looks_two_rounded,
        _ => Icons.looks_3_rounded,
      };
      return Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: medalBg,
          shape: BoxShape.circle,
          border: Border.all(
            color: medalColor.withValues(alpha: 0.5),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: medalColor.withValues(alpha: 0.2),
              blurRadius: 8,
            ),
          ],
        ),
        child: Icon(medalIcon, color: medalColor, size: 24),
      );
    }
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: AppTheme.card2,
        shape: BoxShape.circle,
        border: Border.all(color: AppTheme.border),
      ),
      child: Center(
        child: Text(
          '#$rank',
          style: const TextStyle(
            color: AppTheme.textB,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  // ── Progress bar ─────────────────────────────────────────────────────────

  Widget _buildProgressBar(
    double progress,
    Color medalColor,
    bool isTopThree,
  ) {
    final barColor = isTopThree ? medalColor : AppTheme.primary;
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: SizedBox(
        height: 4,
        child: LinearProgressIndicator(
          value: progress,
          backgroundColor: AppTheme.border.withValues(alpha: 0.4),
          color: barColor.withValues(alpha: 0.7),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// _StatChip — compact icon + number + label for inline stats.
// ═══════════════════════════════════════════════════════════════════════════════

class _StatChip extends StatelessWidget {
  final IconData icon;
  final int value;
  final String label;

  const _StatChip({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: AppTheme.textM, size: 11),
        const SizedBox(width: 3),
        Text(
          '$value',
          style: const TextStyle(
            color: AppTheme.textB,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// _HoverIconButton — an icon button with hover tint and optional spin
// when isLoading is true.
// ═══════════════════════════════════════════════════════════════════════════════

class _HoverIconButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final bool isLoading;
  final VoidCallback onPressed;

  const _HoverIconButton({
    required this.icon,
    required this.tooltip,
    required this.isLoading,
    required this.onPressed,
  });

  @override
  State<_HoverIconButton> createState() => _HoverIconButtonState();
}

class _HoverIconButtonState extends State<_HoverIconButton>
    with SingleTickerProviderStateMixin {
  bool _hovered = false;
  late final AnimationController _spinCtrl;

  @override
  void initState() {
    super.initState();
    _spinCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    if (widget.isLoading) _spinCtrl.repeat();
  }

  @override
  void didUpdateWidget(covariant _HoverIconButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isLoading && !_spinCtrl.isAnimating) {
      _spinCtrl.repeat();
    } else if (!widget.isLoading && _spinCtrl.isAnimating) {
      _spinCtrl.stop();
      _spinCtrl.reset();
    }
  }

  @override
  void dispose() {
    _spinCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Tooltip(
        message: widget.tooltip,
        child: GestureDetector(
          onTap: widget.isLoading ? null : widget.onPressed,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: _hovered
                  ? AppTheme.textM.withValues(alpha: 0.12)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: RotationTransition(
                turns: _spinCtrl,
                child: Icon(
                  widget.icon,
                  color: _hovered ? AppTheme.textH : AppTheme.textM,
                  size: 20,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
