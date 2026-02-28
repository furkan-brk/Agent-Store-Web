import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme.dart';
import '../../../shared/models/agent_model.dart';
import '../../../shared/services/api_service.dart';
import '../../../shared/services/collection_service.dart';
import '../../../shared/services/wallet_service.dart';
import '../../../shared/widgets/achievement_badge.dart';
import '../../store/widgets/agent_card.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});
  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  List<AgentModel> _saved = [];
  List<AgentModel> _created = [];
  int _credits = 0;
  bool _loading = true;

  // Collection state
  List<AgentCollection> _collections = [];
  String? _selectedCollectionId;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _collections = CollectionService.instance.getAll();
    if (ApiService.instance.isAuthenticated) {
      _load();
    } else {
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final wallet = WalletService.instance.connectedWallet ?? '';
    final results = await Future.wait([
      ApiService.instance.getLibrary(),
      ApiService.instance.listAgents(limit: 50),
      ApiService.instance.getCredits(),
    ]);
    final saved = results[0] as List<AgentModel>;
    final allAgents =
        (results[1] as ({List<AgentModel> agents, int total})).agents;
    final credits = results[2] as int;
    final created = wallet.isNotEmpty
        ? allAgents
            .where((a) =>
                a.creatorWallet.toLowerCase() == wallet.toLowerCase())
            .toList()
        : <AgentModel>[];
    if (mounted) {
      setState(() {
        _saved = saved;
        _created = created;
        _credits = credits;
        _loading = false;
        _collections = CollectionService.instance.getAll();
      });
    }
  }

  void _refreshCollections() {
    setState(() {
      _collections = CollectionService.instance.getAll();
      // If selected collection was deleted, reset filter
      if (_selectedCollectionId != null &&
          !_collections.any((c) => c.id == _selectedCollectionId)) {
        _selectedCollectionId = null;
      }
    });
  }

  int get _totalSaves => _created.fold(0, (s, a) => s + a.saveCount);
  int get _totalUses => _created.fold(0, (s, a) => s + a.useCount);

  List<AgentModel> get _filteredSaved {
    if (_selectedCollectionId == null) return _saved;
    final col = _collections.firstWhere(
      (c) => c.id == _selectedCollectionId,
      orElse: () => AgentCollection(
        id: '', name: '', agentIds: [], color: '#6366F1',
        createdAt: DateTime.now(),
      ),
    );
    return _saved.where((a) => col.agentIds.contains(a.id)).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (!ApiService.instance.isAuthenticated) return _loginPrompt(context);
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppTheme.primary,
        child: Column(children: [
          _buildHeader(),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                        color: Color(0xFF81231E)))
                : TabBarView(controller: _tabCtrl, children: [
                    _buildSavedTab(),
                    _buildCreatedTab(),
                  ]),
          ),
        ]),
      ),
    );
  }

  Widget _buildHeader() {
    final wallet = WalletService.instance.connectedWallet ?? '';
    final short = wallet.length > 10
        ? '${wallet.substring(0, 6)}...${wallet.substring(wallet.length - 4)}'
        : wallet;
    return Container(
      color: AppTheme.surface,
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.primary.withValues(alpha: 0.4)),
            ),
            child: const Icon(Icons.person_outline, color: AppTheme.primary, size: 22),
          ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text(short,
                  style: const TextStyle(
                      color: AppTheme.textH, fontSize: 15, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Row(children: [
                _statChip(Icons.bolt, '$_credits', AppTheme.gold, 'credits'),
                const SizedBox(width: 14),
                _statChip(Icons.auto_awesome_outlined, '${_created.length}', AppTheme.primary, 'created'),
                const SizedBox(width: 14),
                _statChip(Icons.bookmark_border, '$_totalSaves', AppTheme.primary, 'saves'),
              ]),
            ]),
          ),
        ]),
        const SizedBox(height: 18),
        TabBar(
          controller: _tabCtrl,
          tabs: [
            Tab(text: 'Saved (${_saved.length})'),
            Tab(text: 'Created (${_created.length})'),
          ],
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.textM,
          indicatorColor: AppTheme.primary,
          dividerColor: AppTheme.border,
        ),
      ]),
    );
  }

  Widget _statChip(
          IconData icon, String value, Color color, String label) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(width: 3),
        Text(value,
            style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 13)),
        const SizedBox(width: 3),
        Text(label,
            style: const TextStyle(color: AppTheme.textM, fontSize: 11)),
      ]);

  // ── Saved Tab ─────────────────────────────────────────────────────────────

  Widget _buildSavedTab() {
    final filtered = _filteredSaved;
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        // Collections section
        SliverToBoxAdapter(child: _buildCollectionsSection()),
        // Empty / Grid
        if (filtered.isEmpty)
          SliverFillRemaining(
            child: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.bookmarks_outlined, color: AppTheme.border2, size: 52),
                const SizedBox(height: 12),
                Text(
                  _selectedCollectionId != null
                      ? 'No agents in this collection'
                      : 'No saved agents yet',
                  style: const TextStyle(color: AppTheme.textB, fontSize: 16),
                ),
                const SizedBox(height: 6),
                Text(
                  _selectedCollectionId != null
                      ? 'Long-press an agent card to add it here'
                      : 'Browse the store and save agents',
                  style: const TextStyle(color: AppTheme.textM, fontSize: 12),
                ),
              ]),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            sliver: SliverGrid(
              delegate: SliverChildBuilderDelegate(
                (context, i) {
                  final a = filtered[i];
                  final wallet = WalletService.instance.connectedWallet;
                  final isOwned = wallet != null &&
                      a.creatorWallet.toLowerCase() ==
                          wallet.toLowerCase();
                  return GestureDetector(
                    onLongPress: () => _showAddToCollectionSheet(a),
                    child: Stack(children: [
                      AgentCard(agent: a, isOwned: isOwned),
                      // Collection indicator dots
                      if (CollectionService.instance
                          .collectionsForAgent(a.id)
                          .isNotEmpty)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: _CollectionDots(agentId: a.id),
                        ),
                    ]),
                  );
                },
                childCount: filtered.length,
              ),
              gridDelegate:
                  const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 300,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.72,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCollectionsSection() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text(
            'Collections',
            style: TextStyle(color: AppTheme.textH, fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.add, color: AppTheme.primary, size: 20),
            onPressed: () => _showNewCollectionDialog(),
            tooltip: 'New collection',
            constraints: const BoxConstraints(),
            padding: EdgeInsets.zero,
          ),
        ]),
        const SizedBox(height: 8),
        if (_collections.isEmpty)
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text(
              'No collections yet. Tap + to create one.',
              style: TextStyle(
                  color: AppTheme.textM, fontSize: 12),
            ),
          )
        else
          SizedBox(
            height: 34,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _collections.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final col = _collections[i];
                final isSelected = _selectedCollectionId == col.id;
                final colColor = _hexToColor(col.color);
                return GestureDetector(
                  onTap: () => setState(() {
                    _selectedCollectionId =
                        isSelected ? null : col.id;
                  }),
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
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        col.name,
                        style: TextStyle(
                          color: isSelected
                              ? colColor
                              : AppTheme.textB,
                          fontSize: 12,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                         '${col.agentIds.length}',
                         style: TextStyle(
                           color: isSelected ? colColor.withValues(alpha: 0.8) : AppTheme.textM,
                           fontSize: 11,
                         ),
                       ),
                      const SizedBox(width: 4),
                      GestureDetector(
                        onTap: () => _confirmDeleteCollection(col),
                        child: Icon(Icons.close, size: 12,
                            color: isSelected ? colColor.withValues(alpha: 0.8) : AppTheme.textM),
                      ),
                    ]),
                  ),
                );
              },
            ),
          ),
        const SizedBox(height: 4),
        const Divider(color: AppTheme.border),
      ]),
    );
  }

  void _showNewCollectionDialog() {
    showDialog<void>(
      context: context,
      builder: (_) => _NewCollectionDialog(
        onCreated: (_) => _refreshCollections(),
      ),
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
          side: const BorderSide(color: AppTheme.border2)),
        title: const Text('Delete Collection', style: TextStyle(color: AppTheme.textH)),
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
            style: FilledButton.styleFrom(backgroundColor: AppTheme.primary),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    ).then((confirmed) {
      if (confirmed == true) {
        CollectionService.instance.delete(col.id);
        _refreshCollections();
      }
    });
  }

  void _showAddToCollectionSheet(AgentModel agent) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.card2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _AddToCollectionSheet(
        agent: agent,
        onChanged: _refreshCollections,
      ),
    );
  }

  // ── Created Tab ───────────────────────────────────────────────────────────

  Widget _buildCreatedTab() {
    final achievements = Achievement.compute(
      agentCount: _created.length,
      totalSaves: _totalSaves,
      totalUses: _totalUses,
      libraryCount: _saved.length,
      credits: _credits,
    );

    if (_created.isEmpty) {
      return CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: AchievementRow(achievements: achievements),
            ),
          ),
          const SliverFillRemaining(
            child: Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.auto_awesome_outlined, color: AppTheme.border2, size: 52),
              const SizedBox(height: 12),
              Text('No agents created yet', style: const TextStyle(color: AppTheme.textB, fontSize: 16)),
              const SizedBox(height: 6),
              Text('Create your first agent', style: const TextStyle(color: AppTheme.textM, fontSize: 12)),
            ])),
          ),
        ],
      );
    }

    final wallet = WalletService.instance.connectedWallet;
    const delegate = SliverGridDelegateWithMaxCrossAxisExtent(
      maxCrossAxisExtent: 300,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 0.72,
    );

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: AchievementRow(achievements: achievements),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          sliver: SliverGrid(
            delegate: SliverChildBuilderDelegate(
              (context, i) {
                final a = _created[i];
                final isOwned = wallet != null &&
                    a.creatorWallet.toLowerCase() ==
                        wallet.toLowerCase();
                final card = AgentCard(agent: a, isOwned: isOwned);
                return Stack(children: [
                  card,
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: () async {
                        final newPrice = await showDialog<double>(
                          context: context,
                          builder: (_) => _SetPriceDialog(
                              agentId: a.id,
                              currentPrice: a.price),
                        );
                        if (newPrice != null && mounted) {
                          setState(() {
                            final idx = _created
                                .indexWhere((x) => x.id == a.id);
                            if (idx != -1) {
                              _created[idx] = AgentModel(
                                id: a.id,
                                title: a.title,
                                description: a.description,
                                prompt: a.prompt,
                                category: a.category,
                                creatorWallet: a.creatorWallet,
                                characterType: a.characterType,
                                subclass: a.subclass,
                                rarity: a.rarity,
                                stats: a.stats,
                                traits: a.traits,
                                tags: a.tags,
                                useCount: a.useCount,
                                saveCount: a.saveCount,
                                generatedImage: a.generatedImage,
                                createdAt: a.createdAt,
                                price: newPrice,
                              );
                            }
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                           color: a.price > 0
                               ? AppTheme.gold.withValues(alpha: 0.85)
                               : AppTheme.card2.withValues(alpha: 0.9),
                           borderRadius: BorderRadius.circular(4),
                         ),
                         child: Text(
                           a.price > 0
                               ? '${a.price.toStringAsFixed(2)} MON'
                               : 'Free',
                           style: const TextStyle(
                               color: Color(0xFF1E1A14),
                               fontSize: 10,
                               fontWeight: FontWeight.w600),
                         ),
                      ),
                    ),
                  ),
                ]);
              },
              childCount: _created.length,
            ),
            gridDelegate: delegate,
          ),
        ),
      ],
    );
  }

  Widget _loginPrompt(BuildContext context) => Scaffold(
        backgroundColor: AppTheme.bg,
        body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.account_balance_wallet_outlined, color: AppTheme.border2, size: 56),
          const SizedBox(height: 16),
          const Text('Connect your wallet', style: TextStyle(
              color: AppTheme.textH, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Sign in to view your library and created agents',
              style: TextStyle(color: AppTheme.textM, fontSize: 13), textAlign: TextAlign.center),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => context.go('/wallet'),
            icon: const Icon(Icons.account_balance_wallet_rounded),
            label: const Text('Connect Wallet'),
          ),
        ])),
      );
}

