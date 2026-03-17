// lib/features/store/widgets/trending_row.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme.dart';
import '../../../controllers/store_controller.dart';
import '../../../shared/models/agent_model.dart';
import '../../../shared/widgets/pixel_character_widget.dart';
import '../../character/character_types.dart';

class TrendingRow extends StatefulWidget {
  const TrendingRow({super.key});

  @override
  State<TrendingRow> createState() => _TrendingRowState();
}

class _TrendingRowState extends State<TrendingRow> {
  late final ScrollController _scrollCtrl;
  bool _canScrollLeft = false;
  bool _canScrollRight = true;

  StoreController get _ctrl => Get.find<StoreController>();

  @override
  void initState() {
    super.initState();
    _scrollCtrl = ScrollController()..addListener(_updateScrollButtons);
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _updateScrollButtons() {
    if (!_scrollCtrl.hasClients) return;
    final pos = _scrollCtrl.position;
    final newLeft = pos.pixels > 0;
    final newRight = pos.pixels < pos.maxScrollExtent - 1;
    if (newLeft != _canScrollLeft || newRight != _canScrollRight) {
      setState(() {
        _canScrollLeft = newLeft;
        _canScrollRight = newRight;
      });
    }
  }

  void _scrollBy(double offset) {
    if (!_scrollCtrl.hasClients) return;
    _scrollCtrl.animateTo(
      (_scrollCtrl.offset + offset).clamp(
        _scrollCtrl.position.minScrollExtent,
        _scrollCtrl.position.maxScrollExtent,
      ),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final loading = _ctrl.trendingLoading.value;
      final agents = _ctrl.trendingAgents;

      // Update scroll arrows after data arrives
      if (!loading && agents.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _updateScrollButtons();
        });
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
            child: Row(children: [
              const Icon(Icons.local_fire_department_rounded,
                  color: AppTheme.primary, size: 18),
              const SizedBox(width: 6),
              const Text(
                'TRENDING',
                style: TextStyle(
                  color: AppTheme.textH,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  loading ? '...' : '${agents.length}',
                  style: const TextStyle(
                    color: AppTheme.primary,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Spacer(),
              // Scroll navigation arrows (web UX)
              if (!loading && agents.isNotEmpty) ...[
                _ScrollArrow(
                  icon: Icons.chevron_left_rounded,
                  enabled: _canScrollLeft,
                  onTap: () => _scrollBy(-200),
                ),
                const SizedBox(width: 4),
                _ScrollArrow(
                  icon: Icons.chevron_right_rounded,
                  enabled: _canScrollRight,
                  onTap: () => _scrollBy(200),
                ),
              ],
            ]),
          ),
          SizedBox(
            height: 190,
            child: loading
                ? _buildShimmer()
                : agents.isEmpty
                    ? _buildEmpty()
                    : _buildList(agents),
          ),
        ],
      );
    });
  }

  Widget _buildShimmer() {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 6,
      itemBuilder: (_, __) => Container(
        width: 140,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: const LinearGradient(
            colors: [AppTheme.card, AppTheme.card2],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: AppTheme.border),
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return const Center(
      child: Text(
        'No trending agents yet',
        style: TextStyle(color: AppTheme.textM, fontSize: 12),
      ),
    );
  }

  Widget _buildList(List<AgentModel> agents) {
    return ListView.builder(
      controller: _scrollCtrl,
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      itemCount: agents.length,
      itemBuilder: (_, i) =>
          _TrendingCard(agent: agents[i], rank: i + 1),
    );
  }
}

/// Small arrow button for horizontal scroll navigation
class _ScrollArrow extends StatefulWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  const _ScrollArrow({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  State<_ScrollArrow> createState() => _ScrollArrowState();
}

class _ScrollArrowState extends State<_ScrollArrow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.enabled ? widget.onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: widget.enabled && _hovered
                ? AppTheme.card2
                : AppTheme.card,
            shape: BoxShape.circle,
            border: Border.all(
              color: widget.enabled ? AppTheme.border2 : AppTheme.border,
            ),
          ),
          child: Icon(
            widget.icon,
            size: 16,
            color: widget.enabled ? AppTheme.textB : AppTheme.border,
          ),
        ),
      ),
    );
  }
}

