// lib/features/wallet/screens/credit_history_screen.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../shared/services/api_service.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/page_header.dart';
import '../../../app/theme.dart';

class CreditHistoryScreen extends StatelessWidget {
  const CreditHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.isRegistered<_CreditHistoryController>()
        ? Get.find<_CreditHistoryController>()
        : Get.put(_CreditHistoryController());
    return Obx(() => Scaffold(
      backgroundColor: AppTheme.bg,
      body: Column(children: [
        // -- Header bar with PageHeader + balance badge + refresh --------
        Container(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
          decoration: const BoxDecoration(
            color: AppTheme.surface,
            border: Border(bottom: BorderSide(color: AppTheme.border)),
          ),
          child: PageHeader(
            icon: Icons.receipt_long_rounded,
            iconColor: AppTheme.gold,
            title: 'Credit History',
            subtitle: 'Track your credit transactions',
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              // Balance badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.card,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.gold.withValues(alpha: 0.3)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.bolt_rounded, color: AppTheme.gold, size: 18),
                  const SizedBox(width: 4),
                  Text(
                    '${ctrl.balance.value}',
                    style: const TextStyle(
                      color: AppTheme.textH,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    'credits',
                    style: TextStyle(color: AppTheme.textM, fontSize: 12),
                  ),
                ]),
              ),
              const SizedBox(width: 8),
              _HoverIconButton(
                icon: Icons.refresh_rounded,
                tooltip: 'Refresh',
                isLoading: ctrl.isLoading.value,
                onPressed: ctrl.isLoading.value ? null : ctrl.load,
              ),
            ]),
          ),
        ),

        // -- Filter bar (search + type dropdown + date chips) -----------
        if (!ctrl.isLoading.value && ctrl.error.value == null)
          _FilterBar(ctrl: ctrl),

        // -- Content ----------------------------------------------------
        if (ctrl.isLoading.value)
          Expanded(child: _buildLoadingSkeleton())
        else if (ctrl.error.value != null)
          Expanded(child: ErrorState(
            message: ctrl.error.value!,
            onRetry: ctrl.load,
          ))
        else if (ctrl.filteredTransactions.isEmpty)
          Expanded(child: ctrl.hasActiveFilters
            ? Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.filter_list_off_rounded, size: 48,
                    color: AppTheme.textM.withValues(alpha: 0.5)),
                  const SizedBox(height: 12),
                  const Text('No matching transactions',
                    style: TextStyle(color: AppTheme.textM, fontSize: 14)),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: ctrl.clearFilters,
                    icon: const Icon(Icons.clear_all_rounded, size: 16),
                    label: const Text('Clear Filters'),
                  ),
                ]),
              )
            : const EmptyState(
                icon: Icons.receipt_long_outlined,
                title: 'No transactions yet',
                subtitle: 'Create or fork an agent to see your credit history here.',
              ),
          )
        else
          // Sort controls row
          Expanded(
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
                child: Row(children: [
                  Text(
                    '${ctrl.filteredTransactions.length} transaction${ctrl.filteredTransactions.length == 1 ? '' : 's'}',
                    style: const TextStyle(color: AppTheme.textM, fontSize: 12),
                  ),
                  const Spacer(),
                  _SortToggle(
                    ascending: ctrl.sortAscending.value,
                    onToggle: ctrl.toggleSort,
                  ),
                ]),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
                  itemCount: ctrl.filteredTransactions.length,
                  itemBuilder: (_, i) => _TxCard(tx: ctrl.filteredTransactions[i]),
                ),
              ),
            ]),
          ),
      ]),
    ));
  }

  Widget _buildLoadingSkeleton() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      itemCount: 6,
      itemBuilder: (_, __) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: AppTheme.card2,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 100,
                  height: 12,
                  decoration: BoxDecoration(
                    color: AppTheme.card2,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  width: 160,
                  height: 10,
                  decoration: BoxDecoration(
                    color: AppTheme.card2,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 50,
            height: 14,
            decoration: BoxDecoration(
              color: AppTheme.card2,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ]),
      ),
    );
  }
}

