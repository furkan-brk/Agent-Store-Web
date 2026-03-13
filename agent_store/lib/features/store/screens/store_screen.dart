// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:html' as html;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme.dart';
import '../../../controllers/store_controller.dart';
import '../../../shared/models/agent_model.dart';
import '../../../shared/services/api_service.dart';
import '../../../shared/services/wallet_service.dart';
import '../widgets/agent_card.dart';
import '../widgets/category_sidebar.dart';
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
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _ctrl = Get.put(StoreController());
    _loadRecentSearches();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (OnboardingModal.shouldShow() && mounted) {
        showDialog(context: context, barrierDismissible: false, builder: (_) => const OnboardingModal());
      }
    });
  }

  void _loadRecentSearches() {
    try {
      final raw = html.window.localStorage['recent_searches'] ?? '[]';
      _ctrl.recentSearches.value = (jsonDecode(raw) as List).cast<String>().take(8).toList();
    } catch (_) {}
  }

  void _saveRecentSearch(String term) {
    if (term.trim().isEmpty) return;
    try {
      final list = _ctrl.recentSearches.toList();
      list.remove(term); list.insert(0, term);
      if (list.length > 8) list.removeRange(8, list.length);
      _ctrl.recentSearches.value = list;
      html.window.localStorage['recent_searches'] = jsonEncode(list);
    } catch (_) {}
  }

  void _onSearchChanged(String val) {
    setState(() {}); // updates clear button visibility only
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _ctrl.search.value = val;
      _saveRecentSearch(val);
      _ctrl.load();
    });
  }

  void _clearSearch() {
    _debounce?.cancel();
    _searchCtrl.clear();
    _ctrl.search.value = '';
    _ctrl.load();
    setState(() {});
  }

  Future<void> _onSaveAgent(AgentModel agent) async {
    if (!ApiService.instance.isAuthenticated || !WalletService.instance.isConnected) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Connect your wallet to save agents'),
        action: SnackBarAction(label: 'Connect', onPressed: () => context.go('/wallet')),
      ));
      return;
    }
    final ok = await ApiService.instance.addToLibrary(agent.id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok ? 'Saved to library' : 'Already in library'),
        duration: const Duration(seconds: 2),
      ));
    }
  }

  @override
  void dispose() { _debounce?.cancel(); _searchCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppTheme.bg,
    body: Row(children: [
      Obx(() => CategorySidebar(
        selectedCategory: _ctrl.category.value,
        onSelect: (cat) {
          _searchCtrl.clear();
          _ctrl.search.value = '';
          _ctrl.category.value = cat;
          _ctrl.load();
        },
      )),
      // ShimmerScope provides a shared AnimationController for all AgentCardSkeleton children.
    Expanded(child: ShimmerScope(
      child: RefreshIndicator(
        onRefresh: _ctrl.load,
        color: AppTheme.primary,
        child: CustomScrollView(cacheExtent: 1200, slivers: [
          // Header is purely driven by TextEditingController + inner Obx calls → no outer Obx needed.
          SliverToBoxAdapter(child: _buildHeader()),
          // TrendingRow: only hide/show when search changes.
          Obx(() => _ctrl.search.value.isEmpty
            ? const SliverToBoxAdapter(child: TrendingRow())
            : const SliverToBoxAdapter(child: SizedBox.shrink())),
          // Discovery: only visible with empty search + no category + not loading.
          Obx(() => (_ctrl.search.value.isEmpty && _ctrl.category.value.isEmpty && !_ctrl.isLoading.value)
            ? SliverToBoxAdapter(child: _buildDiscovery())
            : const SliverToBoxAdapter(child: SizedBox.shrink())),
          // Section heading has its own inner Obx → no outer wrapper needed.
          SliverToBoxAdapter(child: _buildSectionHeader()),
          // Main content sliver: rebuilds ONLY when isLoading/agents/hasError change.
          Obx(() => _buildContentSliver()),
        ]),
      ),
    )),
    ]),
  );

  // Returns a sliver based on current controller state.
  Widget _buildContentSliver() {
    // Skeleton: loading AND no stale data to show
    if (_ctrl.isLoading.value && _ctrl.agents.isEmpty) {
      return SliverPadding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        sliver: SliverGrid(
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 300, crossAxisSpacing: 16, mainAxisSpacing: 16, childAspectRatio: 0.72),
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
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 300, crossAxisSpacing: 16, mainAxisSpacing: 16, childAspectRatio: 0.72),
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

  Widget _buildHeader() => Padding(
    padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      ShaderMask(
        shaderCallback: (b) => const LinearGradient(colors: [AppTheme.primary, AppTheme.gold], begin: Alignment.centerLeft, end: Alignment.centerRight).createShader(b),
        child: const Text('Agent Store', style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
      ),
      const SizedBox(height: 4),
      Obx(() => Text('${_ctrl.total.value} agents available', style: const TextStyle(color: AppTheme.textM, fontSize: 13))),
      const SizedBox(height: 16),
      Row(children: [
        Expanded(child: TextField(
          controller: _searchCtrl,
          onSubmitted: (v) { _debounce?.cancel(); _ctrl.search.value = v; _saveRecentSearch(v); _ctrl.load(); },
          onChanged: _onSearchChanged,
          style: const TextStyle(color: AppTheme.textH),
          decoration: InputDecoration(
            hintText: 'Search agents...', prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.textM),
            suffixIcon: _searchCtrl.text.isNotEmpty ? IconButton(icon: const Icon(Icons.clear_rounded, color: AppTheme.textM), onPressed: _clearSearch) : null,
            fillColor: AppTheme.card, filled: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.primary, width: 1.5)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.border)),
          ),
        )),
        const SizedBox(width: 12),
        Obx(() => Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: AppTheme.card, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppTheme.border)),
          child: DropdownButton<String>(
            value: _ctrl.sort.value,
            dropdownColor: AppTheme.card2, underline: const SizedBox(),
            icon: const Icon(Icons.sort_rounded, color: AppTheme.textM, size: 16),
            style: const TextStyle(color: AppTheme.textB, fontSize: 12),
            items: const [
              DropdownMenuItem(value: 'newest', child: Text('Newest')),
              DropdownMenuItem(value: 'popular', child: Text('Popular')),
              DropdownMenuItem(value: 'saves', child: Text('Most Saved')),
              DropdownMenuItem(value: 'price_asc', child: Text('Price ↑')),
              DropdownMenuItem(value: 'price_desc', child: Text('Price ↓')),
              DropdownMenuItem(value: 'oldest', child: Text('Oldest')),
            ],
            onChanged: (v) { if (v != null) { _ctrl.sort.value = v; _ctrl.load(); } },
          ),
        )),
        const SizedBox(width: 8),
        Obx(() => Stack(clipBehavior: Clip.none, children: [
          Container(
            decoration: BoxDecoration(
              color: _ctrl.showFilter.value ? AppTheme.primary.withValues(alpha: 0.15) : AppTheme.card,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _ctrl.showFilter.value ? AppTheme.primary : AppTheme.border),
            ),
            child: IconButton(
              icon: Icon(Icons.tune_rounded, color: _ctrl.showFilter.value ? AppTheme.primary : AppTheme.textM, size: 18),
              onPressed: () => _ctrl.showFilter.toggle(),
              padding: const EdgeInsets.all(8), constraints: const BoxConstraints(), tooltip: 'Filter',
            ),
          ),
          if (_ctrl.activeFilterCount > 0)
            Positioned(top: -4, right: -4, child: CircleAvatar(
              radius: 8, backgroundColor: AppTheme.gold,
              child: Text('${_ctrl.activeFilterCount}', style: const TextStyle(color: Color(0xFF1E1A14), fontSize: 10, fontWeight: FontWeight.bold)),
            )),
        ])),
      ]),
      // Filter panel
      Obx(() => AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        transitionBuilder: (child, a) => SizeTransition(sizeFactor: a, child: FadeTransition(opacity: a, child: child)),
        child: _ctrl.showFilter.value
          ? Padding(key: const ValueKey('fp'), padding: const EdgeInsets.only(top: 12), child: FilterPanel(
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
      Obx(() => _ctrl.recentSearches.isNotEmpty && _ctrl.search.value.isEmpty ? Column(children: [
        const SizedBox(height: 10),
        SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
          const Icon(Icons.history, size: 12, color: AppTheme.textM),
          const SizedBox(width: 6),
          const Text('Recent:', style: TextStyle(color: AppTheme.textM, fontSize: 11)),
          const SizedBox(width: 8),
          ..._ctrl.recentSearches.map((s) => Padding(padding: const EdgeInsets.only(right: 6), child: ActionChip(
            label: Text(s, style: const TextStyle(fontSize: 10, color: AppTheme.textB)),
            onPressed: () { _debounce?.cancel(); _searchCtrl.text = s; _ctrl.search.value = s; _ctrl.load(); },
            backgroundColor: AppTheme.card2, side: const BorderSide(color: AppTheme.border),
            padding: const EdgeInsets.symmetric(horizontal: 4), visualDensity: VisualDensity.compact,
          ))),
          TextButton(
            onPressed: () { html.window.localStorage.remove('recent_searches'); _ctrl.recentSearches.clear(); },
            style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 6), minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
            child: const Text('Clear', style: TextStyle(fontSize: 10, color: AppTheme.textM)),
          ),
        ])),
      ]) : const SizedBox.shrink()),
    ]),
  );

  Widget _buildSectionHeader() => Padding(
    padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
    child: Obx(() => Text(
      _ctrl.search.value.isNotEmpty ? 'Results for "${_ctrl.search.value}"'
        : _ctrl.category.value.isNotEmpty ? '${_ctrl.category.value[0].toUpperCase()}${_ctrl.category.value.substring(1)} Agents'
        : 'All Agents',
      style: const TextStyle(color: AppTheme.textH, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5),
    )),
  );

  Widget _buildErrorView() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    const Icon(Icons.cloud_off_outlined, color: AppTheme.border2, size: 56),
    const SizedBox(height: 12),
    const Text('Could not load agents', style: TextStyle(color: AppTheme.textB, fontSize: 18)),
    const SizedBox(height: 6),
    const Text('Check your connection and try again', style: TextStyle(color: AppTheme.textM, fontSize: 13)),
    const SizedBox(height: 20),
    ElevatedButton.icon(onPressed: _ctrl.load, icon: const Icon(Icons.refresh, size: 16), label: const Text('Retry')),
  ]));

  Widget _buildEmpty() {
    if (_ctrl.search.value.isNotEmpty) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.search_off_rounded, color: AppTheme.border2, size: 52),
        const SizedBox(height: 12),
        const Text('No agents found', style: TextStyle(color: AppTheme.textB, fontSize: 16)),
        const SizedBox(height: 6),
        const Text('Try a different search term', style: TextStyle(color: AppTheme.textM, fontSize: 12)),
        const SizedBox(height: 16),
        TextButton(onPressed: _clearSearch, child: const Text('Clear search')),
      ]));
    }
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.search_off_rounded, color: AppTheme.border2, size: 56),
      const SizedBox(height: 12),
      const Text('No agents found', style: TextStyle(color: AppTheme.textB, fontSize: 18)),
      if (_ctrl.category.value.isNotEmpty) ...[
        const SizedBox(height: 8),
        TextButton(onPressed: () { _ctrl.category.value = ''; _ctrl.load(); }, child: const Text('Clear filters')),
      ],
    ]));
  }

  static const _kDiscoveryCategories = <(CharacterType, String, IconData)>[
    (CharacterType.wizard,     'backend',   Icons.code_outlined),
    (CharacterType.strategist, 'planning',  Icons.map_outlined),
    (CharacterType.oracle,     'data',      Icons.bar_chart_outlined),
    (CharacterType.guardian,   'security',  Icons.shield_outlined),
    (CharacterType.artisan,    'frontend',  Icons.brush_outlined),
    (CharacterType.bard,       'creative',  Icons.auto_stories_outlined),
    (CharacterType.scholar,    'research',  Icons.school_outlined),
    (CharacterType.merchant,   'marketing', Icons.trending_up_outlined),
  ];

  static const _kPopularTags = ['AI', 'coding', 'writing', 'analysis', 'planning', 'security', 'research', 'marketing', 'automation', 'data'];

  Widget _buildDiscovery() => Padding(
    padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Browse by Category', style: TextStyle(color: AppTheme.textH, fontSize: 14, fontWeight: FontWeight.w600)),
      const SizedBox(height: 10),
      GridView.builder(
        shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 1.5),
        itemCount: _kDiscoveryCategories.length,
        itemBuilder: (_, i) {
          final (type, key, icon) = _kDiscoveryCategories[i];
          final color = type.primaryColor;
          return InkWell(
            onTap: () { _ctrl.category.value = key; _ctrl.load(); },
            borderRadius: BorderRadius.circular(10),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [color.withValues(alpha: 0.2), AppTheme.card2]),
                borderRadius: BorderRadius.circular(10), border: Border.all(color: color.withValues(alpha: 0.4)),
              ),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(icon, color: color, size: 22),
                const SizedBox(height: 4),
                Text(type.displayName, style: const TextStyle(color: AppTheme.textH, fontSize: 11, fontWeight: FontWeight.w600)),
              ]),
            ),
          );
        },
      ),
      const SizedBox(height: 16),
      const Text('Popular Tags', style: TextStyle(color: AppTheme.textH, fontSize: 14, fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      Wrap(spacing: 6, runSpacing: 6, children: _kPopularTags.map((tag) => ActionChip(
        label: Text(tag, style: const TextStyle(color: AppTheme.textB, fontSize: 11)),
        onPressed: () { _debounce?.cancel(); _searchCtrl.text = tag; _ctrl.search.value = tag; _saveRecentSearch(tag); _ctrl.load(); },
        backgroundColor: AppTheme.card2, side: const BorderSide(color: AppTheme.border2),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0), visualDensity: VisualDensity.compact,
      )).toList()),
      const SizedBox(height: 8),
    ]),
  );
}

/// Wraps [AgentCard] with a bookmark/save button overlay
class _AgentCardWithSave extends StatelessWidget {
  final AgentModel agent;
  final VoidCallback onSave;
  const _AgentCardWithSave({required this.agent, required this.onSave});

  @override
  Widget build(BuildContext context) => Stack(clipBehavior: Clip.none, children: [
    AgentCard(agent: agent),
    Positioned(
      top: 8, right: 8,
      child: GestureDetector(
        onTap: onSave,
        child: Container(
          width: 28, height: 28,
          decoration: BoxDecoration(color: AppTheme.surface.withValues(alpha: 0.9), shape: BoxShape.circle, border: Border.all(color: AppTheme.border2)),
          child: const Icon(Icons.bookmark_add_outlined, size: 15, color: AppTheme.gold),
        ),
      ),
    ),
  ]);
}
