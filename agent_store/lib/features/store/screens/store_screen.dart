// lib/features/store/screens/store_screen.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme.dart';
import '../../../controllers/store_controller.dart';
import '../../../shared/models/agent_model.dart';
import '../../../shared/services/api_service.dart';
import '../../../shared/widgets/wallet_guard.dart';
import '../widgets/agent_card.dart';
import '../widgets/category_chips.dart';
import '../widgets/filter_panel.dart';
import '../widgets/trending_row.dart';
import '../../../shared/widgets/onboarding_modal.dart';
import '../../../shared/widgets/skeleton_widgets.dart';
import '../../character/character_types.dart';

class StoreScreen extends StatefulWidget {
  const StoreScreen({super.key});
  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

/// NOTE: StoreScreen keeps a thin StatefulWidget shell ONLY for:
///  - TextEditingController lifecycle
///  - debounce timer
///  - keyboard / focus management
/// All *data state* is in StoreController (GetX).
class _StoreScreenState extends State<StoreScreen> {
  late final StoreController _ctrl;
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _ctrl = Get.isRegistered<StoreController>()
        ? Get.find<StoreController>()
        : Get.put(StoreController(), permanent: true);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (await OnboardingModal.shouldShow() && mounted) {
        showDialog(context: context, barrierDismissible: false, builder: (_) => const OnboardingModal());
      }
    });
  }

  void _onSearchChanged(String val) {
    setState(() {}); // updates clear button visibility only
    _ctrl.onSearchChanged(val);
  }

  void _clearSearch() {
    _searchCtrl.clear();
    _ctrl.clearSearch();
    setState(() {});
  }

  Future<void> _onSaveAgent(AgentModel agent) async {
    if (!WalletGuard.checkWithSnackBar(context, actionLabel: 'save agents')) return;
    final ok = await ApiService.instance.addToLibrary(agent.id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: [
          Icon(
            ok ? Icons.bookmark_added_rounded : Icons.bookmark_outlined,
            color: ok ? AppTheme.olive : AppTheme.gold,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(ok ? 'Saved to library' : 'Already in library')),
        ]),
        duration: const Duration(seconds: 2),
      ));
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: ShimmerScope(
        child: Stack(
          children: [
            RefreshIndicator(
              onRefresh: _ctrl.load,
              color: AppTheme.primary,
              child: CustomScrollView(cacheExtent: 1200, slivers: [
                // Header is purely driven by TextEditingController + inner Obx calls.
                SliverToBoxAdapter(child: _buildHeader()),
                // Inline category chips — replaces the old sidebar
                SliverToBoxAdapter(child: _buildCategoryChips()),
                // TrendingRow: only hide/show when search changes.
                Obx(() => _ctrl.search.value.isEmpty
                  ? const SliverToBoxAdapter(child: TrendingRow())
                  : const SliverToBoxAdapter(child: SizedBox.shrink())),
                // Discovery: only visible with empty search + no category + not loading.
                Obx(() => (_ctrl.search.value.isEmpty && _ctrl.category.value.isEmpty && !_ctrl.isLoading.value)
                  ? SliverToBoxAdapter(child: _buildDiscovery())
                  : const SliverToBoxAdapter(child: SizedBox.shrink())),
                // Section heading with divider
                SliverToBoxAdapter(child: _buildSectionHeader()),
                // Main content sliver: rebuilds ONLY when isLoading/agents/hasError change.
                Obx(() => _buildContentSliver()),
                // End-of-list spacer
                Obx(() => (_ctrl.agents.isNotEmpty && !_ctrl.isLoading.value)
                  ? SliverToBoxAdapter(child: _buildEndOfList())
                  : const SliverToBoxAdapter(child: SizedBox.shrink())),
              ]),
            ),
            // Subtle loading indicator overlay when refreshing with stale data
            Obx(() => (_ctrl.isLoading.value && _ctrl.agents.isNotEmpty)
              ? Positioned(
                  top: 0, left: 0, right: 0,
                  child: LinearProgressIndicator(
                    backgroundColor: Colors.transparent,
                    valueColor: AlwaysStoppedAnimation(AppTheme.primary.withValues(alpha: 0.7)),
                    minHeight: 2,
                  ),
                )
              : const SizedBox.shrink()),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryChips() {
    final isMobile = MediaQuery.of(context).size.width < 768;
    final hPad = isMobile ? 16.0 : 24.0;
    return Obx(() => Padding(
      padding: EdgeInsets.fromLTRB(hPad, 8, hPad, 8),
      child: CategoryChips(
        categories: _ctrl.categories,
        selectedCategory: _ctrl.category.value,
        onSelect: (cat) {
          _searchCtrl.clear();
          _ctrl.search.value = '';
          _ctrl.category.value = cat;
          _ctrl.load();
        },
      ),
    ));
  }

  // Responsive grid delegate based on available width.
  SliverGridDelegate _responsiveGridDelegate(double width) {
    if (width < 400) {
      // Small phones: 2 columns, tight spacing
      return const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.68,
      );
    } else if (width < 768) {
      // Large phones / small tablets: 2-3 columns
      return const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 220,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.70,
      );
    }
    // Tablet / Desktop: default behavior
    return const SliverGridDelegateWithMaxCrossAxisExtent(
      maxCrossAxisExtent: 300,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 0.72,
    );
  }

  // Returns a sliver based on current controller state.
  Widget _buildContentSliver() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;
    final gridPadding = isMobile
        ? const EdgeInsets.fromLTRB(12, 0, 12, 12)
        : const EdgeInsets.fromLTRB(24, 0, 24, 24);

    // Skeleton: loading AND no stale data to show
    if (_ctrl.isLoading.value && _ctrl.agents.isEmpty) {
      return SliverPadding(
        padding: gridPadding,
        sliver: SliverGrid(
          gridDelegate: _responsiveGridDelegate(screenWidth),
          delegate: SliverChildBuilderDelegate(
            (_, __) => const AgentCardSkeleton(),
            childCount: 12,
          ),
        ),
      );
    }
    if (_ctrl.hasError.value) return SliverFillRemaining(child: _buildErrorView());
    if (_ctrl.agents.isEmpty) return SliverFillRemaining(child: _buildEmpty());
    return SliverPadding(
      padding: gridPadding,
      sliver: SliverGrid(
        gridDelegate: _responsiveGridDelegate(screenWidth),
        delegate: SliverChildBuilderDelegate(
          (_, i) => RepaintBoundary(
            key: ValueKey(_ctrl.agents[i].id),
            child: _AgentCardWithSave(agent: _ctrl.agents[i], onSave: () => _onSaveAgent(_ctrl.agents[i])),
          ),
          childCount: _ctrl.agents.length,
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;
    final hPad = isMobile ? 16.0 : 24.0;
    final titleSize = isMobile ? 20.0 : 24.0;

    return Padding(
    padding: EdgeInsets.fromLTRB(hPad, isMobile ? 20 : 28, hPad, 0),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Title row with accent decoration
      Row(children: [
        Container(
          width: 4, height: isMobile ? 22 : 28,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [AppTheme.primary, AppTheme.gold],
            ),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            'Discover Agents',
            style: TextStyle(
              color: AppTheme.textH,
              fontSize: titleSize,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
        ),
      ]),
      const SizedBox(height: 8),
      Obx(() => Padding(
        padding: EdgeInsets.only(left: isMobile ? 12 : 16),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.auto_awesome, size: 14, color: AppTheme.gold),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              '${_ctrl.total.value} agents available',
              style: TextStyle(color: AppTheme.textM, fontSize: isMobile ? 12 : 13, letterSpacing: 0.2),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ]),
      )),
      const SizedBox(height: 20),
      // Search + Sort + Filter row
      LayoutBuilder(builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 500;
        if (isCompact) {
          return Column(children: [
            _buildSearchField(),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: _buildSortDropdown()),
              const SizedBox(width: 8),
              _buildFilterButton(),
            ]),
          ]);
        }
        return Row(children: [
          Expanded(child: _buildSearchField()),
          const SizedBox(width: 12),
          _buildSortDropdown(),
          const SizedBox(width: 8),
          _buildFilterButton(),
        ]);
      }),
      // Filter panel
      Obx(() => AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        transitionBuilder: (child, a) => SizeTransition(sizeFactor: a, child: FadeTransition(opacity: a, child: child)),
        child: _ctrl.showFilter.value
          ? Padding(key: const ValueKey('fp'), padding: const EdgeInsets.only(top: 14), child: FilterPanel(
              minPrice: 0, maxPrice: 10,
              currentMin: _ctrl.minPrice.value, currentMax: _ctrl.maxPrice.value,
              selectedTags: _ctrl.filterTags.toList(),
              onPriceChanged: (r) { _ctrl.minPrice.value = r.start; _ctrl.maxPrice.value = r.end; _ctrl.load(); },
              onTagToggled: (t) { _ctrl.toggleTag(t); _ctrl.load(); },
              onReset: _ctrl.resetFilters,
            ))
          : const SizedBox.shrink(key: ValueKey('fh')),
      )),
      // Recent searches
      Obx(() => _ctrl.recentSearches.isNotEmpty && _ctrl.search.value.isEmpty ? Padding(
        padding: const EdgeInsets.only(top: 14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.card.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.border.withValues(alpha: 0.5)),
          ),
          child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
            const Icon(Icons.history_rounded, size: 13, color: AppTheme.textM),
            const SizedBox(width: 8),
            const Text('Recent:', style: TextStyle(color: AppTheme.textM, fontSize: 11, fontWeight: FontWeight.w500)),
            const SizedBox(width: 10),
            ..._ctrl.recentSearches.map((s) => Padding(padding: const EdgeInsets.only(right: 6), child: ActionChip(
              label: Text(s, style: const TextStyle(fontSize: 10, color: AppTheme.textB)),
              onPressed: () { _searchCtrl.text = s; _ctrl.submitSearch(s); },
              backgroundColor: AppTheme.card2, side: const BorderSide(color: AppTheme.border),
              padding: const EdgeInsets.symmetric(horizontal: 6), visualDensity: VisualDensity.compact,
            ))),
            TextButton.icon(
              onPressed: _ctrl.clearRecentSearches,
              style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 6), minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
              icon: const Icon(Icons.close_rounded, size: 11, color: AppTheme.textM),
              label: const Text('Clear', style: TextStyle(fontSize: 10, color: AppTheme.textM)),
            ),
          ])),
        ),
      ) : const SizedBox.shrink()),
      const SizedBox(height: 4),
    ]),
  );
  }

  Widget _buildSearchField() => TextField(
    controller: _searchCtrl,
    focusNode: _searchFocus,
    onSubmitted: (v) { _ctrl.submitSearch(v); },
    onChanged: _onSearchChanged,
    style: const TextStyle(color: AppTheme.textH, fontSize: 14),
    decoration: InputDecoration(
      hintText: 'Search by name, category, or tag...',
      hintStyle: const TextStyle(color: AppTheme.textM, fontSize: 13),
      prefixIcon: const Padding(
        padding: EdgeInsets.only(left: 12, right: 8),
        child: Icon(Icons.search_rounded, color: AppTheme.textM, size: 20),
      ),
      prefixIconConstraints: const BoxConstraints(minWidth: 40),
      suffixIcon: _searchCtrl.text.isNotEmpty
        ? IconButton(
            icon: const Icon(Icons.clear_rounded, color: AppTheme.textM, size: 18),
            onPressed: _clearSearch,
            tooltip: 'Clear search',
          )
        : null,
      fillColor: AppTheme.card, filled: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppTheme.border),
      ),
    ),
  );

  Widget _buildSortDropdown() => Obx(() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    decoration: BoxDecoration(
      color: AppTheme.card,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppTheme.border),
    ),
    child: DropdownButton<String>(
      value: _ctrl.sort.value,
      dropdownColor: AppTheme.card2, underline: const SizedBox(),
      icon: const Padding(
        padding: EdgeInsets.only(left: 6),
        child: Icon(Icons.sort_rounded, color: AppTheme.textM, size: 16),
      ),
      style: const TextStyle(color: AppTheme.textH, fontSize: 12),
      items: const [
        DropdownMenuItem(value: 'newest', child: _SortMenuItem(icon: Icons.schedule_rounded, label: 'Newest')),
        DropdownMenuItem(value: 'popular', child: _SortMenuItem(icon: Icons.trending_up_rounded, label: 'Popular')),
        DropdownMenuItem(value: 'saves', child: _SortMenuItem(icon: Icons.bookmark_rounded, label: 'Most Saved')),
        DropdownMenuItem(value: 'price_asc', child: _SortMenuItem(icon: Icons.arrow_upward_rounded, label: 'Price Low')),
        DropdownMenuItem(value: 'price_desc', child: _SortMenuItem(icon: Icons.arrow_downward_rounded, label: 'Price High')),
        DropdownMenuItem(value: 'oldest', child: _SortMenuItem(icon: Icons.history_rounded, label: 'Oldest')),
      ],
      onChanged: (v) { if (v != null) { _ctrl.sort.value = v; _ctrl.load(); } },
    ),
  ));

  Widget _buildFilterButton() => Obx(() => Stack(clipBehavior: Clip.none, children: [
    _HoverContainer(
      isActive: _ctrl.showFilter.value,
      onTap: () => _ctrl.showFilter.toggle(),
      tooltip: 'Filter options',
      child: Icon(
        Icons.tune_rounded,
        color: _ctrl.showFilter.value ? AppTheme.primary : AppTheme.textM,
        size: 18,
      ),
    ),
    if (_ctrl.activeFilterCount > 0)
      Positioned(top: -4, right: -4, child: Container(
        width: 18, height: 18,
        decoration: BoxDecoration(
          color: AppTheme.gold,
          shape: BoxShape.circle,
          border: Border.all(color: AppTheme.bg, width: 1.5),
          boxShadow: [BoxShadow(color: AppTheme.gold.withValues(alpha: 0.4), blurRadius: 6)],
        ),
        child: Center(child: Text(
          '${_ctrl.activeFilterCount}',
          style: const TextStyle(color: Color(0xFF1E1A14), fontSize: 9, fontWeight: FontWeight.bold),
        )),
      )),
  ]));

  Widget _buildSectionHeader() {
    final isMobile = MediaQuery.of(context).size.width < 768;
    final hPad = isMobile ? 16.0 : 24.0;
    return Padding(
    padding: EdgeInsets.fromLTRB(hPad, isMobile ? 16 : 24, hPad, 4),
    child: Column(children: [
      Obx(() {
        final IconData icon;
        final String text;
        final String? subtitle;
        if (_ctrl.search.value.isNotEmpty) {
          icon = Icons.search_rounded;
          text = 'Results for "${_ctrl.search.value}"';
          subtitle = '${_ctrl.agents.length} agent${_ctrl.agents.length != 1 ? 's' : ''} found';
        } else if (_ctrl.category.value.isNotEmpty) {
          icon = _getCategoryIcon(_ctrl.category.value);
          text = '${_ctrl.category.value[0].toUpperCase()}${_ctrl.category.value.substring(1)} Agents';
          subtitle = '${_ctrl.agents.length} in this category';
        } else {
          icon = Icons.grid_view_rounded;
          text = 'All Agents';
          subtitle = null;
        }
        return Row(children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppTheme.gold.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: AppTheme.gold),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(text, style: const TextStyle(
                color: AppTheme.textH, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.3)),
              if (subtitle != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(subtitle, style: const TextStyle(color: AppTheme.textM, fontSize: 11)),
                ),
            ],
          )),
        ]);
      }),
      const Padding(
        padding: EdgeInsets.only(top: 12),
        child: Divider(color: AppTheme.border, height: 1, thickness: 1),
      ),
      const SizedBox(height: 16),
    ]),
  );
  }

  IconData _getCategoryIcon(String category) => switch (category.toLowerCase()) {
    'backend'  => Icons.code_rounded,
    'frontend' => Icons.brush_rounded,
    'data'     => Icons.bar_chart_rounded,
    'security' => Icons.shield_rounded,
    'creative' => Icons.auto_awesome_rounded,
    'business' => Icons.trending_up_rounded,
    'research' => Icons.science_rounded,
    'planning' => Icons.map_rounded,
    _          => Icons.folder_open_rounded,
  };

  Widget _buildErrorView() => Center(child: Padding(
    padding: const EdgeInsets.all(32),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(
        width: 80, height: 80,
        decoration: BoxDecoration(
          color: AppTheme.primary.withValues(alpha: 0.1),
          shape: BoxShape.circle,
          border: Border.all(color: AppTheme.primary.withValues(alpha: 0.25)),
        ),
        child: const Icon(Icons.cloud_off_rounded, color: AppTheme.primary, size: 36),
      ),
      const SizedBox(height: 20),
      const Text(
        'Could not load agents',
        style: TextStyle(color: AppTheme.textH, fontSize: 18, fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 8),
      const Text(
        'Please check your internet connection and try again.',
        style: TextStyle(color: AppTheme.textM, fontSize: 13, height: 1.5),
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 24),
      ElevatedButton.icon(
        onPressed: _ctrl.load,
        icon: const Icon(Icons.refresh_rounded, size: 18),
        label: const Text('Try Again'),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    ]),
  ));

  Widget _buildEmpty() {
    if (_ctrl.search.value.isNotEmpty) {
      return Center(child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              color: AppTheme.gold.withValues(alpha: 0.08),
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.gold.withValues(alpha: 0.2)),
            ),
            child: const Icon(Icons.search_off_rounded, color: AppTheme.gold, size: 32),
          ),
          const SizedBox(height: 20),
          const Text(
            'No agents found',
            style: TextStyle(color: AppTheme.textH, fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'No results for "${_ctrl.search.value}". Try a different term or browse categories.',
            style: const TextStyle(color: AppTheme.textM, fontSize: 13, height: 1.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Row(mainAxisSize: MainAxisSize.min, children: [
            OutlinedButton.icon(
              onPressed: _clearSearch,
              icon: const Icon(Icons.clear_rounded, size: 16),
              label: const Text('Clear search'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: () => context.go('/create'),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Create Agent'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ]),
        ]),
      ));
    }
    return Center(child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          width: 80, height: 80,
          decoration: BoxDecoration(
            color: AppTheme.gold.withValues(alpha: 0.08),
            shape: BoxShape.circle,
            border: Border.all(color: AppTheme.gold.withValues(alpha: 0.2)),
          ),
          child: const Icon(Icons.inventory_2_outlined, color: AppTheme.gold, size: 36),
        ),
        const SizedBox(height: 20),
        const Text(
          'No agents yet',
          style: TextStyle(color: AppTheme.textH, fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Text(
          _ctrl.category.value.isNotEmpty
            ? 'No agents in this category yet. Be the first to create one!'
            : 'The store is empty. Create your first AI agent to get started.',
          style: const TextStyle(color: AppTheme.textM, fontSize: 13, height: 1.5),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        Row(mainAxisSize: MainAxisSize.min, children: [
          if (_ctrl.category.value.isNotEmpty) ...[
            OutlinedButton.icon(
              onPressed: () { _ctrl.category.value = ''; _ctrl.load(); },
              icon: const Icon(Icons.clear_all_rounded, size: 16),
              label: const Text('Clear filters'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(width: 12),
          ],
          ElevatedButton.icon(
            onPressed: () => context.go('/create'),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Create Agent'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ]),
      ]),
    ));
  }

  /// End-of-list indicator for long scrollable grids
  Widget _buildEndOfList() {
    final isMobile = MediaQuery.of(context).size.width < 768;
    final hPad = isMobile ? 12.0 : 24.0;
    return Padding(
    padding: EdgeInsets.fromLTRB(hPad, 8, hPad, 32),
    child: Obx(() => Column(children: [
      const Divider(color: AppTheme.border, height: 1, thickness: 1),
      const SizedBox(height: 16),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.check_circle_outline_rounded, size: 14, color: AppTheme.textM),
        const SizedBox(width: 8),
        Text(
          'Showing all ${_ctrl.agents.length} agent${_ctrl.agents.length != 1 ? 's' : ''}',
          style: const TextStyle(color: AppTheme.textM, fontSize: 12),
        ),
      ]),
    ])),
  );
  }

  static const _kDiscoveryCategories = <(CharacterType, String, IconData)>[
    (CharacterType.wizard,     'backend',   Icons.code_rounded),
    (CharacterType.strategist, 'planning',  Icons.map_rounded),
    (CharacterType.oracle,     'data',      Icons.bar_chart_rounded),
    (CharacterType.guardian,   'security',  Icons.shield_rounded),
    (CharacterType.artisan,    'frontend',  Icons.brush_rounded),
    (CharacterType.bard,       'creative',  Icons.auto_stories_rounded),
    (CharacterType.scholar,    'research',  Icons.school_rounded),
    (CharacterType.merchant,   'marketing', Icons.trending_up_rounded),
  ];

  static const _kPopularTags = ['AI', 'coding', 'writing', 'analysis', 'planning', 'security', 'research', 'marketing', 'automation', 'data'];

  Widget _buildDiscovery() {
    final isMobile = MediaQuery.of(context).size.width < 768;
    final hPad = isMobile ? 16.0 : 24.0;
    return Padding(
    padding: EdgeInsets.fromLTRB(hPad, 4, hPad, 0),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // "Browse by Category" header
      Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppTheme.gold.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Icon(Icons.category_rounded, size: 14, color: AppTheme.gold),
        ),
        const SizedBox(width: 8),
        const Text('Browse by Category', style: TextStyle(color: AppTheme.textH, fontSize: 14, fontWeight: FontWeight.w600)),
      ]),
      const SizedBox(height: 12),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _kDiscoveryCategories.map((entry) {
            final (type, key, icon) = entry;
            final color = type.primaryColor;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _HoverChip(
                icon: icon,
                label: type.displayName,
                color: color,
                onPressed: () { _ctrl.category.value = key; _ctrl.load(); },
              ),
            );
          }).toList(),
        ),
      ),
      const SizedBox(height: 16),
      // "Popular Tags" header
      Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppTheme.gold.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Icon(Icons.local_offer_rounded, size: 14, color: AppTheme.gold),
        ),
        const SizedBox(width: 8),
        const Text('Popular Tags', style: TextStyle(color: AppTheme.textH, fontSize: 14, fontWeight: FontWeight.w600)),
      ]),
      const SizedBox(height: 10),
      Wrap(spacing: 8, runSpacing: 8, children: _kPopularTags.map((tag) => _HoverTagChip(
        tag: tag,
        onPressed: () { _searchCtrl.text = tag; _ctrl.submitSearch(tag); },
      )).toList()),
      const SizedBox(height: 12),
    ]),
  );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Sort menu item with icon
