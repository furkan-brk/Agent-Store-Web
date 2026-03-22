// lib/features/store/widgets/filter_sidebar.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme.dart';
import '../../../controllers/store_controller.dart';
import '../../../shared/models/agent_model.dart';
import '../../../shared/widgets/pixel_character_widget.dart';
import '../../character/character_types.dart';
import 'filter_panel.dart';

/// Persistent right sidebar (260px) for desktop store layout.
/// Top section: embedded [FilterPanel]. Bottom section: trending agents list.
class StoreFilterSidebar extends StatelessWidget {
  const StoreFilterSidebar({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<StoreController>();

    return Container(
      width: 260,
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(
          left: BorderSide(color: AppTheme.border, width: 1),
        ),
      ),
      child: Column(
        children: [
          // -- Filter panel (scrollable top section) --
          Expanded(
            child: Obx(() => ListView(
              padding: const EdgeInsets.all(14),
              children: [
                // Sort dropdown
                _SidebarSortDropdown(ctrl: ctrl),
                const SizedBox(height: 14),
                // Filter panel
                FilterPanel(
                  minPrice: 0,
                  maxPrice: 10,
                  currentMin: ctrl.minPrice.value,
                  currentMax: ctrl.maxPrice.value,
                  selectedTags: ctrl.filterTags.toList(),
                  onPriceChanged: (r) {
                    ctrl.minPrice.value = r.start;
                    ctrl.maxPrice.value = r.end;
                    ctrl.load();
                  },
                  onTagToggled: (t) {
                    ctrl.toggleTag(t);
                    ctrl.load();
                  },
                  onReset: ctrl.resetFilters,
                ),
                const SizedBox(height: 20),
                // -- Trending section --
                const _TrendingSection(),
              ],
            )),
          ),
        ],
      ),
    );
  }
}

/// Sort dropdown styled for the sidebar context.
class _SidebarSortDropdown extends StatelessWidget {
  final StoreController ctrl;
  const _SidebarSortDropdown({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.sort_rounded, size: 14, color: AppTheme.gold),
            SizedBox(width: 6),
            Text(
              'Sort By',
              style: TextStyle(
                color: AppTheme.textH,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Obx(() => Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.border),
          ),
          child: DropdownButton<String>(
            value: ctrl.sort.value,
            dropdownColor: AppTheme.card2,
            underline: const SizedBox(),
            isExpanded: true,
            icon: const Icon(Icons.expand_more_rounded, color: AppTheme.textM, size: 18),
            style: const TextStyle(color: AppTheme.textH, fontSize: 12),
            items: const [
              DropdownMenuItem(value: 'newest', child: _SortItem(icon: Icons.schedule_rounded, label: 'Newest')),
              DropdownMenuItem(value: 'popular', child: _SortItem(icon: Icons.trending_up_rounded, label: 'Popular')),
              DropdownMenuItem(value: 'saves', child: _SortItem(icon: Icons.bookmark_rounded, label: 'Most Saved')),
              DropdownMenuItem(value: 'price_asc', child: _SortItem(icon: Icons.arrow_upward_rounded, label: 'Price Low')),
              DropdownMenuItem(value: 'price_desc', child: _SortItem(icon: Icons.arrow_downward_rounded, label: 'Price High')),
              DropdownMenuItem(value: 'oldest', child: _SortItem(icon: Icons.history_rounded, label: 'Oldest')),
            ],
            onChanged: (v) {
              if (v != null) {
                ctrl.sort.value = v;
                ctrl.load();
              }
            },
          ),
        )),
      ],
    );
  }
}

class _SortItem extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SortItem({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 14, color: AppTheme.textM),
      const SizedBox(width: 6),
      Text(label),
    ],
  );
}

/// Trending agents vertical list for sidebar (top 5).
class _TrendingSection extends StatelessWidget {
  const _TrendingSection();

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<StoreController>();

    return Obx(() {
      final loading = ctrl.trendingLoading.value;
      final agents = ctrl.trendingAgents;
      final displayAgents = agents.take(5).toList();

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Row(
            children: [
              const Icon(Icons.local_fire_department_rounded,
                  color: AppTheme.primary, size: 16),
              const SizedBox(width: 6),
              const Text(
                'TRENDING',
                style: TextStyle(
                  color: AppTheme.textM,
                  fontSize: 10,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              if (!loading)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${displayAgents.length}',
                    style: const TextStyle(
                      color: AppTheme.primary,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          // Content
          if (loading)
            ..._buildShimmer()
          else if (displayAgents.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  'No trending agents yet',
                  style: TextStyle(color: AppTheme.textM, fontSize: 11),
                ),
              ),
            )
          else
            ...displayAgents.asMap().entries.map((entry) {
              final rank = entry.key + 1;
              final agent = entry.value;
              return _TrendingItem(agent: agent, rank: rank);
            }),
        ],
      );
    });
  }

  List<Widget> _buildShimmer() {
    return List.generate(
      5,
      (i) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.border),
          ),
        ),
      ),
    );
  }
}

/// Single trending agent row: rank + avatar + title + save count.
class _TrendingItem extends StatefulWidget {
  final AgentModel agent;
  final int rank;

  const _TrendingItem({required this.agent, required this.rank});

  @override
  State<_TrendingItem> createState() => _TrendingItemState();
}

class _TrendingItemState extends State<_TrendingItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final agent = widget.agent;
    final rc = agent.rarity.color;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () => context.go('/agent/${agent.id}'),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: _hovered ? AppTheme.card2 : AppTheme.card,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _hovered
                    ? rc.withValues(alpha: 0.5)
                    : AppTheme.border,
              ),
              boxShadow: _hovered
                  ? [BoxShadow(color: rc.withValues(alpha: 0.15), blurRadius: 8)]
                  : null,
            ),
            child: Row(
              children: [
                // Rank number
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: _rankColor(widget.rank),
                    shape: BoxShape.circle,
                    boxShadow: widget.rank <= 3
                        ? [
                            BoxShadow(
                              color: _rankColor(widget.rank).withValues(alpha: 0.4),
                              blurRadius: 4,
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
                const SizedBox(width: 8),
                // Small character avatar
                RepaintBoundary(
                  child: SizedBox(
                    width: 32,
                    height: 32,
                    child: PixelCharacterWidget(
                      characterType: agent.characterType,
                      rarity: agent.rarity,
                      subclass: agent.subclass,
                      size: 32,
                      agentId: agent.id,
                      generatedImage: agent.generatedImage,
                      imageUrl: agent.imageUrl,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Title + save count
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        agent.title,
                        style: TextStyle(
                          color: _hovered ? AppTheme.textH : AppTheme.textB,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.bookmarks_outlined,
                              size: 9, color: AppTheme.textM),
                          const SizedBox(width: 3),
                          Text(
                            '${agent.saveCount}',
                            style: const TextStyle(
                                color: AppTheme.textM, fontSize: 9),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.play_circle_outline,
                              size: 9, color: AppTheme.textM),
                          const SizedBox(width: 3),
                          Text(
                            '${agent.useCount}',
                            style: const TextStyle(
                                color: AppTheme.textM, fontSize: 9),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
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
