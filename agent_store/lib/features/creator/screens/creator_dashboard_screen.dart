// lib/features/creator/screens/creator_dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme.dart';
import '../../../controllers/creator_controller.dart';
import '../../../shared/models/agent_model.dart';
import '../../../shared/services/api_service.dart';
import '../../../shared/widgets/page_header.dart';
import '../../../shared/widgets/pixel_character_widget.dart';
import '../../../features/character/character_types.dart';

class CreatorDashboardScreen extends StatelessWidget {
  const CreatorDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.isRegistered<CreatorController>()
        ? Get.find<CreatorController>()
        : Get.put(CreatorController(), permanent: true);
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Column(children: [
        _buildHeader(ctrl),
        const Divider(height: 1, color: AppTheme.border),
        if (!ApiService.instance.isAuthenticated)
          _buildUnauthState(context)
        else
          Expanded(child: Obx(() {
            if (ctrl.isLoading.value) return _buildLoadingSkeleton();
            if (ctrl.error.value != null) return _buildErrorState(ctrl);
            return ctrl.agents.isEmpty
                ? _buildEmptyState(context)
                : _buildContent(context, ctrl);
          })),
      ]),
    );
  }

  // -- Header ----------------------------------------------------------------

  Widget _buildHeader(CreatorController ctrl) => Container(
    padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
    decoration: const BoxDecoration(
      color: AppTheme.surface,
      border: Border(bottom: BorderSide(color: AppTheme.border)),
    ),
    child: PageHeader(
      icon: Icons.dashboard_rounded,
      iconColor: AppTheme.gold,
      title: 'Creator Dashboard',
      subtitle: 'Manage your published agents',
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        Obx(() => Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppTheme.card2,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppTheme.border),
          ),
          child: Text(
            '${ctrl.agents.length} agent${ctrl.agents.length == 1 ? '' : 's'}',
            style: const TextStyle(color: AppTheme.textM, fontSize: 12),
          ),
        )),
        const SizedBox(width: 8),
        IconButton(
          onPressed: ctrl.load,
          icon: const Icon(Icons.refresh_rounded, color: AppTheme.textM, size: 18),
          tooltip: 'Refresh',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          splashRadius: 16,
        ),
      ]),
    ),
  );

  // -- Unauthenticated state -------------------------------------------------

  Widget _buildUnauthState(BuildContext context) => Expanded(
    child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 80, height: 80,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppTheme.card2,
          border: Border.all(color: AppTheme.border, width: 2),
        ),
        child: const Icon(
          Icons.account_balance_wallet_outlined,
          color: AppTheme.border2,
          size: 36,
        ),
      ),
      const SizedBox(height: 20),
      const Text(
        'Connect wallet to view your creator stats',
        style: TextStyle(color: AppTheme.textM, fontSize: 15),
      ),
      const SizedBox(height: 24),
      ElevatedButton.icon(
        onPressed: () => context.go('/wallet'),
        icon: const Icon(Icons.account_balance_wallet_outlined, size: 18),
        label: const Text('Connect Wallet'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primary,
          foregroundColor: AppTheme.textH,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    ])),
  );

  // -- Empty state -----------------------------------------------------------

  Widget _buildEmptyState(BuildContext context) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 80, height: 80,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppTheme.card2,
          border: Border.all(color: AppTheme.border, width: 2),
        ),
        child: const Icon(
          Icons.auto_awesome_outlined,
          color: AppTheme.gold,
          size: 36,
        ),
      ),
      const SizedBox(height: 20),
      const Text(
        'No agents created yet',
        style: TextStyle(
          color: AppTheme.textH,
          fontSize: 17,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 8),
      const Text(
        'Create your first AI agent and start building your portfolio.',
        style: TextStyle(color: AppTheme.textM, fontSize: 13),
      ),
      const SizedBox(height: 24),
      ElevatedButton.icon(
        onPressed: () => context.go('/create'),
        icon: const Icon(Icons.add_rounded, size: 18),
        label: const Text('Create Your First Agent'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primary,
          foregroundColor: AppTheme.textH,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    ]),
  );

  // -- Loading skeleton ------------------------------------------------------

  Widget _buildLoadingSkeleton() => SingleChildScrollView(
    padding: const EdgeInsets.all(20),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Stat card skeletons
      LayoutBuilder(builder: (context, constraints) {
        if (constraints.maxWidth < 600) {
          return Wrap(
            spacing: 12, runSpacing: 12,
            children: List.generate(5, (_) => SizedBox(
              width: (constraints.maxWidth - 12) / 2,
              child: const _SkeletonStatCard(),
            )),
          );
        }
        return Row(children: List.generate(5, (i) => Expanded(
          child: Padding(
            padding: EdgeInsets.only(left: i > 0 ? 12 : 0),
            child: const _SkeletonStatCard(),
          ),
        )));
      }),
      const SizedBox(height: 24),
      // Table skeleton
      Container(
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.border),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(children: List.generate(5, (i) => Padding(
          padding: EdgeInsets.only(top: i > 0 ? 12 : 0),
          child: const _SkeletonTableRow(),
        ))),
      ),
    ]),
  );

  // -- Error state -----------------------------------------------------------

  Widget _buildErrorState(CreatorController ctrl) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 64, height: 64,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppTheme.primary.withValues(alpha: 0.12),
        ),
        child: const Icon(Icons.error_outline_rounded, color: AppTheme.primary, size: 32),
      ),
      const SizedBox(height: 16),
      Text(
        ctrl.error.value!,
        style: const TextStyle(color: AppTheme.textB, fontSize: 14),
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 20),
      OutlinedButton.icon(
        onPressed: ctrl.load,
        icon: const Icon(Icons.refresh_rounded, size: 16),
        label: const Text('Retry'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppTheme.textB,
          side: const BorderSide(color: AppTheme.border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    ]),
  );

  // -- Main content ----------------------------------------------------------

  Widget _buildContent(BuildContext context, CreatorController ctrl) =>
    SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _buildStatsRow(ctrl),
        const SizedBox(height: 16),
        // Search bar
        SizedBox(
          height: 40,
          child: TextField(
            onChanged: ctrl.setSearchQuery,
            style: const TextStyle(color: AppTheme.textH, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Search agents by title or description...',
              hintStyle: const TextStyle(color: AppTheme.textM, fontSize: 13),
              prefixIcon: const Icon(Icons.search_rounded, size: 18, color: AppTheme.textM),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14),
              filled: true,
              fillColor: AppTheme.card,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppTheme.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppTheme.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppTheme.gold, width: 1.5),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        _CreatorAgentTable(ctrl: ctrl),
      ]),
    );

  // -- Stats row (responsive) ------------------------------------------------

  Widget _buildStatsRow(CreatorController ctrl) {
    final avgScore = ctrl.agents.isEmpty
        ? 0
        : (ctrl.agents.fold<int>(0, (s, a) => s + a.promptScore) / ctrl.agents.length).round();

    final cards = [
      _StatCard(
        icon: Icons.auto_awesome_rounded,
        value: '${ctrl.agents.length}',
        label: 'Total Agents',
        accentColor: AppTheme.gold,
      ),
      _StatCard(
        icon: Icons.bookmark_rounded,
        value: '${ctrl.totalSaves}',
        label: 'Total Saves',
        accentColor: AppTheme.olive,
      ),
      _StatCard(
        icon: Icons.play_circle_rounded,
        value: '${ctrl.totalUses}',
        label: 'Total Uses',
        accentColor: const Color(0xFF4A8AC0),
      ),
      _StatCard(
        icon: Icons.star_rounded,
        value: '$avgScore',
        label: 'Avg Score',
        accentColor: const Color(0xFFD4A843),
      ),
      _StatCard(
        icon: Icons.monetization_on_rounded,
        value: ctrl.totalRevenue.toStringAsFixed(1),
        label: 'Total Revenue (MON)',
        accentColor: const Color(0xFFD4A843),
      ),
    ];

    return LayoutBuilder(builder: (context, constraints) {
      if (constraints.maxWidth < 600) {
        return Wrap(
          spacing: 12, runSpacing: 12,
          children: cards.map((c) => SizedBox(
            width: (constraints.maxWidth - 12) / 2,
            child: c,
          )).toList(),
        );
      }
      return Row(
        children: cards.asMap().entries.map((e) => Expanded(
          child: Padding(
            padding: EdgeInsets.only(left: e.key > 0 ? 12 : 0),
            child: e.value,
          ),
        )).toList(),
      );
    });
  }
}

