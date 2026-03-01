import 'package:agent_store/features/character/character_types.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/models/guild_model.dart';
import '../../../shared/services/api_service.dart';
import '../../../shared/services/wallet_service.dart';
import '../widgets/team_formation_widget.dart';
import '../widgets/synergy_badge_widget.dart';
import '../widgets/team_workflow_modal.dart';

class GuildDetailScreen extends StatelessWidget {
  final int guildId;
  const GuildDetailScreen({super.key, required this.guildId});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.put(_GuildDetailCtrl(guildId), tag: '$guildId');
    return Obx(() => Scaffold(
      backgroundColor: const Color(0xFFDDD1BB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFC8BA9A),
        foregroundColor: const Color(0xFF2B2C1E),
        title: Text(ctrl.detail.value?.guild.name ?? 'Guild Detail', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        actions: [
          if (ctrl.detail.value != null) ...[
            IconButton(icon: const Icon(Icons.auto_awesome, color: Color(0xFF8B5CF6)), tooltip: 'Open in Guild Master', onPressed: () => _openInGuildMaster(ctrl, context)),
            IconButton(icon: const Icon(Icons.account_tree_outlined, color: Color(0xFF81231E)), tooltip: 'Team Workflow', onPressed: () {
              final d = ctrl.detail.value;
              if (d != null) showDialog<void>(context: context, builder: (_) => TeamWorkflowModal(guild: d.guild));
            }),
          ],
          IconButton(icon: const Icon(Icons.refresh), onPressed: ctrl.load),
        ],
      ),
      body: _buildBody(ctrl, context),
    ));
  }

  Widget _buildBody(_GuildDetailCtrl ctrl, BuildContext context) {
    if (ctrl.isLoading.value) return const Center(child: CircularProgressIndicator(color: Color(0xFF81231E), strokeWidth: 2.5));
    if (ctrl.error.value != null) return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.error_outline, color: Color(0xFF81231E), size: 40), const SizedBox(height: 12),
      Text(ctrl.error.value!, style: const TextStyle(color: Color(0xFF6B5A40))),
      TextButton(onPressed: ctrl.load, child: const Text('Retry')),
    ]));
    final d = ctrl.detail.value;
    if (d == null) return const Center(child: Text('Guild not found', style: TextStyle(color: Color(0xFF2B2C1E))));

    final guild = d.guild;
    final rarityColor = _rarityColor(guild.rarity);
    final isMember = ctrl.isUserMember;
    final isCreator = ctrl.isCreator;
    final isFull = guild.memberCount >= 4;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(guild.roleIcon, style: const TextStyle(fontSize: 32)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(guild.name, style: const TextStyle(color: Color(0xFF2B2C1E), fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Row(children: [
              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: rarityColor.withValues(alpha: 0.15), border: Border.all(color: rarityColor.withValues(alpha: 0.5)), borderRadius: BorderRadius.circular(6)), child: Text(guild.rarity.toUpperCase(), style: TextStyle(color: rarityColor, fontSize: 10, fontWeight: FontWeight.bold))),
              const SizedBox(width: 8),
              Text('${guild.memberCount}/4 members', style: const TextStyle(color: Color(0xFF7A6E52), fontSize: 12)),
            ]),
          ])),
        ]),
        const SizedBox(height: 16),

        if (!isCreator) ...[
          if (ctrl.joinLoading.value)
            const SizedBox(height: 38, child: Center(child: CircularProgressIndicator(color: Color(0xFF81231E), strokeWidth: 2)))
          else if (isMember)
            SizedBox(width: double.infinity, child: OutlinedButton.icon(style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF81231E), side: const BorderSide(color: Color(0xFF81231E), width: 1), padding: const EdgeInsets.symmetric(vertical: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), onPressed: () => _onLeave(ctrl, context), icon: const Icon(Icons.exit_to_app, size: 16), label: const Text('Leave Guild')))
          else
            SizedBox(width: double.infinity, child: FilledButton.icon(style: FilledButton.styleFrom(backgroundColor: isFull ? const Color(0xFFC0B490) : const Color(0xFF5A8A48), padding: const EdgeInsets.symmetric(vertical: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), onPressed: isFull ? null : () => ctrl.join(context), icon: Icon(isFull ? Icons.block : Icons.group_add, size: 16), label: Text(isFull ? 'Guild is Full' : 'Join Guild'))),
          const SizedBox(height: 24),
        ] else ...[
          Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: BoxDecoration(color: const Color(0xFF81231E).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFF81231E).withValues(alpha: 0.3))), child: const Row(children: [Icon(Icons.star, color: Color(0xFF81231E), size: 14), SizedBox(width: 6), Text('You are the Guild Master', style: TextStyle(color: Color(0xFF81231E), fontSize: 12, fontWeight: FontWeight.w600))])),
          const SizedBox(height: 24),
        ],

        _Section(title: 'Guild Stats', child: _GuildStatsRow(guild: guild)),
        const SizedBox(height: 24),
        _Section(title: 'Formation', child: guild.members.isEmpty ? const Text('No members yet', style: TextStyle(color: Color(0xFF7A6E52))) : TeamFormationWidget(members: guild.members)),
        const SizedBox(height: 24),
        _Section(title: 'Active Synergies', child: SynergyBadgeList(synergies: d.synergy)),
        const SizedBox(height: 24),
        if (d.bonuses.isNotEmpty) ...[
          _Section(title: 'Combined Stat Bonuses', child: CombinedBonusBar(bonuses: d.bonuses)),
          const SizedBox(height: 24),
        ],
        _Section(title: 'Members', child: Column(children: guild.members.isEmpty ? [const Text('No members yet', style: TextStyle(color: Color(0xFF7A6E52)))] : guild.members.map((m) => _MemberRow(member: m)).toList())),
        if (guild.members.isNotEmpty) ...[const SizedBox(height: 28), _GuildMasterCTA(onPressed: () => _openInGuildMaster(ctrl, context))],
        const SizedBox(height: 32),
      ]),
    );
  }

  void _openInGuildMaster(_GuildDetailCtrl ctrl, BuildContext context) {
    final d = ctrl.detail.value;
    if (d == null) return;
    final agents = d.guild.members.where((m) => m.agent != null).map((m) => <String, dynamic>{'id': m.agentId, 'title': m.agent!.title, 'character_type': m.agent!.characterType.name, 'subclass': m.agent!.subclass.name}).toList();
    context.go('/guild-master', extra: <String, dynamic>{'guild_name': d.guild.name, 'agents': agents});
  }

  Future<void> _onLeave(_GuildDetailCtrl ctrl, BuildContext context) async {
    if (!ApiService.instance.isAuthenticated) { _showWalletDialog(context); return; }
    final confirmed = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      backgroundColor: const Color(0xFFB8AA88), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Leave Guild?', style: TextStyle(color: Color(0xFF2B2C1E), fontWeight: FontWeight.bold)),
      content: Text('Are you sure you want to leave "${ctrl.detail.value?.guild.name}"?', style: const TextStyle(color: Color(0xFF6B5A40))),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel', style: TextStyle(color: Color(0xFF7A6E52)))), FilledButton(style: FilledButton.styleFrom(backgroundColor: const Color(0xFF81231E)), onPressed: () => Navigator.pop(context, true), child: const Text('Leave'))],
    ));
    if (confirmed != true || !context.mounted) return;
    final ok = await ctrl.leave();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ok ? 'Left guild.' : 'Failed to leave guild.'), backgroundColor: ok ? const Color(0xFFB8AA88) : const Color(0xFF81231E), behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));
    }
  }

  static void _showWalletDialog(BuildContext context) {
    showDialog<void>(context: context, builder: (_) => AlertDialog(
      backgroundColor: const Color(0xFFB8AA88), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Wallet Required', style: TextStyle(color: Color(0xFF2B2C1E), fontWeight: FontWeight.bold)),
      content: const Text('Connect your wallet to join or leave guilds.', style: TextStyle(color: Color(0xFF6B5A40))),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Color(0xFF7A6E52)))), FilledButton(style: FilledButton.styleFrom(backgroundColor: const Color(0xFF81231E)), onPressed: () { Navigator.pop(context); context.go('/wallet'); }, child: const Text('Connect Wallet'))],
    ));
  }

  static Color _rarityColor(String rarity) => switch (rarity.toLowerCase()) {
    'legendary' => const Color(0xFF9B7B1A),
    'epic'      => const Color(0xFF70683B),
    'rare'      => const Color(0xFF5F6A54),
    'uncommon'  => const Color(0xFF5A8A48),
    _           => const Color(0xFF7A6E52),
  };
}

