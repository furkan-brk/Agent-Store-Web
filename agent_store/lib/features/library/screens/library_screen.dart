// lib/features/library/screens/library_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme.dart';
import '../../../shared/utils/app_snack_bar.dart';
import '../../../controllers/library_controller.dart';
import '../../../shared/models/agent_model.dart';
import '../../../shared/services/api_service.dart';
import '../../../shared/services/collection_service.dart';
import '../../../shared/services/wallet_service.dart';
import '../../../shared/widgets/achievement_badge.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/skeleton_widgets.dart';
import '../../store/widgets/agent_card.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});
  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

/// NOTE: LibraryScreen keeps a thin StatefulWidget shell for:
///  - TabController lifecycle (requires TickerProvider)
///  - Local search/sort/filter state
/// All *data state* is in LibraryController (GetX).
class _LibraryScreenState extends State<LibraryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  late final LibraryController _ctrl;
  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  // Local filter/sort state for saved tab
  String _searchQuery = '';
  String _sortBy = 'newest'; // newest | oldest | rarity | category
  String _filterCategory = ''; // empty = all
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _ctrl = Get.isRegistered<LibraryController>()
        ? Get.find<LibraryController>()
        : Get.put(LibraryController(), permanent: true);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() => _hasError = false);
    try {
      await _ctrl.load();
    } catch (_) {
      if (mounted) setState(() => _hasError = true);
    }
  }

  void _onSearchChanged(String val) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _searchQuery = val.toLowerCase().trim());
    });
  }

  void _clearSearch() {
    _debounce?.cancel();
    _searchCtrl.clear();
    setState(() => _searchQuery = '');
  }

  /// Apply local search + category filter + sort to a list of agents.
  List<AgentModel> _applyFilters(List<AgentModel> agents) {
    var result = agents.toList();

    // Search filter
    if (_searchQuery.isNotEmpty) {
      result = result.where((a) {
        return a.title.toLowerCase().contains(_searchQuery) ||
            a.description.toLowerCase().contains(_searchQuery) ||
            a.category.toLowerCase().contains(_searchQuery) ||
            a.tags.any((t) => t.toLowerCase().contains(_searchQuery));
      }).toList();
    }

    // Category filter
    if (_filterCategory.isNotEmpty) {
      result = result
          .where(
              (a) => a.category.toLowerCase() == _filterCategory.toLowerCase())
          .toList();
    }

    // Sort
    switch (_sortBy) {
      case 'oldest':
        result.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      case 'rarity':
        result.sort((a, b) => b.rarity.index.compareTo(a.rarity.index));
      case 'category':
        result.sort((a, b) => a.category.compareTo(b.category));
      case 'newest':
      default:
        result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
    return result;
  }

  /// Collect unique categories from agents list.
  List<String> _uniqueCategories(List<AgentModel> agents) {
    final cats = <String>{};
    for (final a in agents) {
      if (a.category.isNotEmpty) cats.add(a.category);
    }
    final sorted = cats.toList()..sort();
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    if (!ApiService.instance.isAuthenticated) return _loginPrompt(context);

    return Obx(() => Scaffold(
          backgroundColor: AppTheme.bg,
          body: ShimmerScope(
            child: RefreshIndicator(
              onRefresh: _reload,
              color: AppTheme.primary,
              child: Column(children: [
                _buildHeader(),
                Expanded(
                  child: _ctrl.isLoading.value
                      ? _buildLoadingSkeleton()
                      : _hasError
                          ? _buildErrorState()
                          : TabBarView(
                              controller: _tabCtrl,
                              children: [
                                _buildSavedTab(),
                                _buildCreatedTab(),
                              ],
                            ),
                ),
              ]),
            ),
          ),
        ));
  }

  // ── Header ──────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    final wallet = WalletService.instance.connectedWallet ?? '';
    final short = wallet.length > 10
        ? '${wallet.substring(0, 6)}...${wallet.substring(wallet.length - 4)}'
        : wallet;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = AppBreakpoints.isMobile(screenWidth);
    final hPad = isMobile ? 14.0 : 24.0;

    return Obx(() => Container(
          color: AppTheme.surface,
          padding: EdgeInsets.fromLTRB(hPad, isMobile ? 16 : 24, hPad, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title row
              Row(
                children: [
                  Container(
                    width: isMobile ? 32 : 36,
                    height: isMobile ? 32 : 36,
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: AppTheme.primary.withValues(alpha: 0.3)),
                    ),
                    child: Icon(Icons.collections_bookmark_rounded,
                        color: AppTheme.primary, size: isMobile ? 16 : 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'My Library',
                          style: TextStyle(
                            color: AppTheme.textH,
                            fontSize: isMobile ? 18 : 20,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          short,
                          style: const TextStyle(
                              color: AppTheme.textM, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              // Stats chips row — scrollable on mobile
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _statChip(Icons.bolt, '${_ctrl.credits.value}',
                        AppTheme.gold, 'credits'),
                    SizedBox(width: isMobile ? 8 : 12),
                    _statChip(Icons.auto_awesome_outlined,
                        '${_ctrl.created.length}', AppTheme.primary, 'created'),
                    SizedBox(width: isMobile ? 8 : 12),
                    _statChip(Icons.bookmark_border, '${_ctrl.totalSaves}',
                        AppTheme.primary, 'saves'),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Tabs
              TabBar(
                controller: _tabCtrl,
                isScrollable: isMobile,
                tabAlignment: isMobile ? TabAlignment.start : null,
                tabs: [
                  Tab(text: 'Saved (${_ctrl.saved.length})'),
                  Tab(text: 'Created (${_ctrl.created.length})'),
                ],
                labelColor: AppTheme.primary,
                unselectedLabelColor: AppTheme.textM,
                indicatorColor: AppTheme.primary,
                dividerColor: AppTheme.border,
              ),
            ],
          ),
        ));
  }

  Widget _statChip(
          IconData icon, String value, Color color, String label) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(width: 3),
        Text(value,
            style: TextStyle(
                color: color, fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(width: 3),
        Text(label,
            style: const TextStyle(color: AppTheme.textM, fontSize: 11)),
      ]);

  // ── Loading Skeleton ──────────────────────────────────────────────────────

  Widget _buildLoadingSkeleton() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = AppBreakpoints.isMobile(screenWidth);
    final hPad = isMobile ? 12.0 : 20.0;
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        // Skeleton search bar placeholder
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(hPad, 16, hPad, 8),
            child: const ShimmerBox(
              width: double.infinity,
              height: 44,
              radius: 10,
              color: AppTheme.card2,
            ),
          ),
        ),
        // Skeleton grid
        SliverPadding(
          padding: EdgeInsets.fromLTRB(hPad, 8, hPad, 20),
          sliver: SliverGrid(
            gridDelegate: _responsiveGridDelegate(screenWidth),
            delegate: SliverChildBuilderDelegate(
              (_, __) => const AgentCardSkeleton(),
              childCount: isMobile ? 6 : 8,
            ),
          ),
        ),
      ],
    );
  }

  /// Responsive grid delegate based on available width.
  SliverGridDelegate _responsiveGridDelegate(double width) {
    if (AppBreakpoints.isMobile(width)) {
      return const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 240,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.70,
      );
    }
    return const SliverGridDelegateWithMaxCrossAxisExtent(
      maxCrossAxisExtent: 300,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 0.72,
    );
  }

  // ── Error State ───────────────────────────────────────────────────────────

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.cloud_off_outlined,
              color: AppTheme.border2, size: 56),
          const SizedBox(height: 16),
          const Text(
            'Could not load your library',
            style: TextStyle(
                color: AppTheme.textH,
                fontSize: 18,
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          const Text(
            'Check your connection and try again',
            style: TextStyle(color: AppTheme.textM, fontSize: 13),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _reload,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  // ── Saved Tab ─────────────────────────────────────────────────────────────

  Widget _buildSavedTab() => Obx(() {
        final baseList = _ctrl.filteredSaved;
        final filtered = _applyFilters(baseList);
        final categories = _uniqueCategories(_ctrl.saved);
        final screenWidth = MediaQuery.of(context).size.width;
        final isMobile = AppBreakpoints.isMobile(screenWidth);
        final hPad = isMobile ? 12.0 : 20.0;

        if (_ctrl.saved.isEmpty && _searchQuery.isEmpty) {
          return _buildEmptySavedState();
        }

        return CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // Collections section
            SliverToBoxAdapter(child: _buildCollectionsSection()),
            // Search bar + sort/filter row
            SliverToBoxAdapter(
              child: _buildSearchAndSort(categories),
            ),
            // Count indicator
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(hPad, 4, hPad, 12),
                child: Row(
                  children: [
                    const Icon(Icons.grid_view_rounded,
                        size: 13, color: AppTheme.textM),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${filtered.length} agent${filtered.length == 1 ? '' : 's'}${_searchQuery.isNotEmpty || _filterCategory.isNotEmpty ? ' found' : ' in your library'}',
                        style: const TextStyle(
                            color: AppTheme.textM, fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Grid or empty search result
            if (filtered.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: hPad),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.search_off_rounded,
                            color: AppTheme.border2, size: 48),
                        const SizedBox(height: 12),
                        const Text('No matching agents',
                            style: TextStyle(
                                color: AppTheme.textB, fontSize: 16)),
                        const SizedBox(height: 6),
                        const Text(
                            'Try adjusting your search or filters',
                            style: TextStyle(
                                color: AppTheme.textM, fontSize: 12)),
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: () {
                            _clearSearch();
                            setState(() {
                              _filterCategory = '';
                              _sortBy = 'newest';
                            });
                          },
                          child: const Text('Clear all filters'),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: EdgeInsets.fromLTRB(hPad, 0, hPad, 20),
                sliver: SliverGrid(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) {
                      final a = filtered[i];
                      final wallet =
                          WalletService.instance.connectedWallet;
                      final isOwned = wallet != null &&
                          a.creatorWallet.toLowerCase() ==
                              wallet.toLowerCase();
                      return _LibraryAgentCard(
                        agent: a,
                        isOwned: isOwned,
                        onLongPress: () =>
                            _showAddToCollectionSheet(a),
                        onRemove: () => _confirmRemoveAgent(a),
                        collectionDots: _CollectionDots(agentId: a.id),
                      );
                    },
                    childCount: filtered.length,
                  ),
                  gridDelegate: _responsiveGridDelegate(screenWidth),
                ),
              ),
          ],
        );
      });

  Widget _buildEmptySavedState() {
    final isMobile = AppBreakpoints.isMobile(MediaQuery.sizeOf(context).width);
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: isMobile ? 24 : 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
                border: Border.all(
                    color: AppTheme.primary.withValues(alpha: 0.2)),
              ),
              child: const Icon(Icons.bookmarks_outlined,
                  color: AppTheme.primary, size: 36),
            ),
            const SizedBox(height: 20),
            const Text(
              'Your library is empty',
              style: TextStyle(
                color: AppTheme.textH,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Browse the store to discover AI agents and save them to your library for quick access.',
              style: TextStyle(
                  color: AppTheme.textM, fontSize: 13, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => context.go('/'),
              icon: const Icon(Icons.explore_outlined, size: 18),
              label: const Text('Browse the Store'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchAndSort(List<String> categories) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = AppBreakpoints.isMobile(screenWidth);
    final hPad = isMobile ? 12.0 : 20.0;
    return Padding(
      padding: EdgeInsets.fromLTRB(hPad, 12, hPad, 0),
      child: Column(
        children: [
          // Search bar + sort dropdown
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: _onSearchChanged,
                    style: const TextStyle(
                        color: AppTheme.textH, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Search your library...',
                      hintStyle: const TextStyle(
                          color: AppTheme.textM, fontSize: 13),
                      prefixIcon: const Icon(Icons.search_rounded,
                          color: AppTheme.textM, size: 18),
                      suffixIcon: _searchCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded,
                                  color: AppTheme.textM, size: 16),
                              onPressed: _clearSearch,
                            )
                          : null,
                      fillColor: AppTheme.card,
                      filled: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 0),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                            const BorderSide(color: AppTheme.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                            color: AppTheme.primary, width: 1.5),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Sort dropdown
              Container(
                height: 40,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: AppTheme.card,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.border),
                ),
                child: DropdownButton<String>(
                  value: _sortBy,
                  dropdownColor: AppTheme.card2,
                  underline: const SizedBox(),
                  icon: const Icon(Icons.sort_rounded,
                      color: AppTheme.textM, size: 16),
                  style: const TextStyle(
                      color: AppTheme.textB, fontSize: 12),
                  items: const [
                    DropdownMenuItem(
                        value: 'newest', child: Text('Newest')),
                    DropdownMenuItem(
                        value: 'oldest', child: Text('Oldest')),
                    DropdownMenuItem(
                        value: 'rarity', child: Text('Rarity')),
                    DropdownMenuItem(
                        value: 'category',
                        child: Text('Category')),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _sortBy = v);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Category filter chips
          if (categories.isNotEmpty)
            SizedBox(
              height: 32,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: categories.length + 1,
                separatorBuilder: (_, __) =>
                    const SizedBox(width: 6),
                itemBuilder: (ctx, i) {
                  if (i == 0) {
                    // "All" chip
                    final isSelected = _filterCategory.isEmpty;
                    return _FilterChip(
                      label: 'All',
                      isSelected: isSelected,
                      onTap: () =>
                          setState(() => _filterCategory = ''),
                    );
                  }
                  final cat = categories[i - 1];
                  final isSelected = _filterCategory == cat;
                  return _FilterChip(
                    label: cat[0].toUpperCase() +
                        cat.substring(1),
                    isSelected: isSelected,
                    onTap: () => setState(
                        () => _filterCategory = isSelected ? '' : cat),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  void _confirmRemoveAgent(AgentModel agent) async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Remove from Library',
      message: 'Remove "${agent.title}" from your library?',
      confirmLabel: 'Remove',
      isDestructive: true,
      icon: Icons.delete_outline_rounded,
    );
    if (confirmed) {
      final ok = await ApiService.instance.removeFromLibrary(agent.id);
      if (mounted) {
        if (ok) {
          _ctrl.load();
          AppSnackBar.info(context, '"${agent.title}" removed from library');
        } else {
          AppSnackBar.error(context, 'Failed to remove agent. Try again.');
        }
      }
    }
  }

  Widget _buildCollectionsSection() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = AppBreakpoints.isMobile(screenWidth);
    final hPad = isMobile ? 12.0 : 20.0;
    return Obx(() => Container(
        padding: EdgeInsets.fromLTRB(hPad, 14, hPad, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.folder_special_outlined,
                  color: AppTheme.textM, size: 15),
              const SizedBox(width: 6),
              const Text('Collections',
                  style: TextStyle(
                      color: AppTheme.textH,
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
              const Spacer(),
              IconButton(
                icon:
                    const Icon(Icons.add, color: AppTheme.primary, size: 20),
                onPressed: _showNewCollectionDialog,
                tooltip: 'New collection',
                constraints: const BoxConstraints(),
                padding: EdgeInsets.zero,
              ),
            ]),
            const SizedBox(height: 8),
            if (_ctrl.collections.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(Icons.info_outline,
                        color: AppTheme.textM.withValues(alpha: 0.6),
                        size: 13),
                    const SizedBox(width: 6),
                    const Text(
                      'No collections yet. Tap + to create one.',
                      style: TextStyle(color: AppTheme.textM, fontSize: 12),
                    ),
                  ],
                ),
              )
            else
              SizedBox(
                height: 34,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _ctrl.collections.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (ctx, i) {
                    final col = _ctrl.collections[i];
                    final isSelected =
                        _ctrl.selectedCollectionId.value == col.id;
                    final colColor = _hexToColor(col.color);
                    return GestureDetector(
                      onTap: () => _ctrl.selectedCollectionId.value =
                          isSelected ? null : col.id,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? colColor.withValues(alpha: 0.18)
                              : AppTheme.card2,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected
                                ? colColor
                                : colColor.withValues(alpha: 0.35),
                            width: isSelected ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                  color: colColor,
                                  shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 6),
                            Text(col.name,
                                style: TextStyle(
                                  color: isSelected
                                      ? colColor
                                      : AppTheme.textB,
                                  fontSize: 12,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                )),
                            const SizedBox(width: 4),
                            Text('${col.agentIds.length}',
                                style: TextStyle(
                                  color: isSelected
                                      ? colColor.withValues(alpha: 0.8)
                                      : AppTheme.textM,
                                  fontSize: 11,
                                )),
                            const SizedBox(width: 4),
                            GestureDetector(
                              onTap: () =>
                                  _confirmDeleteCollection(col),
                              child: Icon(Icons.close,
                                  size: 12,
                                  color: isSelected
                                      ? colColor.withValues(alpha: 0.8)
                                      : AppTheme.textM),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 4),
            const Divider(color: AppTheme.border),
          ],
        ),
      ));
  }

  void _showNewCollectionDialog() {
    showDialog<void>(
      context: context,
      builder: (_) =>
          _NewCollectionDialog(onCreated: (_) => _ctrl.refreshCollections()),
    );
  }

  void _confirmDeleteCollection(AgentCollection col) {
    showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppTheme.border2),
        ),
        title: const Text('Delete Collection',
            style: TextStyle(color: AppTheme.textH)),
        content: Text(
          'Delete "${col.name}"? Agents won\'t be removed from your library.',
          style: const TextStyle(color: AppTheme.textB, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style:
                FilledButton.styleFrom(backgroundColor: AppTheme.primary),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    ).then((confirmed) async {
      if (confirmed == true) {
        await CollectionService.instance.delete(col.id);
        _ctrl.refreshCollections();
      }
    });
  }

  void _showAddToCollectionSheet(AgentModel agent) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => _AddToCollectionSheet(
          agent: agent, onChanged: _ctrl.refreshCollections),
    );
  }

  // ── Created Tab ───────────────────────────────────────────────────────────

  Widget _buildCreatedTab() => Obx(() {
        final achievements = Achievement.compute(
          agentCount: _ctrl.created.length,
          totalSaves: _ctrl.totalSaves,
          totalUses: _ctrl.totalUses,
          libraryCount: _ctrl.saved.length,
          credits: _ctrl.credits.value,
        );
        final screenWidth = MediaQuery.of(context).size.width;
        final isMobile = AppBreakpoints.isMobile(screenWidth);
        final hPad = isMobile ? 12.0 : 20.0;
        final gridDelegate = _responsiveGridDelegate(screenWidth);
        final wallet = WalletService.instance.connectedWallet;

        if (_ctrl.created.isEmpty) {
          return CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(hPad, 20, hPad, 0),
                  child: AchievementRow(achievements: achievements),
                ),
              ),
              SliverFillRemaining(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: isMobile ? 24 : 40),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: AppTheme.gold.withValues(alpha: 0.08),
                            shape: BoxShape.circle,
                            border: Border.all(
                                color:
                                    AppTheme.gold.withValues(alpha: 0.2)),
                          ),
                          child: const Icon(
                              Icons.auto_awesome_outlined,
                              color: AppTheme.gold,
                              size: 36),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'No agents created yet',
                          style: TextStyle(
                            color: AppTheme.textH,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Create your first AI agent and share it with the community.',
                          style: TextStyle(
                              color: AppTheme.textM,
                              fontSize: 13,
                              height: 1.5),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: () => context.go('/create'),
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: const Text('Create Agent'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        }

        return CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(hPad, 20, hPad, 8),
                child: AchievementRow(achievements: achievements),
              ),
            ),
            // Created count
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(hPad, 8, hPad, 12),
                child: Row(
                  children: [
                    const Icon(Icons.grid_view_rounded,
                        size: 13, color: AppTheme.textM),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${_ctrl.created.length} agent${_ctrl.created.length == 1 ? '' : 's'} created',
                        style: const TextStyle(
                            color: AppTheme.textM, fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(hPad, 0, hPad, 20),
              sliver: SliverGrid(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) {
                    final a = _ctrl.created[i];
                    final isOwned = wallet != null &&
                        a.creatorWallet.toLowerCase() ==
                            wallet.toLowerCase();
                    return Stack(children: [
                      AgentCard(agent: a, isOwned: isOwned),
                      Positioned(
                        bottom: 8,
                        right: 8,
                        child: GestureDetector(
                          onTap: () async {
                            final newPrice =
                                await showDialog<double>(
                              context: context,
                              builder: (_) => _SetPriceDialog(
                                agentId: a.id,
                                currentPrice: a.price,
                              ),
                            );
                            if (newPrice != null) {
                              _ctrl.updateAgentPrice(a.id, newPrice);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: a.price > 0
                                  ? AppTheme.gold.withValues(alpha: 0.85)
                                  : AppTheme.card2
                                      .withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              a.price > 0
                                  ? '${a.price.toStringAsFixed(2)} MON'
                                  : 'Free',
                              style: TextStyle(
                                color: a.price > 0
                                    ? const Color(0xFF1E1A14)
                                    : AppTheme.textB,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ]);
                  },
                  childCount: _ctrl.created.length,
                ),
                gridDelegate: gridDelegate,
              ),
            ),
          ],
        );
      });

  Widget _loginPrompt(BuildContext context) => Scaffold(
        backgroundColor: AppTheme.bg,
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Wallet icon with animated gradient border
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.primary.withValues(alpha: 0.15),
                          AppTheme.gold.withValues(alpha: 0.08),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppTheme.primary.withValues(alpha: 0.3),
                        width: 1.5,
                      ),
                    ),
                    child: const Icon(
                      Icons.account_balance_wallet_outlined,
                      color: AppTheme.primary,
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Connect Your Wallet',
                    style: TextStyle(
                      color: AppTheme.textH,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Sign in with MetaMask to view your saved agents, created agents, and collection progress.',
                    style: TextStyle(
                      color: AppTheme.textM,
                      fontSize: 13,
                      height: 1.6,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),
                  // Feature preview cards
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.card,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Your library includes:',
                          style: TextStyle(
                            color: AppTheme.textH,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _loginFeatureRow(
                          Icons.bookmark_rounded,
                          'Saved Agents',
                          'Agents you bookmarked from the store',
                          AppTheme.gold,
                        ),
                        const SizedBox(height: 10),
                        _loginFeatureRow(
                          Icons.auto_awesome_rounded,
                          'Created Agents',
                          'AI agents you built with unique characters',
                          AppTheme.primary,
                        ),
                        const SizedBox(height: 10),
                        _loginFeatureRow(
                          Icons.emoji_events_rounded,
                          'Collection Progress',
                          'Track your rarity badges and achievements',
                          AppTheme.olive,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Network badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.card,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppTheme.gold,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Monad Testnet',
                        style: TextStyle(
                          color: AppTheme.gold,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 24),
                  // Connect button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: () => context.go('/wallet'),
                      icon: const Icon(Icons.account_balance_wallet_rounded, size: 18),
                      label: const Text(
                        'Connect Wallet',
                        style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
                      ),
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Browse store link
                  TextButton.icon(
                    onPressed: () => context.go('/'),
                    icon: const Icon(Icons.storefront_rounded, size: 16),
                    label: const Text('Browse Store Without Signing In'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.textM,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

  Widget _loginFeatureRow(IconData icon, String title, String subtitle, Color color) =>
    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 16, color: color),
      ),
      const SizedBox(width: 12),
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(
            color: AppTheme.textH,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          )),
          const SizedBox(height: 2),
          Text(subtitle, style: const TextStyle(
            color: AppTheme.textM,
            fontSize: 11,
          )),
        ],
      )),
    ]);
}