// ══════════════════════════════════════════════════════════════════════════════

class _SortMenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SortMenuItem({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    Icon(icon, size: 14, color: AppTheme.textM),
    const SizedBox(width: 6),
    Text(label),
  ]);
}

// ══════════════════════════════════════════════════════════════════════════════
// Hover-aware container for icon buttons (filter, etc.)
// ══════════════════════════════════════════════════════════════════════════════

class _HoverContainer extends StatefulWidget {
  final bool isActive;
  final VoidCallback onTap;
  final String tooltip;
  final Widget child;
  const _HoverContainer({required this.isActive, required this.onTap, required this.tooltip, required this.child});

  @override
  State<_HoverContainer> createState() => _HoverContainerState();
}

class _HoverContainerState extends State<_HoverContainer> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: widget.isActive
                ? AppTheme.primary.withValues(alpha: 0.15)
                : _hovered
                  ? AppTheme.card2
                  : AppTheme.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: widget.isActive
                  ? AppTheme.primary
                  : _hovered
                    ? AppTheme.border2
                    : AppTheme.border,
              ),
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Hover-aware category chip for discovery section
// ══════════════════════════════════════════════════════════════════════════════

class _HoverChip extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onPressed;
  const _HoverChip({required this.icon, required this.label, required this.color, required this.onPressed});

  @override
  State<_HoverChip> createState() => _HoverChipState();
}