// ── Local micro-controller ───────────────────────────────────────────────────

class _GuildDetailCtrl extends GetxController {
  final int guildId;
  _GuildDetailCtrl(this.guildId);

  final detail = Rxn<GuildDetailModel>();
  final isLoading = true.obs;
  final joinLoading = false.obs;
  final error = RxnString();

  bool get isUserMember {
    final wallet = WalletService.instance.connectedWallet;
    if (wallet == null || detail.value == null) return false;
    return detail.value!.guild.members.any((m) => m.agent?.creatorWallet.toLowerCase() == wallet.toLowerCase());
  }

  bool get isCreator {
    final wallet = WalletService.instance.connectedWallet;
    if (wallet == null || detail.value == null) return false;
    return detail.value!.guild.creatorWallet.toLowerCase() == wallet.toLowerCase();
  }

  @override
  void onInit() { super.onInit(); load(); }

  Future<void> load() async {
    isLoading.value = true; error.value = null;
    try {
      detail.value = await ApiService.instance.getGuild(guildId);
    } catch (e) { error.value = e.toString(); }
    isLoading.value = false;
  }

  Future<void> join(BuildContext context) async {
    if (!ApiService.instance.isAuthenticated) { GuildDetailScreen._showWalletDialog(context); return; }
    joinLoading.value = true;
    final ok = await ApiService.instance.joinGuild(guildId);
    joinLoading.value = false;
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ok ? 'Joined guild successfully!' : 'Failed to join guild. Guild may be full.'), backgroundColor: ok ? const Color(0xFF5A8A48) : const Color(0xFF81231E), behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));
    }
    if (ok) await load();
  }

  Future<bool> leave() async {
    joinLoading.value = true;
    final ok = await ApiService.instance.leaveGuild(guildId);
    joinLoading.value = false;
    if (ok) await load();
    return ok;
  }
}