// ============================================================================
// _CreatorAgentTable -- Sortable DataTable with hover and management actions
// ============================================================================

class _CreatorAgentTable extends StatefulWidget {
  final CreatorController ctrl;
  const _CreatorAgentTable({required this.ctrl});

  @override
  State<_CreatorAgentTable> createState() => _CreatorAgentTableState();
}

enum _SortColumn { title, category, saves, uses, price, rarity, score }

class _CreatorAgentTableState extends State<_CreatorAgentTable> {
  _SortColumn _sortColumn = _SortColumn.saves;
  bool _sortAscending = false;
  int? _hoveredIndex;

  List<T> _sorted<T>(List<T> items, Comparable Function(T) selector) {
    final sorted = List<T>.from(items);
    sorted.sort((a, b) {
      final cmp = selector(a).compareTo(selector(b));
      return _sortAscending ? cmp : -cmp;
    });
    return sorted;
  }

  void _onSort(_SortColumn col) {
    setState(() {
      if (_sortColumn == col) {
        _sortAscending = !_sortAscending;
      } else {
        _sortColumn = col;
        _sortAscending = false;
      }
    });
  }

  Widget _sortableHeader(String label, _SortColumn col) {
    final isActive = _sortColumn == col;
    return InkWell(
      onTap: () => _onSort(col),
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(
            label,
            style: TextStyle(
              color: isActive ? AppTheme.gold : AppTheme.textM,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            isActive
                ? (_sortAscending ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded)
                : Icons.unfold_more_rounded,
            size: 14,
            color: isActive ? AppTheme.gold : AppTheme.textM.withValues(alpha: 0.5),
          ),
        ]),
      ),
    );
  }

  // -- Management dialogs ----------------------------------------------------

  void _showEditDialog(BuildContext context, AgentModel agent) {
    final titleCtrl = TextEditingController(text: agent.title);
    final descCtrl = TextEditingController(text: agent.description);
    final tags = List<String>.from(agent.tags);
    final tagCtrl = TextEditingController();
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final titleLen = titleCtrl.text.length;
          final descLen = descCtrl.text.length;
          final titleValid = titleLen >= 3 && titleLen <= 80;
          final descValid = descLen >= 10 && descLen <= 500;

          return AlertDialog(
            backgroundColor: AppTheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: AppTheme.border),
            ),
            title: const Row(children: [
              Icon(Icons.edit_outlined, color: AppTheme.gold, size: 20),
              SizedBox(width: 12),
              Text('Edit Agent', style: TextStyle(color: AppTheme.textH, fontSize: 16, fontWeight: FontWeight.w600)),
            ]),
            content: SizedBox(
              width: 500,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Title field
                    const Text('Title', style: TextStyle(color: AppTheme.textB, fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: titleCtrl,
                      maxLength: 80,
                      style: const TextStyle(color: AppTheme.textH, fontSize: 14),
                      decoration: InputDecoration(
                        counterStyle: const TextStyle(color: AppTheme.textM, fontSize: 11),
                        errorText: titleCtrl.text.isNotEmpty && !titleValid
                            ? 'Title must be 3-80 characters'
                            : null,
                      ),
                      onChanged: (_) => setDialogState(() {}),
                    ),
                    const SizedBox(height: 16),

                    // Description field
                    const Text('Description', style: TextStyle(color: AppTheme.textB, fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: descCtrl,
                      maxLines: 4,
                      maxLength: 500,
                      style: const TextStyle(color: AppTheme.textH, fontSize: 14),
                      decoration: InputDecoration(
                        counterStyle: const TextStyle(color: AppTheme.textM, fontSize: 11),
                        errorText: descCtrl.text.isNotEmpty && !descValid
                            ? 'Description must be 10-500 characters'
                            : null,
                      ),
                      onChanged: (_) => setDialogState(() {}),
                    ),
                    const SizedBox(height: 16),

                    // Tags
                    const Text('Tags', style: TextStyle(color: AppTheme.textB, fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 4),
                    Text(
                      '${tags.length}/10 tags',
                      style: const TextStyle(color: AppTheme.textM, fontSize: 11),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        ...tags.map((tag) => Chip(
                          label: Text(tag, style: const TextStyle(color: AppTheme.textH, fontSize: 12)),
                          backgroundColor: AppTheme.card,
                          deleteIcon: const Icon(Icons.close, size: 14, color: AppTheme.textM),
                          onDeleted: () => setDialogState(() => tags.remove(tag)),
                          side: const BorderSide(color: AppTheme.border),
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        )),
                        if (tags.length < 10)
                          SizedBox(
                            width: 140,
                            child: TextField(
                              controller: tagCtrl,
                              style: const TextStyle(color: AppTheme.textH, fontSize: 12),
                              maxLength: 30,
                              decoration: const InputDecoration(
                                hintText: 'Add tag + Enter',
                                hintStyle: TextStyle(color: AppTheme.textM, fontSize: 12),
                                border: InputBorder.none,
                                isDense: true,
                                counterText: '',
                                contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                              ),
                              onSubmitted: (value) {
                                final trimmed = value.trim();
                                if (trimmed.isNotEmpty && tags.length < 10 && !tags.contains(trimmed)) {
                                  setDialogState(() {
                                    tags.add(trimmed);
                                    tagCtrl.clear();
                                  });
                                }
                              },
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: (isSaving || !titleValid || !descValid)
                    ? null
                    : () async {
                        setDialogState(() => isSaving = true);
                        try {
                          await ApiService.instance.updateAgent(
                            agent.id,
                            title: titleCtrl.text.trim(),
                            description: descCtrl.text.trim(),
                            tags: tags,
                          );
                          if (ctx.mounted) Navigator.pop(ctx);
                          widget.ctrl.load();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Agent updated successfully')),
                            );
                          }
                        } catch (e) {
                          setDialogState(() => isSaving = false);
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(content: Text('Error: ${e.toString().replaceFirst('Exception: ', '')}')),
                            );
                          }
                        }
                      },
                child: isSaving
                    ? const SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.textH),
                      )
                    : const Text('Save Changes'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showRegenerateDialog(BuildContext context, AgentModel agent) {
    bool isRegenerating = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppTheme.border),
          ),
          title: const Row(children: [
            Icon(Icons.auto_fix_high_rounded, color: AppTheme.gold, size: 20),
            SizedBox(width: 12),
            Text('Regenerate Avatar', style: TextStyle(color: AppTheme.textH, fontSize: 16, fontWeight: FontWeight.w600)),
          ]),
          content: SizedBox(
            width: 420,
            child: isRegenerating
                ? const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(height: 12),
                      SizedBox(
                        width: 40, height: 40,
                        child: CircularProgressIndicator(strokeWidth: 3, color: AppTheme.gold),
                      ),
                      SizedBox(height: 20),
                      Text(
                        'Generating new avatar...',
                        style: TextStyle(color: AppTheme.textH, fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'This may take 30-60 seconds. Please do not close this dialog.',
                        style: TextStyle(color: AppTheme.textM, fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 12),
                    ],
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Agent preview row
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.card,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: Row(children: [
                          PixelCharacterWidget(
                            characterType: agent.characterType,
                            rarity: agent.rarity,
                            subclass: agent.subclass,
                            size: 40,
                            agentId: agent.id,
                            generatedImage: agent.generatedImage,
                            imageUrl: agent.imageUrl,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              agent.title,
                              style: const TextStyle(color: AppTheme.textH, fontWeight: FontWeight.w500, fontSize: 14),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ]),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'This will create a new pixel-art character image using AI. The current avatar will be replaced.',
                        style: TextStyle(color: AppTheme.textB, fontSize: 13),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.gold.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.gold.withValues(alpha: 0.2)),
                        ),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Icon(Icons.info_outline_rounded, color: AppTheme.gold.withValues(alpha: 0.8), size: 16),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'You can regenerate once every 24 hours.',
                              style: TextStyle(color: AppTheme.textB, fontSize: 12),
                            ),
                          ),
                        ]),
                      ),
                    ],
                  ),
          ),
          actions: isRegenerating
              ? null
              : [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton.icon(
                    onPressed: () async {
                      setDialogState(() => isRegenerating = true);
                      try {
                        await ApiService.instance.regenerateImage(agent.id);
                        if (ctx.mounted) Navigator.pop(ctx);
                        widget.ctrl.load();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Avatar regenerated successfully')),
                          );
                        }
                      } catch (e) {
                        setDialogState(() => isRegenerating = false);
                        final msg = e.toString().replaceFirst('Exception: ', '');
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(content: Text('Error: $msg')),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.auto_fix_high_rounded, size: 16),
                    label: const Text('Regenerate'),
                  ),
                ],
        ),
      ),
    );
  }

  void _showPriceDialog(BuildContext context, AgentModel agent) {
    final priceCtrl = TextEditingController(
      text: agent.price > 0 ? agent.price.toStringAsFixed(2) : '',
    );
    bool isSaving = false;
    String? priceError;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppTheme.border),
          ),
          title: const Row(children: [
            Icon(Icons.monetization_on_outlined, color: AppTheme.gold, size: 20),
            SizedBox(width: 12),
            Text('Set Price', style: TextStyle(color: AppTheme.textH, fontSize: 16, fontWeight: FontWeight.w600)),
          ]),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Current price display
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.card,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Row(children: [
                    const Icon(Icons.sell_outlined, color: AppTheme.textM, size: 16),
                    const SizedBox(width: 8),
                    const Text('Current price: ', style: TextStyle(color: AppTheme.textM, fontSize: 13)),
                    Text(
                      agent.price == 0 ? 'Free' : '${agent.price.toStringAsFixed(2)} MON',
                      style: TextStyle(
                        color: agent.price == 0 ? AppTheme.textM : AppTheme.gold,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 20),

                // Price input
                const Text('New Price', style: TextStyle(color: AppTheme.textB, fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 8),
                TextField(
                  controller: priceCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(color: AppTheme.textH, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: '0.00',
                    suffixText: 'MON',
                    suffixStyle: const TextStyle(color: AppTheme.gold, fontWeight: FontWeight.w600, fontSize: 13),
                    errorText: priceError,
                  ),
                  onChanged: (val) {
                    setDialogState(() {
                      if (val.isEmpty) {
                        priceError = null;
                        return;
                      }
                      final parsed = double.tryParse(val);
                      if (parsed == null) {
                        priceError = 'Enter a valid number';
                      } else if (parsed < 0) {
                        priceError = 'Price cannot be negative';
                      } else {
                        priceError = null;
                      }
                    });
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  'Set to 0 or leave empty to make this agent free.',
                  style: TextStyle(color: AppTheme.textM.withValues(alpha: 0.8), fontSize: 11),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: (isSaving || priceError != null)
                  ? null
                  : () async {
                      final price = double.tryParse(priceCtrl.text) ?? 0.0;
                      setDialogState(() => isSaving = true);
                      try {
                        final ok = await ApiService.instance.setAgentPrice(agent.id, price);
                        if (!ok) throw Exception('Failed to update price');
                        if (ctx.mounted) Navigator.pop(ctx);
                        widget.ctrl.load();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                price == 0
                                    ? 'Agent is now free'
                                    : 'Price set to ${price.toStringAsFixed(2)} MON',
                              ),
                            ),
                          );
                        }
                      } catch (e) {
                        setDialogState(() => isSaving = false);
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(content: Text('Error: ${e.toString().replaceFirst('Exception: ', '')}')),
                          );
                        }
                      }
                    },
              child: isSaving
                  ? const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.textH),
                    )
                  : const Text('Update Price'),
            ),
          ],
        ),
      ),
    );
  }

  // -- Table build -----------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Section header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Row(children: [
            const Icon(Icons.table_chart_outlined, color: AppTheme.gold, size: 16),
            const SizedBox(width: 8),
            const Text(
              'Agent Performance',
              style: TextStyle(
                color: AppTheme.textH,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            const Spacer(),
            Text(
              'Click a row to view details',
              style: TextStyle(
                color: AppTheme.textM.withValues(alpha: 0.6),
                fontSize: 11,
              ),
            ),
          ]),
        ),
        const Divider(height: 1, color: AppTheme.border),

        // Scrollable table
        SizedBox(
          width: double.infinity,
          child: Obx(() {
            final agents = widget.ctrl.filteredAgents;
            final sortedAgents = switch (_sortColumn) {
              _SortColumn.title    => _sorted(agents, (a) => a.title.toLowerCase()),
              _SortColumn.category => _sorted(agents, (a) => a.category.toLowerCase()),
              _SortColumn.saves    => _sorted(agents, (a) => a.saveCount),
              _SortColumn.uses     => _sorted(agents, (a) => a.useCount),
              _SortColumn.price    => _sorted(agents, (a) => a.price),
              _SortColumn.rarity   => _sorted(agents, (a) => a.rarity.index),
              _SortColumn.score    => _sorted(agents, (a) => a.promptScore),
            };

            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(AppTheme.card),
                dataRowColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return AppTheme.primary.withValues(alpha: 0.1);
                  }
                  return Colors.transparent;
                }),
                showCheckboxColumn: false,
                dividerThickness: 0.5,
                columnSpacing: 20,
                horizontalMargin: 16,
                dataRowMinHeight: 56,
                dataRowMaxHeight: 64,
                headingTextStyle: const TextStyle(
                  color: AppTheme.textM,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                ),
                dataTextStyle: const TextStyle(color: AppTheme.textB, fontSize: 13),
                columns: [
                  const DataColumn(label: Text('AVATAR')),
                  DataColumn(label: _sortableHeader('TITLE', _SortColumn.title)),
                  DataColumn(label: _sortableHeader('CATEGORY', _SortColumn.category)),
                  DataColumn(label: _sortableHeader('SCORE', _SortColumn.score), numeric: true),
                  DataColumn(label: _sortableHeader('SAVES', _SortColumn.saves), numeric: true),
                  DataColumn(label: _sortableHeader('USES', _SortColumn.uses), numeric: true),
                  DataColumn(label: _sortableHeader('PRICE', _SortColumn.price), numeric: true),
                  DataColumn(label: _sortableHeader('RARITY', _SortColumn.rarity)),
                  const DataColumn(label: Text('ACTIONS')),
                ],
                rows: sortedAgents.asMap().entries.map((entry) {
                  final i = entry.key;
                  final agent = entry.value;
                  final isHovered = _hoveredIndex == i;

                  return DataRow(
                    color: WidgetStateProperty.resolveWith((states) {
                      if (isHovered) return AppTheme.card2.withValues(alpha: 0.5);
                      if (states.contains(WidgetState.selected)) {
                        return AppTheme.primary.withValues(alpha: 0.1);
                      }
                      // Alternating row tint for readability
                      return i.isEven ? Colors.transparent : AppTheme.card.withValues(alpha: 0.3);
                    }),
                    onSelectChanged: (_) => context.go('/agent/${agent.id}'),
                    cells: [
                      // Avatar
                      DataCell(
                        MouseRegion(
                          onEnter: (_) => setState(() => _hoveredIndex = i),
                          onExit: (_) => setState(() => _hoveredIndex = null),
                          child: SizedBox(
                            width: 48, height: 48,
                            child: Center(
                              child: PixelCharacterWidget(
                                characterType: agent.characterType,
                                rarity: agent.rarity,
                                subclass: agent.subclass,
                                size: 36,
                                agentId: agent.id,
                                generatedImage: agent.generatedImage,
                                imageUrl: agent.imageUrl,
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Title
                      DataCell(
                        MouseRegion(
                          onEnter: (_) => setState(() => _hoveredIndex = i),
                          onExit: (_) => setState(() => _hoveredIndex = null),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 180),
                            child: Text(
                              agent.title,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              style: TextStyle(
                                color: isHovered ? AppTheme.gold : AppTheme.textH,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Category
                      DataCell(
                        MouseRegion(
                          onEnter: (_) => setState(() => _hoveredIndex = i),
                          onExit: (_) => setState(() => _hoveredIndex = null),
                          child: _CategoryChip(category: agent.category),
                        ),
                      ),

                      // Prompt Score
                      DataCell(
                        MouseRegion(
                          onEnter: (_) => setState(() => _hoveredIndex = i),
                          onExit: (_) => setState(() => _hoveredIndex = null),
                          child: _PromptScoreBadge(score: agent.promptScore),
                        ),
                      ),

                      // Saves
                      DataCell(
                        MouseRegion(
                          onEnter: (_) => setState(() => _hoveredIndex = i),
                          onExit: (_) => setState(() => _hoveredIndex = null),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.bookmark_rounded, color: AppTheme.olive.withValues(alpha: 0.8), size: 14),
                            const SizedBox(width: 4),
                            Text('${agent.saveCount}', style: const TextStyle(color: AppTheme.textB)),
                          ]),
                        ),
                      ),

                      // Uses
                      DataCell(
                        MouseRegion(
                          onEnter: (_) => setState(() => _hoveredIndex = i),
                          onExit: (_) => setState(() => _hoveredIndex = null),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.play_circle_rounded, color: Color(0xFF4A8AC0), size: 14),
                            const SizedBox(width: 4),
                            Text('${agent.useCount}', style: const TextStyle(color: AppTheme.textB)),
                          ]),
                        ),
                      ),

                      // Price
                      DataCell(
                        MouseRegion(
                          onEnter: (_) => setState(() => _hoveredIndex = i),
                          onExit: (_) => setState(() => _hoveredIndex = null),
                          child: Text(
                            agent.price == 0 ? 'Free' : '${agent.price.toStringAsFixed(1)} MON',
                            style: TextStyle(
                              color: agent.price == 0 ? AppTheme.textM : AppTheme.gold,
                              fontWeight: agent.price > 0 ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                        ),
                      ),

                      // Rarity
                      DataCell(
                        MouseRegion(
                          onEnter: (_) => setState(() => _hoveredIndex = i),
                          onExit: (_) => setState(() => _hoveredIndex = null),
                          child: _RarityChip(rarity: agent.rarity),
                        ),
                      ),

                      // Actions -- View | Edit | Regenerate | Price
                      DataCell(
                        MouseRegion(
                          onEnter: (_) => setState(() => _hoveredIndex = i),
                          onExit: (_) => setState(() => _hoveredIndex = null),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            _ActionIcon(
                              icon: Icons.visibility_rounded,
                              tooltip: 'View Details',
                              onTap: () => context.go('/agent/${agent.id}'),
                            ),
                            const SizedBox(width: 4),
                            _ActionIcon(
                              icon: Icons.edit_rounded,
                              tooltip: 'Quick Edit (title/desc/tags)',
                              onTap: () => _showEditDialog(context, agent),
                            ),
                            const SizedBox(width: 4),
                            _ActionIcon(
                              icon: Icons.style_outlined,
                              tooltip: 'Manage Card (full editor)',
                              onTap: () => context.go('/agent/${agent.id}/edit'),
                            ),
                            const SizedBox(width: 4),
                            _ActionIcon(
                              icon: Icons.auto_fix_high_rounded,
                              tooltip: 'Regenerate Image',
                              onTap: () => _showRegenerateDialog(context, agent),
                            ),
                            const SizedBox(width: 4),
                            _ActionIcon(
                              icon: Icons.monetization_on_outlined,
                              tooltip: 'Set Price',
                              onTap: () => _showPriceDialog(context, agent),
                            ),
                          ]),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            );
          }),
        ),
      ]),
    );
  }
}