class _HoverChipState extends State<_HoverChip> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: _hovered
              ? widget.color.withValues(alpha: 0.2)
              : widget.color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _hovered
                ? widget.color.withValues(alpha: 0.6)
                : widget.color.withValues(alpha: 0.3),
            ),
            boxShadow: _hovered
              ? [BoxShadow(color: widget.color.withValues(alpha: 0.15), blurRadius: 8, spreadRadius: 1)]
              : [],
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(widget.icon, size: 16, color: widget.color),
            const SizedBox(width: 6),
            Text(widget.label, style: TextStyle(
              color: widget.color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            )),
          ]),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Hover-aware tag chip for popular tags
// ══════════════════════════════════════════════════════════════════════════════

class _HoverTagChip extends StatefulWidget {
  final String tag;
  final VoidCallback onPressed;
  const _HoverTagChip({required this.tag, required this.onPressed});

  @override
  State<_HoverTagChip> createState() => _HoverTagChipState();
}

class _HoverTagChipState extends State<_HoverTagChip> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _hovered ? AppTheme.card2 : AppTheme.card,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _hovered ? AppTheme.gold.withValues(alpha: 0.4) : AppTheme.border2,
            ),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.tag_rounded, size: 12, color: _hovered ? AppTheme.gold : AppTheme.textM),
            const SizedBox(width: 4),
            Text(widget.tag, style: TextStyle(
              color: _hovered ? AppTheme.textH : AppTheme.textB,
              fontSize: 11,
              fontWeight: _hovered ? FontWeight.w600 : FontWeight.normal,
            )),
          ]),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Agent card wrapper with hover-aware bookmark/save button