// ── Supporting widgets ────────────────────────────────────────────────────────

class _GuildStatsRow extends StatelessWidget {
  final GuildModel guild;
  const _GuildStatsRow({required this.guild});

  @override
  Widget build(BuildContext context) {
    final isFull = guild.memberCount >= 4;
    final slotColor = isFull ? const Color(0xFF81231E) : const Color(0xFF5A8A48);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFFE8DEC9), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFADA07A))),
      child: Row(children: [
        _StatCell(icon: Icons.group, iconColor: slotColor, label: 'Members', value: '${guild.memberCount}/4'),
        _VertDivider(),
        _StatCell(icon: Icons.calendar_today, iconColor: const Color(0xFF7A6E52), label: 'Created', value: _formatDate(guild.createdAt)),
        _VertDivider(),
        _StatCell(icon: Icons.emoji_events, iconColor: const Color(0xFF81231E), label: 'Status', value: isFull ? 'Full' : 'Recruiting', valueColor: slotColor),
      ]),
    );
  }

  static String _formatDate(DateTime dt) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }
}

class _StatCell extends StatelessWidget {
  final IconData icon; final Color iconColor; final String label; final String value; final Color? valueColor;
  const _StatCell({required this.icon, required this.iconColor, required this.label, required this.value, this.valueColor});
  @override
  Widget build(BuildContext context) => Expanded(child: Column(children: [
    Icon(icon, color: iconColor, size: 18), const SizedBox(height: 6),
    Text(value, style: TextStyle(color: valueColor ?? const Color(0xFF2B2C1E), fontWeight: FontWeight.bold, fontSize: 13)),
    const SizedBox(height: 2),
    Text(label, style: const TextStyle(color: Color(0xFF7A6E52), fontSize: 10)),
  ]));
}

