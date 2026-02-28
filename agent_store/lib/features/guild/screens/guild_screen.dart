import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../character/character_types.dart';
import '../../../shared/models/guild_model.dart';
import '../../../shared/services/api_service.dart';

class GuildScreen extends StatefulWidget {
  const GuildScreen({super.key});

  @override
  State<GuildScreen> createState() => _GuildScreenState();
}

class _GuildScreenState extends State<GuildScreen> {
  List<GuildModel> _guilds = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final result = await ApiService.instance.listGuilds();
      if (mounted) setState(() { _guilds = result.guilds; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  void _onCreateGuild() {
    if (!ApiService.instance.isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Connect your wallet to create a guild'),
          backgroundColor: const Color(0xFF1A1A2E),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          action: SnackBarAction(
            label: 'Connect',
            textColor: const Color(0xFF6366F1),
            onPressed: () => context.go('/wallet'),
          ),
        ),
      );
      return;
    }
    context.go('/guild/create');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A14),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Text('Guilds', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
            const Spacer(),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF6366F1)),
              onPressed: _onCreateGuild,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Create Guild'),
            ),
          ]),
          const SizedBox(height: 8),
          const Text('2–4 agents united for synergy bonuses',
            style: TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
          const SizedBox(height: 24),
          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator(
              color: Color(0xFF6366F1),
              strokeWidth: 2.5,
            )))
          else if (_error != null)
            Expanded(child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 40),
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Color(0xFF9CA3AF))),
              const SizedBox(height: 16),
              TextButton(onPressed: _load, child: const Text('Retry')),
            ])))
          else if (_guilds.isEmpty)
            Expanded(child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.groups_outlined, color: Color(0xFF374151), size: 64),
              const SizedBox(height: 16),
              const Text('No guilds yet', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('Be the first to create one!',
                style: TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
              const SizedBox(height: 24),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF6366F1)),
                onPressed: _onCreateGuild,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Create Guild'),
              ),
            ])))
          else
            Expanded(
              child: RefreshIndicator(
                onRefresh: _load,
                color: const Color(0xFF6366F1),
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 280,
                    mainAxisExtent: 172,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: _guilds.length,
                  itemBuilder: (_, i) => _GuildCard(guild: _guilds[i]),
                ),
              ),
            ),
        ]),
      ),
    );
  }
}

class _GuildCard extends StatelessWidget {
  final GuildModel guild;
  const _GuildCard({required this.guild});

  @override
  Widget build(BuildContext context) {
    final rarityColor = _rarityColor(guild.rarity);
    final statusLabel = guild.memberCount >= 4 ? 'Full' : 'Recruiting';
    final statusColor = guild.memberCount >= 4
        ? const Color(0xFFEF4444)
        : const Color(0xFF10B981);

    final categoryLabel = _categoryLabel(guild);

    return InkWell(
      onTap: () => context.go('/guild/${guild.id}'),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF13131F),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: rarityColor.withValues(alpha: 0.35)),
          boxShadow: [BoxShadow(color: rarityColor.withValues(alpha: 0.06), blurRadius: 8)],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(guild.roleIcon, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Expanded(child: Text(guild.name,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
              maxLines: 1, overflow: TextOverflow.ellipsis)),
          ]),
          const SizedBox(height: 8),
          // Rarity badge + category badge row
          Wrap(spacing: 6, runSpacing: 4, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: rarityColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(guild.rarity.toUpperCase(),
                style: TextStyle(color: rarityColor, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF1F2937),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(categoryLabel,
                style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 9, fontWeight: FontWeight.w500)),
            ),
          ]),
          const Spacer(),
          Row(children: [
            const Icon(Icons.group, size: 14, color: Color(0xFF6B7280)),
            const SizedBox(width: 4),
            Text('${guild.memberCount}/4 members',
              style: const TextStyle(color: Color(0xFF6B7280), fontSize: 11)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(statusLabel,
                style: TextStyle(color: statusColor, fontSize: 9, fontWeight: FontWeight.bold)),
            ),
            const Spacer(),
            const Icon(Icons.chevron_right, size: 16, color: Color(0xFF4B5563)),
          ]),
        ]),
      ),
    );
  }

  /// Derive a display category from available member data.
  String _categoryLabel(GuildModel guild) {
    if (guild.members.isEmpty) return 'Open Roster';
    // Collect distinct character types from member agents
    final types = guild.members
        .map((m) => m.agent?.characterType.displayName)
        .whereType<String>()
        .toSet()
        .toList();
    if (types.isEmpty) return 'Mixed';
    if (types.length == 1) return types.first;
    return '${types.length} Types';
  }

  Color _rarityColor(String rarity) => switch (rarity.toLowerCase()) {
    'legendary' => const Color(0xFFF59E0B),
    'epic'      => const Color(0xFFA855F7),
    'rare'      => const Color(0xFF3B82F6),
    'uncommon'  => const Color(0xFF22C55E),
    _           => const Color(0xFF6B7280),
  };
}