class _TrendingCard extends StatefulWidget {
  final AgentModel agent;
  final int rank;
  const _TrendingCard({required this.agent, required this.rank});
  @override
  State<_TrendingCard> createState() => _TrendingCardState();
}

class _TrendingCardState extends State<_TrendingCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final rc = widget.agent.rarity.color;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () => context.go('/agent/${widget.agent.id}'),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: 140,
          margin: const EdgeInsets.only(right: 12),
          decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _hovered
                  ? rc.withValues(alpha: 0.7)
                  : rc.withValues(alpha: 0.3),
            ),
            boxShadow: _hovered
                ? [
                    BoxShadow(
                      color: rc.withValues(alpha: 0.25),
                      blurRadius: 14,
                      spreadRadius: 1,
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 6,
                    ),
                  ],
          ),
          child: Stack(
            children: [
              // Top gradient accent based on character type
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 40,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(11)),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        widget.agent.characterType.secondaryColor
                            .withValues(alpha: _hovered ? 0.5 : 0.3),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 12),
                  RepaintBoundary(
                    child: PixelCharacterWidget(
                      characterType: widget.agent.characterType,
                      rarity: widget.agent.rarity,
                      subclass: widget.agent.subclass,
                      size: 72,
                      agentId: widget.agent.id,
                      generatedImage: widget.agent.generatedImage,
                      imageUrl: widget.agent.imageUrl,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      widget.agent.title,
                      style: const TextStyle(
                        color: AppTheme.textH,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 3),
                  // Category chip
                  Text(
                    widget.agent.characterType.displayName,
                    style: TextStyle(
                      color: widget.agent.characterType.accentColor,
                      fontSize: 9,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Stats row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.local_fire_department_rounded,
                          size: 10, color: AppTheme.primary),
                      const SizedBox(width: 2),
                      const Icon(Icons.bookmarks_outlined,
                          size: 10, color: AppTheme.textM),
                      const SizedBox(width: 3),
                      Text(
                        '${widget.agent.saveCount}',
                        style: const TextStyle(
                            color: AppTheme.textM, fontSize: 10),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.play_circle_outline,
                          size: 10, color: AppTheme.textM),
                      const SizedBox(width: 3),
                      Text(
                        '${widget.agent.useCount}',
                        style: const TextStyle(
                            color: AppTheme.textM, fontSize: 10),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],
              ),
              // Rank badge (all ranks shown, top 3 get special colors)
              Positioned(
                top: 6,
                left: 6,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: _rankColor(widget.rank),
                    shape: BoxShape.circle,
                    boxShadow: widget.rank <= 3
                        ? [
                            BoxShadow(
                              color:
                                  _rankColor(widget.rank).withValues(alpha: 0.5),
                              blurRadius: 6,
                              spreadRadius: 1,
                            ),
                          ]
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      '#${widget.rank}',
                      style: TextStyle(
                        color: widget.rank <= 3
                            ? const Color(0xFF1E1A14)
                            : AppTheme.textH,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
              // Rarity dot
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: rc.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: rc.withValues(alpha: 0.5)),
                  ),
                  child: Text(
                    widget.agent.rarity.displayName,
                    style: TextStyle(
                      color: rc,
                      fontSize: 7,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Color _rankColor(int rank) {
    switch (rank) {
      case 1:
        return AppTheme.gold;
      case 2:
        return const Color(0xFF8A9A9A); // silver
      case 3:
        return const Color(0xFF8B6350); // bronze
      default:
        return AppTheme.card2;
    }
  }
}
