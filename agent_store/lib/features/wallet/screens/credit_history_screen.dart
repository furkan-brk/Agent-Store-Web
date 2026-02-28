import 'package:flutter/material.dart';
import '../../../shared/services/api_service.dart';

class CreditHistoryScreen extends StatefulWidget {
  const CreditHistoryScreen({super.key});
  @override
  State<CreditHistoryScreen> createState() => _CreditHistoryScreenState();
}

class _CreditHistoryScreenState extends State<CreditHistoryScreen> {
  List<Map<String, dynamic>> _transactions = [];
  int _balance = 0;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    final data = await ApiService.instance.getCreditHistory();
    if (data != null) {
      setState(() {
        _transactions = List<Map<String, dynamic>>.from(
            data['transactions'] as List? ?? []);
        _balance = data['balance'] as int? ?? 0;
        _loading = false;
      });
    } else {
      setState(() { _loading = false; _error = 'Failed to load credit history.'; });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF0A0A14),
    body: Column(children: [
      Container(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
        color: const Color(0xFF0F0F1E),
        child: Row(children: [
          const Icon(Icons.history, color: Color(0xFF6366F1), size: 22),
          const SizedBox(width: 10),
          const Text('Credit History',
            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1B4B),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.bolt, color: Color(0xFFFCD34D), size: 16),
              const SizedBox(width: 4),
              Text('$_balance', style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            ]),
          ),
        ]),
      ),
      const Divider(height: 1, color: Color(0xFF1E1E35)),
      if (_loading)
        const Expanded(child: Center(
          child: CircularProgressIndicator(color: Color(0xFF6366F1))))
      else if (_error != null)
        Expanded(child: Center(
          child: Text(_error!, style: const TextStyle(color: Color(0xFFDC2626)))))
      else if (_transactions.isEmpty)
        const Expanded(child: Center(child: Column(
          mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.receipt_long_outlined, color: Color(0xFF374151), size: 56),
            SizedBox(height: 14),
            Text('No transactions yet',
              style: TextStyle(color: Color(0xFF6B7280), fontSize: 15)),
            SizedBox(height: 6),
            Text('Create or fork an agent to see your credit history.',
              style: TextStyle(color: Color(0xFF4B5563), fontSize: 12)),
          ],
        )))
      else
        Expanded(child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _transactions.length,
          itemBuilder: (_, i) => _TxCard(tx: _transactions[i]),
        )),
    ]),
  );
}

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
      case 'create':
        icon = Icons.add_box_outlined;
        iconColor = const Color(0xFF6366F1);
        label = 'Agent Created';
      case 'fork':
        icon = Icons.fork_right;
        iconColor = const Color(0xFF8B5CF6);
        label = 'Agent Forked';
      case 'initial':
        icon = Icons.card_giftcard;
        iconColor = const Color(0xFF16A34A);
        label = 'Welcome Bonus';
      default:
        icon = Icons.bolt;
        iconColor = const Color(0xFF6B7280);
        label = type;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F1E),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF1E1E35)),
      ),
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1), shape: BoxShape.circle),
          child: Icon(icon, color: iconColor, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(
            color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
          if (agentTitle != null && agentTitle.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(agentTitle, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 11),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
          const SizedBox(height: 2),
          Text(_formatDate(createdAt),
            style: const TextStyle(color: Color(0xFF4B5563), fontSize: 11)),
        ])),
        Row(children: [
          const Icon(Icons.bolt, color: Color(0xFFFCD34D), size: 14),
          const SizedBox(width: 2),
          Text(isDeduction ? '$amount' : '+$amount',
            style: TextStyle(
              color: isDeduction ? const Color(0xFFEF4444) : const Color(0xFF22C55E),
              fontWeight: FontWeight.bold, fontSize: 15,
            )),
        ]),
      ]),
    );
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.year}-${_two(dt.month)}-${_two(dt.day)} '
             '${_two(dt.hour)}:${_two(dt.minute)}';
    } catch (_) { return iso; }
  }

  String _two(int n) => n.toString().padLeft(2, '0');
}