class _VertDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(width: 1, height: 40, color: const Color(0xFFADA07A), margin: const EdgeInsets.symmetric(horizontal: 8));
}

class _Section extends StatelessWidget {
  final String title; final Widget child;
  const _Section({required this.title, required this.child});
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(title, style: const TextStyle(color: Color(0xFF6B5A40), fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1)),
    const SizedBox(height: 12), child,
  ]);
}

class _GuildMasterCTA extends StatelessWidget {
  final VoidCallback onPressed;
  const _GuildMasterCTA({required this.onPressed});
  @override
  Widget build(BuildContext context) => GestureDetector(onTap: onPressed, child: Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(gradient: LinearGradient(colors: [const Color(0xFF6366F1).withValues(alpha: 0.15), const Color(0xFF8B5CF6).withValues(alpha: 0.10)], begin: Alignment.centerLeft, end: Alignment.centerRight), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.4))),
    child: Row(children: [
      Container(width: 44, height: 44, decoration: BoxDecoration(color: const Color(0xFF6366F1).withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10), boxShadow: [BoxShadow(color: const Color(0xFF6366F1).withValues(alpha: 0.3), blurRadius: 12)]), child: const Icon(Icons.auto_awesome, color: Color(0xFF8B5CF6), size: 22)),
      const SizedBox(width: 14),
      const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Open in Guild Master', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
        SizedBox(height: 3),
        Text('Chat with your team and get AI-powered insights', style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12)),
      ])),
      const SizedBox(width: 8),
      const Icon(Icons.arrow_forward_ios, color: Color(0xFF6366F1), size: 14),
    ]),
  ));
}

class _MemberRow extends StatelessWidget {
  final GuildMemberModel member;
  const _MemberRow({required this.member});

  String get _roleIcon => switch (member.role) { 'Brain' => '🧠', 'Shield' => '🛡', 'Scout' => '⚡', 'Innovator' => '💡', 'Striker' => '⚔', _ => '●' };
  String _shortWallet(String w) => w.length <= 12 ? w : '${w.substring(0, 6)}...${w.substring(w.length - 4)}';
  String _formatJoined(DateTime dt) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return 'Joined ${months[dt.month - 1]} ${dt.day}';
  }

  @override
  Widget build(BuildContext context) {
    final agent = member.agent;
    if (agent == null) return const SizedBox.shrink();
    final typeColor = agent.characterType.primaryColor;
    return Container(
      margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFFE8DEC9), borderRadius: BorderRadius.circular(10), border: Border.all(color: typeColor.withValues(alpha: 0.2))),
      child: Row(children: [
        Text(_roleIcon, style: const TextStyle(fontSize: 18)), const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(agent.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text('${agent.characterType.displayName} · ${agent.subclass.displayName}', style: TextStyle(color: typeColor, fontSize: 10)),
          const SizedBox(height: 2),
          Row(children: [const Icon(Icons.account_balance_wallet, size: 10, color: Color(0xFF7A6E52)), const SizedBox(width: 3), Text(_shortWallet(agent.creatorWallet), style: const TextStyle(color: Color(0xFF7A6E52), fontSize: 10)), const SizedBox(width: 8), const Icon(Icons.schedule, size: 10, color: Color(0xFF5A5038)), const SizedBox(width: 3), Text(_formatJoined(member.joinedAt), style: const TextStyle(color: Color(0xFF5A5038), fontSize: 10))]),
        ])),
        const SizedBox(width: 8),
        Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: const Color(0xFF282918), borderRadius: BorderRadius.circular(6)), child: Text(member.role, style: const TextStyle(color: Color(0xFF6B5A40), fontSize: 10))),
      ]),
    );
  }
}
