import 'dart:async';
import 'dart:convert';
// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/models/agent_model.dart';
import '../../../shared/services/api_service.dart';
import '../../../shared/services/wallet_service.dart';
import '../widgets/agent_card.dart';
import '../widgets/category_sidebar.dart';
import '../widgets/filter_panel.dart';
import '../widgets/trending_row.dart';
import '../../../shared/widgets/onboarding_modal.dart';
import '../../character/character_types.dart';

class StoreScreen extends StatefulWidget {
  const StoreScreen({super.key});
  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen> {
  List<AgentModel> _agents = [];
  bool _loading = true;
  bool _error = false;
  String _search = '';
  String _category = '';
  String _sort = 'newest';
  int _total = 0;
  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  List<String> _recentSearches = [];

  // Filter panel state
  bool _showFilter = false;
  double _minPrice = 0;
  double _maxPrice = 10;
  List<String> _filterTags = [];

  @override
  void initState() {
    super.initState();
    _loadRecentSearches();
    _load();
    // Show onboarding on first visit
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (OnboardingModal.shouldShow() && mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => const OnboardingModal(),
        );
      }
    });
  }

  void _loadRecentSearches() {
    try {
      final raw = html.window.localStorage['recent_searches'] ?? '[]';
      final list = (jsonDecode(raw) as List).cast<String>();
      setState(() => _recentSearches = list.take(8).toList());
    } catch (_) {}
  }

  void _saveRecentSearch(String term) {
    if (term.trim().isEmpty) return;
    try {
      _recentSearches.remove(term);
      _recentSearches.insert(0, term);
      if (_recentSearches.length > 8) _recentSearches = _recentSearches.sublist(0, 8);
      html.window.localStorage['recent_searches'] = jsonEncode(_recentSearches);
    } catch (_) {}
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = false; });
    try {
      final r = await ApiService.instance.listAgents(
        category: _category,
        search: _search,
        sort: _sort,
        minPrice: _minPrice > 0 ? _minPrice : null,
        maxPrice: _maxPrice < 10 ? _maxPrice : null,
        tags: _filterTags.isNotEmpty ? _filterTags : null,
      );
      if (mounted) setState(() { _agents = r.agents; _total = r.total; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _loading = false; _error = true; });
    }
  }

  void _resetFilters() {
    setState(() {
      _minPrice = 0;
      _maxPrice = 10;
      _filterTags = [];
    });
    _load();
  }

  int get _activeFilterCount {
    int count = 0;
    if (_minPrice > 0 || _maxPrice < 10) count++;
    count += _filterTags.length;
    return count;
  }

  void _onSearchChanged(String val) {
    setState(() {}); // update clear button visibility immediately
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      setState(() => _search = val);
      _saveRecentSearch(val);
      _load();
    });
  }

  void _clearSearch() {
    _debounce?.cancel();
    _searchCtrl.clear();
    _search = '';
    _load();
  }

  Future<void> _onSaveAgent(AgentModel agent) async {
    if (!ApiService.instance.isAuthenticated || !WalletService.instance.isConnected) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Connect your wallet to save agents'),
          action: SnackBarAction(
            label: 'Connect',
            onPressed: () => context.go('/wallet'),
          ),
        ),
      );
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
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFDDD1BB),
    body: Row(
      children: [
        // Category sidebar
        CategorySidebar(
          selectedCategory: _category,
          onSelect: (cat) {
            _searchCtrl.clear();
            setState(() { _category = cat; _search = ''; });
            _load();
          },
        ),
        // Main content
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            color: const Color(0xFF81231E),
            child: CustomScrollView(cacheExtent: 800, slivers: [
              SliverToBoxAdapter(child: _header()),
              // Trending row when search is empty
              if (_search.isEmpty)
                const SliverToBoxAdapter(child: TrendingRow()),
              // Discovery section when no filter active
              if (_search.isEmpty && _category.isEmpty && !_loading)
                SliverToBoxAdapter(child: _buildDiscovery()),
              SliverToBoxAdapter(child: _sectionHeader()),
              if (_loading)
                const SliverFillRemaining(child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  CircularProgressIndicator(color: Color(0xFF81231E)),
                  SizedBox(height: 12),
                  Text('Loading agents...', style: TextStyle(color: Color(0xFF7A6E52), fontSize: 12)),
                ])))
              else if (_error)
                SliverFillRemaining(child: _errorView())
              else if (_agents.isEmpty)
                SliverFillRemaining(child: _empty())
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 300,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 0.72,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (_, i) => RepaintBoundary(
                        key: ValueKey(_agents[i].id),
                        child: _AgentCardWithSave(
                          agent: _agents[i],
                          onSave: () => _onSaveAgent(_agents[i]),
                        ),
                      ),
                      childCount: _agents.length,
                    ),
                  ),
                ),
            ]),
          ),
        ),
      ],
    ),
  );

  Widget _header() => Padding(
    padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Agent Store', style: TextStyle(color: Color(0xFF2B2C1E), fontSize: 30, fontWeight: FontWeight.bold)),
      const SizedBox(height: 4),
      Text('$_total agents available', style: const TextStyle(color: Color(0xFF7A6E52), fontSize: 13)),
      const SizedBox(height: 16),
      Row(children: [
        Expanded(
          child: TextField(
            controller: _searchCtrl,
            onSubmitted: (v) { _debounce?.cancel(); setState(() => _search = v); _saveRecentSearch(v); _load(); },
            onChanged: _onSearchChanged,
            style: const TextStyle(color: Color(0xFF2B2C1E)),
            decoration: InputDecoration(
              hintText: 'Search agents...',
              prefixIcon: const Icon(Icons.search, color: Color(0xFF7A6E52)),
              suffixIcon: _searchCtrl.text.isNotEmpty
                  ? IconButton(icon: const Icon(Icons.clear, color: Color(0xFF7A6E52)), onPressed: _clearSearch)
                  : null,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFB8AA88),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFC0B490)),
          ),
          child: DropdownButton<String>(
            value: _sort,
            dropdownColor: const Color(0xFFB8AA88),
            underline: const SizedBox(),
            icon: const Icon(Icons.sort, color: Color(0xFF6B5A40), size: 16),
            style: const TextStyle(color: Color(0xFF6B5A40), fontSize: 12),
            items: const [
              DropdownMenuItem(value: 'newest',     child: Text('Newest')),
              DropdownMenuItem(value: 'popular',    child: Text('Popular')),
              DropdownMenuItem(value: 'saves',      child: Text('Most Saved')),
              DropdownMenuItem(value: 'price_asc',  child: Text('Price \u2191')),
              DropdownMenuItem(value: 'price_desc', child: Text('Price \u2193')),
              DropdownMenuItem(value: 'oldest',     child: Text('Oldest')),
            ],
            onChanged: (v) { if (v != null) setState(() { _sort = v; _load(); }); },
          ),
        ),
        const SizedBox(width: 8),
        // Filter toggle button with active count badge
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              decoration: BoxDecoration(
                color: _showFilter
                    ? const Color(0xFF81231E).withValues(alpha: 0.15)
                    : const Color(0xFFB8AA88),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _showFilter
                      ? const Color(0xFF81231E)
                      : const Color(0xFFC0B490),
                ),
              ),
              child: IconButton(
                icon: Icon(
                  Icons.tune,
                  color: _showFilter
                      ? const Color(0xFF81231E)
                      : const Color(0xFF6B5A40),
                  size: 18,
                ),
                onPressed: () => setState(() => _showFilter = !_showFilter),
                padding: const EdgeInsets.all(8),
                constraints: const BoxConstraints(),
                tooltip: 'Filter',
              ),
            ),
            if (_activeFilterCount > 0)
              Positioned(
                top: -4,
                right: -4,
                child: CircleAvatar(
                  radius: 8,
                  backgroundColor: const Color(0xFF81231E),
                  child: Text(
                    '$_activeFilterCount',
                    style: const TextStyle(
                      color: Color(0xFFDDD1BB),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ]),
      // Collapsible filter panel
      AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        transitionBuilder: (child, animation) => SizeTransition(
          sizeFactor: animation,
          child: FadeTransition(opacity: animation, child: child),
        ),
        child: _showFilter
            ? Padding(
                key: const ValueKey('filter_panel'),
                padding: const EdgeInsets.only(top: 12),
                child: FilterPanel(
                  minPrice: 0,
                  maxPrice: 10,
                  currentMin: _minPrice,
                  currentMax: _maxPrice,
                  selectedTags: _filterTags,
                  onPriceChanged: (range) {
                    setState(() {
                      _minPrice = range.start;
                      _maxPrice = range.end;
                    });
                    _load();
                  },
                  onTagToggled: (tag) {
                    setState(() {
                      if (_filterTags.contains(tag)) {
                        _filterTags = List.from(_filterTags)..remove(tag);
                      } else {
                        _filterTags = List.from(_filterTags)..add(tag);
                      }
                    });
                    _load();
                  },
                  onReset: _resetFilters,
                ),
              )
            : const SizedBox.shrink(key: ValueKey('filter_hidden')),
      ),
      if (_recentSearches.isNotEmpty && _search.isEmpty) ...[
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              const Icon(Icons.history, size: 12, color: Color(0xFF7A6E52)),
              const SizedBox(width: 6),
              const Text('Recent:', style: TextStyle(color: Color(0xFF7A6E52), fontSize: 11)),
              const SizedBox(width: 8),
              ..._recentSearches.map((s) => Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ActionChip(
                  label: Text(s, style: const TextStyle(fontSize: 10, color: Color(0xFF6B5A40))),
                  onPressed: () {
                    _debounce?.cancel();
                    _searchCtrl.text = s;
                    setState(() => _search = s);
                    _load();
                  },
                  backgroundColor: const Color(0xFFB8AA88),
                  side: const BorderSide(color: Color(0xFFC0B490)),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  visualDensity: VisualDensity.compact,
                ),
              )),
              TextButton(
                onPressed: () {
                  html.window.localStorage.remove('recent_searches');
                  setState(() => _recentSearches = []);
                },
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Clear', style: TextStyle(fontSize: 10, color: Color(0xFF7A6E52))),
              ),
            ],
          ),
        ),
      ],
    ]),
  );

  Widget _sectionHeader() => Padding(
    padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
    child: Text(
      _search.isNotEmpty
          ? 'Results for "$_search"'
          : _category.isNotEmpty
              ? '${_category[0].toUpperCase()}${_category.substring(1)} Agents'
              : 'All Agents',
      style: const TextStyle(
        color: Color(0xFF2B2C1E),
        fontSize: 16,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.5,
      ),
    ),
  );

  Widget _errorView() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    const Icon(Icons.cloud_off_outlined, color: Color(0xFFC0B490), size: 56),
    const SizedBox(height: 12),
    const Text('Could not load agents', style: TextStyle(color: Color(0xFF6B5A40), fontSize: 18)),
    const SizedBox(height: 6),
    const Text('Check your connection and try again', style: TextStyle(color: Color(0xFF7A6E52), fontSize: 13)),
    const SizedBox(height: 20),
    ElevatedButton.icon(
      onPressed: _load,
      icon: const Icon(Icons.refresh, size: 16),
      label: const Text('Retry'),
    ),
  ]));

  Widget _empty() {
    if (_search.isNotEmpty) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.search_off, color: Color(0xFFC0B490), size: 52),
        const SizedBox(height: 12),
        const Text('No agents found', style: TextStyle(color: Color(0xFF6B5A40), fontSize: 16)),
        const SizedBox(height: 6),
        const Text('Try a different search term', style: TextStyle(color: Color(0xFF7A6E52), fontSize: 12)),
        const SizedBox(height: 16),
        TextButton(onPressed: _clearSearch, child: const Text('Clear search')),
      ]));
    }
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.search_off, color: Color(0xFFC0B490), size: 56),
      const SizedBox(height: 12),
      const Text('No agents found', style: TextStyle(color: Color(0xFF6B5A40), fontSize: 18)),
      if (_category.isNotEmpty) ...[
        const SizedBox(height: 8),
        TextButton(onPressed: () { setState(() => _category = ''); _load(); }, child: const Text('Clear filters')),
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

  static const _kPopularTags = [
    'AI', 'coding', 'writing', 'analysis', 'planning',
    'security', 'research', 'marketing', 'automation', 'data',
  ];

  Widget _buildDiscovery() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Category grid ──────────────────────────────────────────────────
        const Text(
          'Browse by Category',
          style: TextStyle(color: Color(0xFF2B2C1E), fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.5,
          ),
          itemCount: _kDiscoveryCategories.length,
          itemBuilder: (_, i) {
            final (type, key, icon) = _kDiscoveryCategories[i];
            final color = type.primaryColor;
            return InkWell(
              onTap: () {
                setState(() { _category = key; });
                _load();
              },
              borderRadius: BorderRadius.circular(10),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [color.withValues(alpha: 0.25), const Color(0xFFE8DEC9)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: color.withValues(alpha: 0.35)),
                ),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(icon, color: color, size: 22),
                  const SizedBox(height: 4),
                  Text(
                    type.displayName,
                    style: const TextStyle(color: Color(0xFF2B2C1E), fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ]),
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        // ── Popular tags ───────────────────────────────────────────────────
        const Text(
          'Popular Tags',
          style: TextStyle(color: Color(0xFF2B2C1E), fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: _kPopularTags.map((tag) => ActionChip(
            label: Text(tag, style: const TextStyle(color: Color(0xFF4A4033), fontSize: 11)),
            onPressed: () {
              _debounce?.cancel();
              _searchCtrl.text = tag;
              setState(() => _search = tag);
              _saveRecentSearch(tag);
              _load();
            },
            backgroundColor: const Color(0xFFB8AA88),
            side: const BorderSide(color: Color(0xFFADA07A)),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
            visualDensity: VisualDensity.compact,
          )).toList(),
        ),
        const SizedBox(height: 8),
      ]),
    );
  }

  @override
  void dispose() { _debounce?.cancel(); _searchCtrl.dispose(); super.dispose(); }
}

/// Wraps [AgentCard] and overlays a bookmark/save button in the top-right corner.
class _AgentCardWithSave extends StatelessWidget {
  final AgentModel agent;
  final VoidCallback onSave;
  const _AgentCardWithSave({required this.agent, required this.onSave});

  @override
  Widget build(BuildContext context) {
    return Stack(clipBehavior: Clip.none, children: [
      AgentCard(agent: agent),
      Positioned(
        top: 8,
        right: 8,
        child: GestureDetector(
          onTap: onSave,
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: const Color(0xFFDDD1BB).withValues(alpha: 0.75),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFC0B490)),
            ),
            child: const Icon(Icons.bookmark_add_outlined, size: 15, color: Color(0xFF6B5A40)),
          ),
        ),
      ),
    ]);
  }
}