// -- Filter bar with search, type dropdown, date chips ----------------------

class _FilterBar extends StatelessWidget {
  final _CreditHistoryController ctrl;
  const _FilterBar({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search + type dropdown row
          Row(children: [
            // Search field
            Expanded(
              child: SizedBox(
                height: 38,
                child: TextField(
                  onChanged: ctrl.setSearchQuery,
                  style: const TextStyle(color: AppTheme.textH, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Search by agent name...',
                    hintStyle: const TextStyle(color: AppTheme.textM, fontSize: 13),
                    prefixIcon: const Icon(Icons.search_rounded, size: 18, color: AppTheme.textM),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    filled: true,
                    fillColor: AppTheme.card,
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
                      borderSide: const BorderSide(color: AppTheme.gold, width: 1.5),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Type dropdown
            Obx(() => Container(
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: AppTheme.card,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.border),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: ctrl.typeFilter.value,
                  dropdownColor: AppTheme.card2,
                  style: const TextStyle(color: AppTheme.textH, fontSize: 13),
                  icon: const Icon(Icons.arrow_drop_down_rounded, color: AppTheme.textM, size: 20),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All Types')),
                    // New v3.7-8.1 action_type values (ledger)
                    DropdownMenuItem(value: 'create_agent', child: Text('Create Agent')),
                    DropdownMenuItem(value: 'regen_image', child: Text('Regen Image')),
                    DropdownMenuItem(value: 'legend_run_node', child: Text('Legend Run')),
                    DropdownMenuItem(value: 'purchase', child: Text('Purchase')),
                    DropdownMenuItem(value: 'topup', child: Text('Topup')),
                    DropdownMenuItem(value: 'dev_grant', child: Text('Dev Grant')),
                    // Legacy `type` values (preserved so older rows still filter)
                    DropdownMenuItem(value: 'create', child: Text('Create (legacy)')),
                    DropdownMenuItem(value: 'fork', child: Text('Fork (legacy)')),
                    DropdownMenuItem(value: 'initial', child: Text('Initial (legacy)')),
                  ],
                  onChanged: (v) => ctrl.setTypeFilter(v ?? 'all'),
                ),
              ),
            )),
          ]),
          const SizedBox(height: 10),
          // Date filter chips
          Obx(() => Row(children: [
            _DateChip(
              label: '7 days',
              isSelected: ctrl.dateFilter.value == 7,
              onTap: () => ctrl.setDateFilter(ctrl.dateFilter.value == 7 ? 0 : 7),
            ),
            const SizedBox(width: 8),
            _DateChip(
              label: '30 days',
              isSelected: ctrl.dateFilter.value == 30,
              onTap: () => ctrl.setDateFilter(ctrl.dateFilter.value == 30 ? 0 : 30),
            ),
            const SizedBox(width: 8),
            _DateChip(
              label: 'All time',
              isSelected: ctrl.dateFilter.value == 0,
              onTap: () => ctrl.setDateFilter(0),
            ),
            if (ctrl.hasActiveFilters) ...[
              const Spacer(),
              TextButton.icon(
                onPressed: ctrl.clearFilters,
                icon: const Icon(Icons.clear_all_rounded, size: 14),
                label: const Text('Clear', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.textM,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ])),
        ],
      ),
    );
  }
}

// -- Date chip for filter bar -----------------------------------------------

class _DateChip extends StatefulWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  const _DateChip({required this.label, required this.isSelected, required this.onTap});

  @override
  State<_DateChip> createState() => _DateChipState();
}

class _DateChipState extends State<_DateChip> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? AppTheme.gold.withValues(alpha: 0.15)
                : (_hovered ? AppTheme.card2 : AppTheme.card),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: widget.isSelected
                  ? AppTheme.gold.withValues(alpha: 0.5)
                  : (_hovered ? AppTheme.border2 : AppTheme.border),
            ),
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              color: widget.isSelected ? AppTheme.gold : AppTheme.textM,
              fontSize: 12,
              fontWeight: widget.isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}

// -- Sort toggle button -----------------------------------------------------