// ============================================================================
// Stat card -- top-level metrics
// ============================================================================

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color accentColor;

  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AppTheme.border),
      boxShadow: [
        BoxShadow(
          color: accentColor.withValues(alpha: 0.08),
          blurRadius: 12,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(
          width: 28, height: 28,
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, color: accentColor, size: 16),
        ),
        const Spacer(),
      ]),
      const SizedBox(height: 12),
      Text(
        value,
        style: const TextStyle(
          color: AppTheme.textH,
          fontWeight: FontWeight.bold,
          fontSize: 24,
        ),
      ),
      const SizedBox(height: 2),
      Text(
        label,
        style: const TextStyle(color: AppTheme.textM, fontSize: 11),
      ),
    ]),
  );
}

// ============================================================================
// Category chip -- dark-themed
// ============================================================================

class _CategoryChip extends StatelessWidget {
  final String category;
  const _CategoryChip({required this.category});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: AppTheme.card2,
      borderRadius: BorderRadius.circular(4),
      border: Border.all(color: AppTheme.border.withValues(alpha: 0.5)),
    ),
    child: Text(
      category.isEmpty ? '--' : category,
      style: const TextStyle(color: AppTheme.textB, fontSize: 11),
    ),
  );
}

// ============================================================================
// Rarity chip -- gradient background
// ============================================================================