// ── Helpers ──────────────────────────────────────────────────────────────────

Color _hexToColor(String hex) {
  final h = hex.replaceFirst('#', '');
  if (h.length == 6) {
    return Color(int.parse('FF$h', radix: 16));
  }
  return const Color(0xFF81231E);
}

// ── Collection Dots ──────────────────────────────────────────────────────────

class _CollectionDots extends StatelessWidget {
  final int agentId;
  const _CollectionDots({required this.agentId});

  @override
  Widget build(BuildContext context) {
    final cols = CollectionService.instance.collectionsForAgent(agentId);
    if (cols.isEmpty) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: cols.take(3).map((c) {
        return Container(
          width: 8,
          height: 8,
          margin: const EdgeInsets.only(left: 3),
          decoration: BoxDecoration(
            color: _hexToColor(c.color),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                  color: _hexToColor(c.color).withValues(alpha: 0.6),
                  blurRadius: 4)
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ── Add to Collection Bottom Sheet ───────────────────────────────────────────

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
  late List<AgentCollection> _collections;

  @override
  void initState() {
    super.initState();
    _collections = CollectionService.instance.getAll();
  }

  void _toggle(AgentCollection col) {
    final alreadyIn = col.agentIds.contains(widget.agent.id);
    if (alreadyIn) {
      CollectionService.instance.removeAgent(col.id, widget.agent.id);
    } else {
      CollectionService.instance.addAgent(col.id, widget.agent.id);
    }
    setState(() {
      _collections = CollectionService.instance.getAll();
    });
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Text(
              'Add to collection',
              style: TextStyle(
                  color: Color(0xFF2B2C1E),
                  fontSize: 16,
                  fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.add,
                  color: Color(0xFF81231E), size: 20),
              onPressed: () async {
                Navigator.pop(context);
                await showDialog<void>(
                  context: context,
                  builder: (_) => _NewCollectionDialog(
                    onCreated: (col) {
                      CollectionService.instance
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
          Text(
            widget.agent.title,
           style: const TextStyle(color: AppTheme.textB, fontSize: 12),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
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
                    color: isIn ? colColor.withValues(alpha: 0.1) : AppTheme.card,
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
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        col.name,
                        style: TextStyle(
                           color: isIn ? colColor : AppTheme.textH,
                          fontWeight: isIn
                              ? FontWeight.w600
                              : FontWeight.normal,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    Text(
                      '${col.agentIds.length} agents',
                       style: const TextStyle(color: AppTheme.textM, fontSize: 11),
                    ),
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
}

// ── New Collection Dialog ─────────────────────────────────────────────────────

class _NewCollectionDialog extends StatefulWidget {
  final void Function(AgentCollection) onCreated;
  const _NewCollectionDialog({required this.onCreated});

  @override
  State<_NewCollectionDialog> createState() =>
      _NewCollectionDialogState();
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
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppTheme.border2)),
      title: const Text('New Collection', style: TextStyle(color: AppTheme.textH)),
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
              fillColor: const Color(0xFFC8BA9A),
              hintText: 'Collection name',
              hintStyle:
                  const TextStyle(color: Color(0xFF5A5038)),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide:
                    const BorderSide(color: Color(0xFFC0B490)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide:
                    const BorderSide(color: Color(0xFFC0B490)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide:
                    const BorderSide(color: Color(0xFF81231E)),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Color',
              style: TextStyle(
                  color: Color(0xFF6B5A40), fontSize: 12)),
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
                            color: Colors.white, width: 2.5)
                        : null,
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: _hexToColor(hex)
                                  .withValues(alpha: 0.6),
                              blurRadius: 8,
                            )
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
          child: const Text('Cancel',
              style: TextStyle(color: Color(0xFF6B5A40))),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF81231E)),
          onPressed: () {
            final name = _ctrl.text.trim();
            if (name.isEmpty) return;
            final col = CollectionService.instance
                .create(name, _selectedColor);
            widget.onCreated(col);
            Navigator.pop(context);
          },
          child: const Text('Create'),
        ),
      ],
    );
  }
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
          : '',
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFFB8AA88),
      title: const Text('Set Agent Price',
          style: TextStyle(color: Color(0xFF2B2C1E))),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text(
          'Set a price in MON. Set to 0 to make it free.',
          style:
              TextStyle(color: Color(0xFF6B5A40), fontSize: 13),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _ctrl,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(color: Color(0xFF2B2C1E)),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFFC8BA9A),
            hintText: '0.00',
            hintStyle:
                const TextStyle(color: Color(0xFF5A5038)),
            suffixText: 'MON',
            suffixStyle:
                const TextStyle(color: Color(0xFF9B7B1A)),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide:
                  const BorderSide(color: Color(0xFFC0B490)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide:
                  const BorderSide(color: Color(0xFFC0B490)),
            ),
          ),
        ),
      ]),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel',
              style: TextStyle(color: Color(0xFF6B5A40))),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF81231E)),
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
                      strokeWidth: 2, color: Colors.white))
              : const Text('Save'),
        ),
      ],
    );
  }
}