class _SortToggle extends StatefulWidget {
  final bool ascending;
  final VoidCallback onToggle;
  const _SortToggle({required this.ascending, required this.onToggle});

  @override
  State<_SortToggle> createState() => _SortToggleState();
}

class _SortToggleState extends State<_SortToggle> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onToggle,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: _hovered ? AppTheme.card2 : AppTheme.card,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: _hovered ? AppTheme.border2 : AppTheme.border),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(
              widget.ascending ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
              size: 13,
              color: AppTheme.textM,
            ),
            const SizedBox(width: 4),
            Text(
              widget.ascending ? 'Oldest first' : 'Newest first',
              style: const TextStyle(color: AppTheme.textM, fontSize: 11),
            ),
          ]),
        ),
      ),
    );
  }
}

// -- Hover icon button ------------------------------------------------------

class _HoverIconButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final bool isLoading;
  final VoidCallback? onPressed;
  const _HoverIconButton({
    required this.icon,
    required this.tooltip,
    this.isLoading = false,
    this.onPressed,
  });

  @override
  State<_HoverIconButton> createState() => _HoverIconButtonState();
}

class _HoverIconButtonState extends State<_HoverIconButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Tooltip(
        message: widget.tooltip,
        child: GestureDetector(
          onTap: widget.onPressed,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _hovered ? AppTheme.card2 : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: widget.isLoading
                ? const Center(
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.gold),
                    ),
                  )
                : Icon(widget.icon, color: AppTheme.textM, size: 18),
          ),
        ),
      ),
    );
  }
}

// -- Local micro-controller with filter support -----------------------------

/// v3.7-8.1: prefers the new structured `entries` field (CreditLedgerEntry rows
/// with action_type / node_ref / cost_breakdown). Falls back to the legacy
/// `transactions` field when the server is older or migration hasn't run.
/// _TxCard reads action_type-aware fields so both shapes render uniformly.
class _CreditHistoryController extends GetxController {
  final transactions = <Map<String, dynamic>>[].obs;
  final balance = 0.obs;
  final isLoading = true.obs;
  final error = RxnString();
  final sortAscending = false.obs;

  // Filter state
  final searchQuery = ''.obs;
  final typeFilter = 'all'.obs;
  final dateFilter = 0.obs; // 0 = all, 7 = 7 days, 30 = 30 days

  bool get hasActiveFilters =>
      searchQuery.value.isNotEmpty ||
      typeFilter.value != 'all' ||
      dateFilter.value != 0;

  List<Map<String, dynamic>> get filteredTransactions {
    var result = transactions.toList();

    // Search by agent_title or action_type
    if (searchQuery.value.isNotEmpty) {
      final q = searchQuery.value.toLowerCase();
      result = result.where((tx) {
        final title = (tx['agent_title'] as String? ?? '').toLowerCase();
        final action = (tx['action_type'] as String? ?? '').toLowerCase();
        final node = (tx['node_ref'] as String? ?? '').toLowerCase();
        return title.contains(q) || action.contains(q) || node.contains(q);
      }).toList();
    }

    // Filter by type / action_type (ledger entries use action_type, legacy
    // entries use type — _TxCard normalises but the filter must match both)
    if (typeFilter.value != 'all') {
      result = result.where((tx) {
        final action = tx['action_type'] as String? ?? tx['type'] as String? ?? '';
        return action == typeFilter.value;
      }).toList();
    }

    // Filter by date
    if (dateFilter.value > 0) {
      final cutoff = DateTime.now().subtract(Duration(days: dateFilter.value));
      result = result.where((tx) {
        try {
          final dt = DateTime.parse(tx['created_at'] as String? ?? '');
          return dt.isAfter(cutoff);
        } catch (_) {
          return true;
        }
      }).toList();
    }

    return result;
  }