class _RarityChip extends StatelessWidget {
  final CharacterRarity rarity;
  const _RarityChip({required this.rarity});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      gradient: LinearGradient(colors: rarity.gradientColors),
      borderRadius: BorderRadius.circular(4),
      border: Border.all(color: rarity.color.withValues(alpha: 0.4)),
    ),
    child: Text(
      rarity.displayName.toUpperCase(),
      style: const TextStyle(
        color: Colors.white,
        fontSize: 9,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
      ),
    ),
  );
}

// ============================================================================
// Prompt score badge -- color-coded quality indicator
// ============================================================================

class _PromptScoreBadge extends StatelessWidget {
  final int score;
  const _PromptScoreBadge({required this.score});

  Color get _color {
    if (score >= 80) return AppTheme.olive;
    if (score >= 60) return AppTheme.gold;
    if (score >= 40) return const Color(0xFFD4843A);
    return AppTheme.primary;
  }

  @override
  Widget build(BuildContext context) => Container(
    width: 36, height: 22,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: _color.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(4),
      border: Border.all(color: _color.withValues(alpha: 0.4)),
    ),
    child: Text(
      '$score',
      style: TextStyle(
        color: _color,
        fontSize: 11,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

// ============================================================================
// Action icon button -- small hover-aware icon
// ============================================================================

class _ActionIcon extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _ActionIcon({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  State<_ActionIcon> createState() => _ActionIconState();
}

class _ActionIconState extends State<_ActionIcon> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: widget.tooltip,
    child: MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 28, height: 28,
          decoration: BoxDecoration(
            color: _hovered ? AppTheme.card2 : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: _hovered ? AppTheme.border2 : Colors.transparent,
            ),
          ),
          child: Icon(
            widget.icon,
            size: 15,
            color: _hovered ? AppTheme.textH : AppTheme.textM,
          ),
        ),
      ),
    ),
  );
}