// ══════════════════════════════════════════════════════════════════════════════

class _AgentCardWithSave extends StatefulWidget {
  final AgentModel agent;
  final VoidCallback onSave;
  const _AgentCardWithSave({required this.agent, required this.onSave});

  @override
  State<_AgentCardWithSave> createState() => _AgentCardWithSaveState();
}

class _AgentCardWithSaveState extends State<_AgentCardWithSave> {
  bool _saveHovered = false;

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;
    // Larger tap target on mobile for touch-friendliness
    final btnSize = isMobile ? 36.0 : 30.0;
    final iconSize = isMobile ? 18.0 : 15.0;

    return Stack(clipBehavior: Clip.none, children: [
      AgentCard(agent: widget.agent),
      Positioned(
        top: 8, right: 8,
        child: MouseRegion(
          onEnter: (_) => setState(() => _saveHovered = true),
          onExit: (_) => setState(() => _saveHovered = false),
          cursor: SystemMouseCursors.click,
          child: Tooltip(
            message: 'Save to library',
            child: GestureDetector(
              onTap: widget.onSave,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: btnSize, height: btnSize,
                decoration: BoxDecoration(
                  color: _saveHovered
                    ? AppTheme.gold.withValues(alpha: 0.2)
                    : AppTheme.surface.withValues(alpha: 0.9),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _saveHovered ? AppTheme.gold : AppTheme.border2,
                    width: _saveHovered ? 1.5 : 1,
                  ),
                  boxShadow: _saveHovered
                    ? [BoxShadow(color: AppTheme.gold.withValues(alpha: 0.3), blurRadius: 8)]
                    : [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 4)],
                ),
                child: Icon(
                  _saveHovered ? Icons.bookmark_add_rounded : Icons.bookmark_add_outlined,
                  size: iconSize,
                  color: _saveHovered ? AppTheme.gold : AppTheme.textM,
                ),
              ),
            ),
          ),
        ),
      ),
    ]);
  }
}