// ── Filter Chip ───────────────────────────────────────────────────────────────

class _FilterChip extends StatefulWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_FilterChip> createState() => _FilterChipState();
}

class _FilterChipState extends State<_FilterChip> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? AppTheme.primary.withValues(alpha: 0.15)
                : _hovered
                    ? AppTheme.card2.withValues(alpha: 0.8)
                    : AppTheme.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: widget.isSelected
                  ? AppTheme.primary
                  : _hovered
                      ? AppTheme.border2
                      : AppTheme.border,
            ),
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              color: widget.isSelected
                  ? AppTheme.primary
                  : AppTheme.textB,
              fontSize: 12,
              fontWeight:
                  widget.isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Library Agent Card (with hover remove button) ─────────────────────────────

class _LibraryAgentCard extends StatefulWidget {
  final AgentModel agent;
  final bool isOwned;
  final VoidCallback onLongPress;
  final VoidCallback onRemove;
  final Widget? collectionDots;

  const _LibraryAgentCard({
    required this.agent,
    required this.isOwned,
    required this.onLongPress,
    required this.onRemove,
    this.collectionDots,
  });

  @override
  State<_LibraryAgentCard> createState() => _LibraryAgentCardState();
}

class _LibraryAgentCardState extends State<_LibraryAgentCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onLongPress: widget.onLongPress,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            AgentCard(agent: widget.agent, isOwned: widget.isOwned),
            // Collection dots
            if (widget.collectionDots != null)
              Positioned(
                top: 8,
                right: 8,
                child: widget.collectionDots!,
              ),
            // Remove button on hover
            if (_hovered)
              Positioned(
                top: 8,
                left: 8,
                child: _RemoveButton(onTap: widget.onRemove),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Remove Button ─────────────────────────────────────────────────────────────

class _RemoveButton extends StatefulWidget {
  final VoidCallback onTap;
  const _RemoveButton({required this.onTap});

  @override
  State<_RemoveButton> createState() => _RemoveButtonState();
}

class _RemoveButtonState extends State<_RemoveButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: _hovered
                ? AppTheme.primary
                : AppTheme.surface.withValues(alpha: 0.9),
            shape: BoxShape.circle,
            border: Border.all(
              color: _hovered
                  ? AppTheme.primary
                  : AppTheme.border2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            Icons.bookmark_remove_outlined,
            size: 14,
            color: _hovered ? AppTheme.textH : AppTheme.textM,
          ),
        ),
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

