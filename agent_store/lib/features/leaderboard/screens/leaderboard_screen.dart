import 'package:flutter/material.dart';
import '../../../shared/services/api_service.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});
  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  List<Map<String, dynamic>> _rankings = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    final data = await ApiService.instance.getLeaderboard();
    if (data != null) {
      setState(() {
        _rankings = List<Map<String, dynamic>>.from(
            data['rankings'] as List? ?? []);
        _loading = false;
      });
    } else {
      setState(() { _loading = false; _error = 'Failed to load leaderboard.'; });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFDDD1BB),
    body: Column(children: [
      Container(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
        color: const Color(0xFFC8BA9A),
        child: const Row(children: [
          Icon(Icons.emoji_events_outlined, color: Color(0xFF9B7B1A), size: 22),
          SizedBox(width: 10),
          Text('Leaderboard',
            style: TextStyle(color: Color(0xFF2B2C1E), fontSize: 20, fontWeight: FontWeight.bold)),
          Spacer(),
          Text('Top Creators', style: TextStyle(color: Color(0xFF7A6E52), fontSize: 12)),
        ]),
      ),
      const Divider(height: 1, color: Color(0xFFADA07A)),
      if (_loading)
        const Expanded(child: Center(
          child: CircularProgressIndicator(color: Color(0xFF81231E))))
      else if (_error != null)
        Expanded(child: Center(
          child: Text(_error!, style: const TextStyle(color: Color(0xFFCAB891)))))
      else if (_rankings.isEmpty)
        const Expanded(child: Center(child: Column(
          mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.emoji_events_outlined, color: Color(0xFFC0B490), size: 56),
            SizedBox(height: 14),
            Text('No creators yet',
              style: TextStyle(color: Color(0xFF7A6E52), fontSize: 15)),
          ],
        )))
      else
        Expanded(child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _rankings.length,
          itemBuilder: (_, i) => _RankCard(entry: _rankings[i]),
        )),
    ]),
  );
}

class _RankCard extends StatelessWidget {
  final Map<String, dynamic> entry;
  const _RankCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final rank = entry['rank'] as int? ?? 0;
    final wallet = entry['wallet'] as String? ?? '';
    final totalAgents = entry['total_agents'] as int? ?? 0;
    final totalSaves = entry['total_saves'] as int? ?? 0;
    final totalUses = entry['total_uses'] as int? ?? 0;
    final short = wallet.length > 10
        ? '${wallet.substring(0, 6)}...${wallet.substring(wallet.length - 4)}'
        : wallet;

    final Color rankColor;
    final IconData? rankIcon;
    if (rank == 1) { rankColor = const Color(0xFF9B7B1A); rankIcon = Icons.emoji_events; }
    else if (rank == 2) { rankColor = const Color(0xFF6B5A40); rankIcon = Icons.emoji_events; }
    else if (rank == 3) { rankColor = const Color(0xFFCD7C32); rankIcon = Icons.emoji_events; }
    else { rankColor = const Color(0xFFC0B490); rankIcon = null; }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFC8BA9A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: rank <= 3 ? rankColor.withValues(alpha: 0.3) : const Color(0xFFADA07A)),
        gradient: rank == 1 ? LinearGradient(
          colors: [const Color(0xFF9B7B1A).withValues(alpha: 0.05), Colors.transparent],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ) : null,
      ),
      child: Row(children: [
        SizedBox(
          width: 40,
          child: rankIcon != null
            ? Icon(rankIcon, color: rankColor, size: 28)
            : Text('#$rank', style: TextStyle(
                color: rankColor, fontSize: 16, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(short, style: const TextStyle(
            color: Color(0xFF2B2C1E), fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(height: 2),
          Text('$totalAgents agents created',
            style: const TextStyle(color: Color(0xFF7A6E52), fontSize: 11)),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Row(children: [
            const Icon(Icons.bookmark_border, color: Color(0xFF81231E), size: 13),
            const SizedBox(width: 3),
            Text('$totalSaves',
              style: const TextStyle(color: Color(0xFF6B5A40), fontSize: 12)),
          ]),
          const SizedBox(height: 3),
          Row(children: [
            const Icon(Icons.chat_bubble_outline, color: Color(0xFF81231E), size: 12),
            const SizedBox(width: 3),
            Text('$totalUses',
              style: const TextStyle(color: Color(0xFF6B5A40), fontSize: 12)),
          ]),
        ]),
      ]),
    );
  }
}