  void setSearchQuery(String q) => searchQuery.value = q;
  void setTypeFilter(String t) => typeFilter.value = t;
  void setDateFilter(int days) => dateFilter.value = days;
  void clearFilters() {
    searchQuery.value = '';
    typeFilter.value = 'all';
    dateFilter.value = 0;
  }

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    isLoading.value = true;
    error.value = null;
    final data = await ApiService.instance.getCreditHistory();
    if (data != null) {
      // Prefer the structured ledger; fall back to legacy `transactions` when
      // the server response predates v3.7-8.1.
      final entries = data['entries'] as List?;
      final legacy = data['transactions'] as List?;
      final source = entries != null && entries.isNotEmpty ? entries : legacy;
      transactions.value = List<Map<String, dynamic>>.from(source ?? const []);
      balance.value = data['balance'] as int? ?? 0;
      _applySort();
    } else {
      error.value = 'Failed to load credit history.';
    }
    isLoading.value = false;
  }

  void toggleSort() {
    sortAscending.value = !sortAscending.value;
    _applySort();
  }

  void _applySort() {
    final sorted = transactions.toList();
    sorted.sort((a, b) {
      final dateA = a['created_at'] as String? ?? '';
      final dateB = b['created_at'] as String? ?? '';
      return sortAscending.value ? dateA.compareTo(dateB) : dateB.compareTo(dateA);
    });
    transactions.value = sorted;
  }
}

// -- Transaction card -------------------------------------------------------

class _TxCard extends StatefulWidget {
  final Map<String, dynamic> tx;
  const _TxCard({required this.tx});

  @override
  State<_TxCard> createState() => _TxCardState();
}

class _TxCardState extends State<_TxCard> {
  bool _hovered = false;
  bool _expanded = false;