Color _hexToColor(String hex) {
  final h = hex.replaceFirst('#', '');
  if (h.length == 6) return Color(int.parse('FF$h', radix: 16));
  return const Color(0xFF81231E);
}

// ── Collection Dots ──────────────────────────────────────────────────────────

class _CollectionDots extends StatelessWidget {
  final int agentId;
  const _CollectionDots({required this.agentId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<AgentCollection>>(
      future: CollectionService.instance.collectionsForAgent(agentId),
      builder: (context, snapshot) {
        final cols = snapshot.data ?? [];
        if (cols.isEmpty) return const SizedBox.shrink();
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: cols
              .take(3)
              .map((c) => Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(left: 3),
                    decoration: BoxDecoration(
                      color: _hexToColor(c.color),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                            color: _hexToColor(c.color).withValues(alpha: 0.6),
                            blurRadius: 4),
                      ],
                    ),
                  ))
              .toList(),
        );
      },
    );
  }
}

// ── Add to Collection Sheet ───────────────────────────────────────────────────

class _AddToCollectionSheet extends StatefulWidget {
  final AgentModel agent;
  final VoidCallback onChanged;
  const _AddToCollectionSheet(
      {required this.agent, required this.onChanged});
  @override
  State<_AddToCollectionSheet> createState() =>
      _AddToCollectionSheetState();
}

