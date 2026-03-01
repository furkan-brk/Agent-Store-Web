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
      backgroundColor: const Color(0xFFDDD1BB),
      body: Column(children: [
        Container(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
          color: const Color(0xFFC8BA9A),
          child: Row(children: [
            const Icon(Icons.history, color: Color(0xFF81231E), size: 22),
            const SizedBox(width: 10),
            const Text('Credit History', style: TextStyle(color: AppTheme.textH, fontSize: 20, fontWeight: FontWeight.bold)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: const Color(0xFFE8DEC9), borderRadius: BorderRadius.circular(8)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.bolt, color: Color(0xFF9B7B1A), size: 16),
                const SizedBox(width: 4),
                Text('${ctrl.balance.value}', style: const TextStyle(color: AppTheme.textH, fontWeight: FontWeight.bold, fontSize: 16)),
              ]),
            ),
          ]),
        ),
        const Divider(height: 1, color: Color(0xFFADA07A)),
        if (ctrl.isLoading.value)
          const Expanded(child: Center(child: CircularProgressIndicator(color: Color(0xFF81231E))))
        else if (ctrl.error.value != null)
          Expanded(child: Center(child: Text(ctrl.error.value!, style: const TextStyle(color: Color(0xFF81231E)))))
        else if (ctrl.transactions.isEmpty)
          const Expanded(child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.receipt_long_outlined, color: Color(0xFFC0B490), size: 56),
            SizedBox(height: 14),
            Text('No transactions yet', style: TextStyle(color: Color(0xFF7A6E52), fontSize: 15)),
            SizedBox(height: 6),
            Text('Create or fork an agent to see your credit history.', style: TextStyle(color: Color(0xFF5A5038), fontSize: 12)),
          ])))
        else
          Expanded(child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: ctrl.transactions.length,
            itemBuilder: (_, i) => _TxCard(tx: ctrl.transactions[i]),
          )),
      ]),
    ));
  }
}

// ── Local micro-controller ────────────────────────────────────────────────────

class _CreditHistoryController extends GetxController {
  final transactions = <Map<String, dynamic>>[].obs;
  final balance = 0.obs;
  final isLoading = true.obs;
  final error = RxnString();

  @override
  void onInit() { super.onInit(); load(); }

  Future<void> load() async {
    isLoading.value = true;
    error.value = null;
    final data = await ApiService.instance.getCreditHistory();
    if (data != null) {
      transactions.value = List<Map<String, dynamic>>.from(data['transactions'] as List? ?? []);
      balance.value = data['balance'] as int? ?? 0;
    } else {
      error.value = 'Failed to load credit history.';
    }
    isLoading.value = false;
  }
}

// ── Transaction card ──────────────────────────────────────────────────────────

class _TxCard extends StatelessWidget {
  final Map<String, dynamic> tx;
  const _TxCard({required this.tx});

  @override
  Widget build(BuildContext context) {
    final type = tx['type'] as String? ?? 'unknown';
    final amount = tx['amount'] as int? ?? 0;
    final agentTitle = tx['agent_title'] as String?;
    final createdAt = tx['created_at'] as String? ?? '';
    final isDeduction = amount < 0;

    final IconData icon;
    final Color iconColor;
    final String label;
    switch (type) {
      case 'create':  icon = Icons.add_box_outlined; iconColor = const Color(0xFF81231E); label = 'Agent Created';
      case 'fork':    icon = Icons.fork_right; iconColor = const Color(0xFF9B7B1A); label = 'Agent Forked';
      case 'initial': icon = Icons.card_giftcard; iconColor = const Color(0xFF5A8A48); label = 'Welcome Bonus';
      default:        icon = Icons.bolt; iconColor = const Color(0xFF7A6E52); label = type;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: const Color(0xFFC8BA9A), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFADA07A))),
      child: Row(children: [
        Container(width: 40, height: 40, decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.1), shape: BoxShape.circle), child: Icon(icon, color: iconColor, size: 18)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(color: AppTheme.textH, fontWeight: FontWeight.w600, fontSize: 13)),
          if (agentTitle != null && agentTitle.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(agentTitle, style: const TextStyle(color: Color(0xFF7A6E52), fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
          const SizedBox(height: 2),
          Text(_formatDate(createdAt), style: const TextStyle(color: Color(0xFF5A5038), fontSize: 11)),
        ])),
        Row(children: [
          const Icon(Icons.bolt, color: Color(0xFF9B7B1A), size: 14),
          const SizedBox(width: 2),
          Text(isDeduction ? '$amount' : '+$amount', style: TextStyle(color: isDeduction ? const Color(0xFF81231E) : const Color(0xFF5A8A48), fontWeight: FontWeight.bold, fontSize: 15)),
        ]),
      ]),
    );
  }

  String _formatDate(String iso) {
    try { final dt = DateTime.parse(iso).toLocal(); return '${dt.year}-${_two(dt.month)}-${_two(dt.day)} ${_two(dt.hour)}:${_two(dt.minute)}'; }
    catch (_) { return iso; }
  }
  String _two(int n) => n.toString().padLeft(2, '0');
}