  /// Maps both new (action_type) and legacy (type) values to a display
  /// label + icon + colour. Falls back to a humanised version of the raw
  /// string so future server-side action types still render reasonably.
  ({IconData icon, Color color, String label}) _classifyAction(String action) {
    switch (action) {
      // v3.7-8.1 action_type values
      case 'create_agent':
        return (icon: Icons.add_box_outlined, color: AppTheme.primary, label: 'Agent Created');
      case 'regen_image':
        return (icon: Icons.image_outlined, color: AppTheme.gold, label: 'Image Regenerated');
      case 'legend_run_node':
        return (icon: Icons.account_tree_outlined, color: AppTheme.gold, label: 'Legend Node Run');
      case 'purchase':
        return (icon: Icons.shopping_bag_outlined, color: AppTheme.primary, label: 'Agent Purchased');
      case 'dev_grant':
        return (icon: Icons.science_outlined, color: AppTheme.olive, label: 'Dev Grant');
      // Legacy `type` values
      case 'create':
        return (icon: Icons.add_box_outlined, color: AppTheme.primary, label: 'Agent Created');
      case 'fork':
        return (icon: Icons.fork_right, color: AppTheme.gold, label: 'Agent Forked');
      case 'initial':
        return (icon: Icons.card_giftcard_rounded, color: AppTheme.olive, label: 'Welcome Bonus');
      case 'topup':
        return (icon: Icons.add_card_rounded, color: AppTheme.olive, label: 'Credits Purchased');
      default:
        // Humanise unknown action keys (e.g. "future_thing" -> "Future Thing")
        final words = action.split('_').where((w) => w.isNotEmpty).map(
              (w) => w[0].toUpperCase() + w.substring(1),
            );
        return (
          icon: Icons.bolt_rounded,
          color: AppTheme.textM,
          label: words.isEmpty ? action : words.join(' '),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Prefer action_type (ledger), fall back to type (legacy).
    final action = (widget.tx['action_type'] as String?) ??
        (widget.tx['type'] as String? ?? 'unknown');
    // Ledger uses `delta` (signed), legacy uses `amount`.
    final amount = (widget.tx['delta'] as int?) ??
        (widget.tx['amount'] as int? ?? 0);
    final agentTitle = widget.tx['agent_title'] as String?;
    final nodeRef = widget.tx['node_ref'] as String?;
    final breakdownRaw = widget.tx['cost_breakdown'];
    Map<String, dynamic>? breakdown;
    if (breakdownRaw is Map) {
      breakdown = Map<String, dynamic>.from(breakdownRaw);
    } else if (breakdownRaw is String && breakdownRaw.isNotEmpty) {
      // Server may serialise jsonb as a string when the driver doesn't decode.
      try {
        final parsed = breakdownRaw.startsWith('{')
            ? Map<String, dynamic>.from({})
            : null;
        breakdown = parsed;
      } catch (_) {}
    }
    final hasDetail = (nodeRef != null && nodeRef.isNotEmpty) ||
        (breakdown != null && breakdown.isNotEmpty);
    final createdAt = widget.tx['created_at'] as String? ?? '';
    final isDeduction = amount < 0;

    final cls = _classifyAction(action);
    final icon = cls.icon;
    final iconColor = cls.color;
    final label = cls.label;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: hasDetail
            ? () => setState(() => _expanded = !_expanded)
            : null,
        child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _hovered ? AppTheme.card2 : AppTheme.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _hovered ? AppTheme.border2 : AppTheme.border,
          ),
        ),
        child: Column(children: [
          Row(children: [
          // Icon circle
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(
                color: iconColor.withValues(alpha: 0.25),
              ),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 14),
          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: AppTheme.textH,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                if (agentTitle != null && agentTitle.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    agentTitle,
                    style: const TextStyle(color: AppTheme.textM, fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 3),
                Row(children: [
                  const Icon(Icons.schedule_rounded, size: 11, color: AppTheme.textM),
                  const SizedBox(width: 4),
                  Text(
                    _formatDate(createdAt),
                    style: const TextStyle(color: AppTheme.textM, fontSize: 11),
                  ),
                ]),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Amount badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: isDeduction
                  ? AppTheme.primary.withValues(alpha: 0.1)
                  : AppTheme.olive.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isDeduction
                    ? AppTheme.primary.withValues(alpha: 0.3)
                    : AppTheme.olive.withValues(alpha: 0.3),
              ),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(
                Icons.bolt_rounded,
                color: isDeduction ? AppTheme.primary : AppTheme.olive,
                size: 14,
              ),
              const SizedBox(width: 2),
              Text(
                isDeduction ? '$amount' : '+$amount',
                style: TextStyle(
                  color: isDeduction ? AppTheme.primary : AppTheme.olive,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ]),
          ),
          if (hasDetail) ...[
            const SizedBox(width: 6),
            Icon(
              _expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
              size: 18,
              color: AppTheme.textM,
            ),
          ],
          ]),
          // ── Expanded detail: node_ref + cost_breakdown ───────────────
          if (_expanded && hasDetail) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.bg.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (nodeRef != null && nodeRef.isNotEmpty) ...[
                    Row(children: [
                      const Icon(Icons.link_rounded, size: 13, color: AppTheme.textM),
                      const SizedBox(width: 6),
                      const Text('Node:',
                          style: TextStyle(color: AppTheme.textM, fontSize: 11)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: SelectableText(
                          nodeRef,
                          style: const TextStyle(
                            color: AppTheme.textB,
                            fontSize: 11,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ]),
                  ],
                  if (breakdown != null && breakdown.isNotEmpty) ...[
                    if (nodeRef != null && nodeRef.isNotEmpty)
                      const SizedBox(height: 8),
                    const Text('Breakdown',
                        style: TextStyle(
                            color: AppTheme.textM,
                            fontSize: 11,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    ...breakdown.entries.map((e) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 1),
                          child: Row(children: [
                            Text('${e.key}:',
                                style: const TextStyle(
                                    color: AppTheme.textM, fontSize: 11)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                '${e.value}',
                                style: const TextStyle(
                                    color: AppTheme.textB, fontSize: 11),
                              ),
                            ),
                          ]),
                        )),
                  ],
                ],
              ),
            ),
          ],
        ]),
      ),
      ),
    );
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.year}-${_two(dt.month)}-${_two(dt.day)} ${_two(dt.hour)}:${_two(dt.minute)}';
    } catch (_) {
      return iso;
    }
  }

  String _two(int n) => n.toString().padLeft(2, '0');
}