class _AddToCollectionSheetState extends State<_AddToCollectionSheet> {
  List<AgentCollection> _collections = [];
  @override
  void initState() {
    super.initState();
    CollectionService.instance.getAll().then((all) {
      if (mounted) setState(() => _collections = all);
    });
  }

  Future<void> _toggle(AgentCollection col) async {
    final alreadyIn = col.agentIds.contains(widget.agent.id);
    if (alreadyIn) {
      await CollectionService.instance.removeAgent(col.id, widget.agent.id);
    } else {
      await CollectionService.instance.addAgent(col.id, widget.agent.id);
    }
    final updated = await CollectionService.instance.getAll();
    if (mounted) setState(() => _collections = updated);
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.border2,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(children: [
              const Text('Add to collection',
                  style: TextStyle(
                      color: AppTheme.textH,
                      fontSize: 16,
                      fontWeight: FontWeight.w600)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.add,
                    color: AppTheme.primary, size: 20),
                onPressed: () async {
                  Navigator.pop(context);
                  await showDialog<void>(
                    context: context,
                    builder: (_) => _NewCollectionDialog(
                      onCreated: (col) async {
                        await CollectionService.instance
                            .addAgent(col.id, widget.agent.id);
                        widget.onChanged();
                      },
                    ),
                  );
                },
                tooltip: 'New collection',
                constraints: const BoxConstraints(),
                padding: EdgeInsets.zero,
              ),
            ]),
            const SizedBox(height: 4),
            Text(widget.agent.title,
                style:
                    const TextStyle(color: AppTheme.textM, fontSize: 12),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 16),
            if (_collections.isEmpty)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text(
                  'No collections yet. Tap + to create one.',
                  style: TextStyle(color: AppTheme.textM, fontSize: 13),
                ),
              )
            else
              ..._collections.map((col) {
                final isIn = col.agentIds.contains(widget.agent.id);
                final colColor = _hexToColor(col.color);
                return GestureDetector(
                  onTap: () => _toggle(col),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: isIn
                          ? colColor.withValues(alpha: 0.1)
                          : AppTheme.card,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isIn
                            ? colColor
                            : colColor.withValues(alpha: 0.3),
                        width: isIn ? 1.5 : 1,
                      ),
                    ),
                    child: Row(children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                            color: colColor,
                            shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(col.name,
                            style: TextStyle(
                              color: isIn ? colColor : AppTheme.textH,
                              fontWeight: isIn
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                              fontSize: 14,
                            )),
                      ),
                      Text('${col.agentIds.length} agents',
                          style: const TextStyle(
                              color: AppTheme.textM, fontSize: 11)),
                      const SizedBox(width: 8),
                      Icon(
                        isIn
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        color: isIn ? colColor : AppTheme.textM,
                        size: 18,
                      ),
                    ]),
                  ),
                );
              }),
          ],
        ),
      );
}

