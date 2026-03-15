// lib/features/wallet/screens/credit_history_screen.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../shared/services/api_service.dart';
import '../../../app/theme.dart';

class CreditHistoryScreen extends StatelessWidget {
  const CreditHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.put(_CreditHistoryController());
    return Obx(() => Scaffold(
      backgroundColor: AppTheme.bg,
      body: Column(children: [
        // ── Header bar ──────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
          decoration: const BoxDecoration(
            color: AppTheme.surface,
            border: Border(bottom: BorderSide(color: AppTheme.border)),
          ),
          child: Row(children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppTheme.gold.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.history_rounded, color: AppTheme.gold, size: 20),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Credit History',
                style: TextStyle(
                  color: AppTheme.textH,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
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
            // Refresh button
            _HoverIconButton(
              icon: Icons.refresh_rounded,
              tooltip: 'Refresh',
              isLoading: ctrl.isLoading.value,
              onPressed: ctrl.isLoading.value ? null : ctrl.load,
            ),
          ]),
        ),

        // ── Sort controls ───────────────────────────────────────────────
        if (!ctrl.isLoading.value && ctrl.error.value == null && ctrl.transactions.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            color: AppTheme.bg,
            child: Row(children: [
              Text(
                '${ctrl.transactions.length} transactions',
                style: const TextStyle(color: AppTheme.textM, fontSize: 12),
              ),
              const Spacer(),
              _SortToggle(
                ascending: ctrl.sortAscending.value,
                onToggle: ctrl.toggleSort,
              ),
            ]),
          ),

        // ── Content ─────────────────────────────────────────────────────
        if (ctrl.isLoading.value)
          Expanded(child: _buildLoadingSkeleton())
        else if (ctrl.error.value != null)
          Expanded(child: _buildErrorState(ctrl))
        else if (ctrl.transactions.isEmpty)
          Expanded(child: _buildEmptyState())
        else
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              itemCount: ctrl.transactions.length,
              itemBuilder: (_, i) => _TxCard(tx: ctrl.transactions[i]),
            ),
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

  Widget _buildErrorState(_CreditHistoryController ctrl) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.error_outline_rounded,
              color: AppTheme.primary,
              size: 32,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            ctrl.error.value!,
            style: const TextStyle(color: AppTheme.textB, fontSize: 15),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: ctrl.load,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Retry'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.primary,
              side: const BorderSide(color: AppTheme.primary),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppTheme.gold.withValues(alpha: 0.08),
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.gold.withValues(alpha: 0.2)),
            ),
            child: const Icon(
              Icons.receipt_long_outlined,
              color: AppTheme.gold,
              size: 36,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'No transactions yet',
            style: TextStyle(
              color: AppTheme.textH,
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Create or fork an agent to see your credit history here.',
            style: TextStyle(color: AppTheme.textM, fontSize: 13, height: 1.5),
            textAlign: TextAlign.center,
          ),
        ]),
      ),
    );
  }
}

// ── Sort toggle button ──────────────────────────────────────────────────────

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

// ── Hover icon button ───────────────────────────────────────────────────────

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

// ── Local micro-controller ──────────────────────────────────────────────────

class _CreditHistoryController extends GetxController {
  final transactions = <Map<String, dynamic>>[].obs;
  final balance = 0.obs;
  final isLoading = true.obs;
  final error = RxnString();
  final sortAscending = false.obs;

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
      final rawList = List<Map<String, dynamic>>.from(data['transactions'] as List? ?? []);
      transactions.value = rawList;
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

// ── Transaction card ────────────────────────────────────────────────────────

class _TxCard extends StatefulWidget {
  final Map<String, dynamic> tx;
  const _TxCard({required this.tx});

  @override
  State<_TxCard> createState() => _TxCardState();
}

class _TxCardState extends State<_TxCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final type = widget.tx['type'] as String? ?? 'unknown';
    final amount = widget.tx['amount'] as int? ?? 0;
    final agentTitle = widget.tx['agent_title'] as String?;
    final createdAt = widget.tx['created_at'] as String? ?? '';
    final isDeduction = amount < 0;

    final IconData icon;
    final Color iconColor;
    final String label;
    switch (type) {
      case 'create':
        icon = Icons.add_box_outlined;
        iconColor = AppTheme.primary;
        label = 'Agent Created';
      case 'fork':
        icon = Icons.fork_right;
        iconColor = AppTheme.gold;
        label = 'Agent Forked';
      case 'initial':
        icon = Icons.card_giftcard_rounded;
        iconColor = AppTheme.olive;
        label = 'Welcome Bonus';
      case 'topup':
        icon = Icons.add_card_rounded;
        iconColor = AppTheme.olive;
        label = 'Credits Purchased';
      default:
        icon = Icons.bolt_rounded;
        iconColor = AppTheme.textM;
        label = type;
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
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
        child: Row(children: [
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
        ]),
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
