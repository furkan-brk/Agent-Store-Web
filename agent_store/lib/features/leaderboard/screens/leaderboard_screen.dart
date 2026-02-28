import 'package:flutter/material.dart';
import '../../../app/theme.dart';
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
        _rankings = List<Map<String, dynamic>>.from(data['rankings'] as List? ?? []);
        _loading = false;
      });
    } else {
      setState(() { _loading = false; _error = 'Failed to load leaderboard.'; });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppTheme.bg,
    body: Column(children: [
      Container(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
        decoration: const BoxDecoration(
          color: AppTheme.surface,
          border: Border(bottom: BorderSide(color: AppTheme.border)),
        ),
        child: Row(children: [
          const Icon(Icons.emoji_events_rounded, color: AppTheme.gold, size: 22),
          const SizedBox(width: 10),
          ShaderMask(
            shaderCallback: (b) => const LinearGradient(
              colors: [AppTheme.textH, AppTheme.gold],
            ).createShader(b),
            child: const Text('Leaderboard',
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          ),
          const Spacer(),
          const Text('Top Creators', style: TextStyle(color: AppTheme.textM, fontSize: 12)),
        ]),
      ),
      if (_loading)
        const Expanded(child: Center(child: CircularProgressIndicator(color: AppTheme.primary)))
      else if (_error != null)
        Expanded(child: Center(child: Text(_error!, style: const TextStyle(color: AppTheme.textB))))
      else if (_rankings.isEmpty)
        const Expanded(child: Center(child: Column(
          mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.emoji_events_outlined, color: AppTheme.border2, size: 56),
            SizedBox(height: 14),
            Text('No creators yet', style: TextStyle(color: AppTheme.textM, fontSize: 15)),
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
    if (rank == 1) { rankColor = AppTheme.gold; rankIcon = Icons.emoji_events_rounded; }
    else if (rank == 2) { rankColor = const Color(0xFF8A9A9A); rankIcon = Icons.emoji_events_rounded; }
    else if (rank == 3) { rankColor = const Color(0xFFCD7C32); rankIcon = Icons.emoji_events_rounded; }
    else { rankColor = AppTheme.textM; rankIcon = null; }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: rank <= 3 ? rankColor.withValues(alpha: 0.4) : AppTheme.border,
        ),
        gradient: rank == 1 ? LinearGradient(
          colors: [AppTheme.gold.withValues(alpha: 0.08), Colors.transparent],
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
            color: AppTheme.textH, fontWeight: FontWeight.w600, fontSize: 14,
            fontFamily: 'monospace')),
          const SizedBox(height: 2),
          Text('$totalAgents agents created',
            style: const TextStyle(color: AppTheme.textM, fontSize: 11)),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Row(children: [
            const Icon(Icons.bookmark_border, color: AppTheme.primary, size: 13),
            const SizedBox(width: 3),
            Text('$totalSaves', style: const TextStyle(color: AppTheme.textB, fontSize: 12)),
          ]),
          const SizedBox(height: 3),
          Row(children: [
            const Icon(Icons.chat_bubble_outline, color: AppTheme.primary, size: 12),
            const SizedBox(width: 3),
            Text('$totalUses', style: const TextStyle(color: AppTheme.textB, fontSize: 12)),
          ]),
        ]),
      ]),
    );
  }
}