// ── New Collection Dialog ─────────────────────────────────────────────────────

class _NewCollectionDialog extends StatefulWidget {
  final void Function(AgentCollection) onCreated;
  const _NewCollectionDialog({required this.onCreated});
  @override
  State<_NewCollectionDialog> createState() => _NewCollectionDialogState();
}

class _NewCollectionDialogState extends State<_NewCollectionDialog> {
  final _ctrl = TextEditingController();
  String _selectedColor = CollectionService.colorOptions[0];
  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppTheme.border2),
        ),
        title: const Text('New Collection',
            style: TextStyle(color: AppTheme.textH)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _ctrl,
              autofocus: true,
              style: const TextStyle(color: AppTheme.textH),
              decoration: InputDecoration(
                filled: true,
                fillColor: AppTheme.card,
                hintText: 'Collection name',
                hintStyle: const TextStyle(color: AppTheme.textM),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppTheme.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppTheme.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(
                      color: AppTheme.primary, width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Color',
                style: TextStyle(color: AppTheme.textM, fontSize: 12)),
            const SizedBox(height: 8),
            Row(
              children: CollectionService.colorOptions.map((hex) {
                final isSelected = _selectedColor == hex;
                return GestureDetector(
                  onTap: () =>
                      setState(() => _selectedColor = hex),
                  child: Container(
                    margin: const EdgeInsets.only(right: 10),
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: _hexToColor(hex),
                      shape: BoxShape.circle,
                      border: isSelected
                          ? Border.all(
                              color: AppTheme.textH, width: 2.5)
                          : null,
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                  color: _hexToColor(hex)
                                      .withValues(alpha: 0.6),
                                  blurRadius: 8)
                            ]
                          : null,
                    ),
                    child: isSelected
                        ? const Icon(Icons.check,
                            color: Colors.white, size: 14)
                        : null,
                  ),
                );
              }).toList(),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primary),
            onPressed: () async {
              final name = _ctrl.text.trim();
              if (name.isEmpty) return;
              final col = await CollectionService.instance
                  .create(name, _selectedColor);
              widget.onCreated(col);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Create'),
          ),
        ],
      );
}