// ============================================================================
// Skeleton widgets for loading state
// ============================================================================

class _SkeletonStatCard extends StatelessWidget {
  const _SkeletonStatCard();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AppTheme.border),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        width: 28, height: 28,
        decoration: BoxDecoration(
          color: AppTheme.card2,
          borderRadius: BorderRadius.circular(6),
        ),
      ),
      const SizedBox(height: 12),
      Container(
        width: 48, height: 24,
        decoration: BoxDecoration(
          color: AppTheme.card2,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
      const SizedBox(height: 6),
      Container(
        width: 72, height: 10,
        decoration: BoxDecoration(
          color: AppTheme.card2,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    ]),
  );
}

class _SkeletonTableRow extends StatelessWidget {
  const _SkeletonTableRow();

  @override
  Widget build(BuildContext context) => Row(children: [
    // Avatar placeholder
    Container(
      width: 40, height: 40,
      decoration: BoxDecoration(
        color: AppTheme.card2,
        borderRadius: BorderRadius.circular(4),
      ),
    ),
    const SizedBox(width: 16),
    // Title placeholder
    Expanded(
      flex: 3,
      child: Container(
        height: 12,
        decoration: BoxDecoration(
          color: AppTheme.card2,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    ),
    const SizedBox(width: 16),
    // Category placeholder
    Expanded(
      flex: 2,
      child: Container(
        height: 12,
        decoration: BoxDecoration(
          color: AppTheme.card2,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    ),
    const SizedBox(width: 16),
    // Stats placeholder
    Expanded(
      child: Container(
        height: 12,
        decoration: BoxDecoration(
          color: AppTheme.card2,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    ),
  ]);
}
