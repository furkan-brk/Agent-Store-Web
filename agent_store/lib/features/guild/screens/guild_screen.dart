import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import '../../../controllers/guild_controller.dart';
import '../../../shared/models/guild_model.dart';
import '../../../shared/services/api_service.dart';
import '../../../shared/widgets/skeleton_widgets.dart';
import '../../character/character_types.dart';

class GuildScreen extends StatelessWidget {
  const GuildScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.put(GuildController());

    return Obx(() => Scaffold(
      backgroundColor: const Color(0xFFDDD1BB),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Text('Guilds', style: TextStyle(color: Color(0xFF2B2C1E), fontSize: 24, fontWeight: FontWeight.bold)),
            const Spacer(),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF81231E)),
              onPressed: () => _onCreateGuild(context),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Create Guild'),
            ),
          ]),
          const SizedBox(height: 8),
          const Text('2–4 agents united for synergy bonuses', style: TextStyle(color: Color(0xFF7A6E52), fontSize: 13)),
          const SizedBox(height: 24),
          if (ctrl.isLoading.value)
            Expanded(
              child: ShimmerScope(
                child: GridView.builder(
                  padding: const EdgeInsets.all(0),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 280, mainAxisExtent: 172,
                    crossAxisSpacing: 12, mainAxisSpacing: 12),
                  itemCount: 8,
                  itemBuilder: (_, __) => const GuildCardSkeleton(),
                ),
              ),
            )
          else if (ctrl.error.value != null)
            Expanded(child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.error_outline, color: Color(0xFF81231E), size: 40),
              const SizedBox(height: 12),
              Text(ctrl.error.value!, style: const TextStyle(color: Color(0xFF6B5A40))),
              const SizedBox(height: 16),
              TextButton(onPressed: ctrl.load, child: const Text('Retry')),
            ])))
          else if (ctrl.guilds.isEmpty)
            Expanded(child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.groups_outlined, color: Color(0xFFC0B490), size: 64),
              const SizedBox(height: 16),
              const Text('No guilds yet', style: TextStyle(color: Color(0xFF2B2C1E), fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('Be the first to create one!', style: TextStyle(color: Color(0xFF7A6E52), fontSize: 13)),
              const SizedBox(height: 24),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF81231E)),
                onPressed: () => _onCreateGuild(context),
                icon: const Icon(Icons.add, size: 16), label: const Text('Create Guild'),
              ),
            ])))
          else
            Expanded(child: RefreshIndicator(
              onRefresh: ctrl.load,
              color: const Color(0xFF81231E),
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 280, mainAxisExtent: 172, crossAxisSpacing: 12, mainAxisSpacing: 12),
                itemCount: ctrl.guilds.length,
                itemBuilder: (_, i) => _GuildCard(guild: ctrl.guilds[i]),
              ),
            )),
        ]),
      ),
    ));
  }

  void _onCreateGuild(BuildContext context) {
    if (!ApiService.instance.isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Connect your wallet to create a guild'),
        backgroundColor: const Color(0xFFB8AA88),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        action: SnackBarAction(label: 'Connect', textColor: const Color(0xFF81231E), onPressed: () => context.go('/wallet')),
      ));
      return;
    }
    context.go('/guild/create');
  }
}

class _GuildCard extends StatelessWidget {
  final GuildModel guild;
  const _GuildCard({required this.guild});

  @override
  Widget build(BuildContext context) {
    final rarityColor = _rarityColor(guild.rarity);
    final statusLabel = guild.memberCount >= 4 ? 'Full' : 'Recruiting';
    final statusColor = guild.memberCount >= 4 ? const Color(0xFF81231E) : const Color(0xFF5A8A48);
    final categoryLabel = _categoryLabel(guild);

    return InkWell(
      onTap: () => context.go('/guild/${guild.id}'),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFE8DEC9), borderRadius: BorderRadius.circular(12),
          border: Border.all(color: rarityColor.withValues(alpha: 0.35)),
          boxShadow: [BoxShadow(color: rarityColor.withValues(alpha: 0.06), blurRadius: 8)],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(guild.roleIcon, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Expanded(child: Text(guild.name,
              style: const TextStyle(color: Color(0xFF2B2C1E), fontWeight: FontWeight.bold, fontSize: 14),
              maxLines: 1, overflow: TextOverflow.ellipsis)),
          ]),
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 4, children: [
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: rarityColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
              child: Text(guild.rarity.toUpperCase(), style: TextStyle(color: rarityColor, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1))),
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: const Color(0xFF282918), borderRadius: BorderRadius.circular(6)),
              child: Text(categoryLabel, style: const TextStyle(color: Color(0xFF6B5A40), fontSize: 9, fontWeight: FontWeight.w500))),
          ]),
          const Spacer(),
          Row(children: [
            const Icon(Icons.group, size: 14, color: Color(0xFF7A6E52)),
            const SizedBox(width: 4),
            Text('${guild.memberCount}/4 members', style: const TextStyle(color: Color(0xFF7A6E52), fontSize: 11)),
            const SizedBox(width: 8),
            Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(4)),
              child: Text(statusLabel, style: TextStyle(color: statusColor, fontSize: 9, fontWeight: FontWeight.bold))),
            const Spacer(),
            const Icon(Icons.chevron_right, size: 16, color: Color(0xFF5A5038)),
          ]),
        ]),
      ),
    );
  }

  String _categoryLabel(GuildModel guild) {
    if (guild.members.isEmpty) return 'Open Roster';
    final types = guild.members.map((m) => m.agent?.characterType.displayName).whereType<String>().toSet().toList();
    if (types.isEmpty) return 'Mixed';
    if (types.length == 1) return types.first;
    return '${types.length} Types';
  }

  Color _rarityColor(String rarity) => switch (rarity.toLowerCase()) {
    'legendary' => const Color(0xFF9B7B1A),
    'epic'      => const Color(0xFF70683B),
    'rare'      => const Color(0xFF5F6A54),
    'uncommon'  => const Color(0xFF5A8A48),
    _           => const Color(0xFF7A6E52),
  };
}