// ── Set Price Dialog ──────────────────────────────────────────────────────────

class _SetPriceDialog extends StatefulWidget {
  final int agentId;
  final double currentPrice;
  const _SetPriceDialog(
      {required this.agentId, required this.currentPrice});
  @override
  State<_SetPriceDialog> createState() => _SetPriceDialogState();
}

class _SetPriceDialogState extends State<_SetPriceDialog> {
  late final TextEditingController _ctrl;
  bool _saving = false;
  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(
        text: widget.currentPrice > 0
            ? widget.currentPrice.toStringAsFixed(2)
            : '');
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppTheme.border2),
        ),
        title: const Text('Set Agent Price',
            style: TextStyle(color: AppTheme.textH)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Set a price in MON. Set to 0 to make it free.',
              style: TextStyle(color: AppTheme.textM, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _ctrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: AppTheme.textH),
              decoration: InputDecoration(
                filled: true,
                fillColor: AppTheme.card,
                hintText: '0.00',
                hintStyle: const TextStyle(color: AppTheme.textM),
                suffixText: 'MON',
                suffixStyle: const TextStyle(color: AppTheme.gold),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppTheme.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppTheme.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(
                      color: AppTheme.primary, width: 1.5),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primary),
            onPressed: _saving
                ? null
                : () async {
                    final price =
                        double.tryParse(_ctrl.text) ?? 0.0;
                    setState(() => _saving = true);
                    final ok = await ApiService.instance
                        .setAgentPrice(widget.agentId, price);
                    if (context.mounted) {
                      Navigator.pop(context, ok ? price : null);
                    }
                  },
            child: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Save'),
          ),
        ],
      );
}
