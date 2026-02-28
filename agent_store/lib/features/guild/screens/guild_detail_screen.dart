import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../features/character/character_types.dart';
import '../../../shared/models/guild_model.dart';
import '../../../shared/services/api_service.dart';
import '../../../shared/services/wallet_service.dart';
import '../widgets/team_formation_widget.dart';
import '../widgets/synergy_badge_widget.dart';
import '../widgets/team_workflow_modal.dart';

class GuildDetailScreen extends StatefulWidget {
  final int guildId;
  const GuildDetailScreen({super.key, required this.guildId});

  @override
  State<GuildDetailScreen> createState() => _GuildDetailScreenState();
}

class _GuildDetailScreenState extends State<GuildDetailScreen> {
  GuildDetailModel? _detail;
  bool _loading = true;
  String? _error;
  bool _joinLoading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final detail = await ApiService.instance.getGuild(widget.guildId);
      if (mounted) setState(() { _detail = detail; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  /// Returns true if the currently connected wallet owns any of the guild members.
  bool get _isUserMember {
    final wallet = WalletService.instance.connectedWallet;
    if (wallet == null || _detail == null) return false;
    return _detail!.guild.members.any(
      (m) => m.agent?.creatorWallet.toLowerCase() == wallet.toLowerCase(),
    );
  }

  bool get _isCreator {
    final wallet = WalletService.instance.connectedWallet;
    if (wallet == null || _detail == null) return false;
    return _detail!.guild.creatorWallet.toLowerCase() == wallet.toLowerCase();
  }

  void _showWalletDialog() {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E1F14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Wallet Required',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text(
          'Connect your wallet to join or leave guilds.',
          style: TextStyle(color: Color(0xFF9E8F72)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF7A6E52))),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF81231E)),
            onPressed: () {
              Navigator.pop(context);
              context.go('/wallet');
            },
            child: const Text('Connect Wallet'),
          ),
        ],
      ),
    );
  }

  Future<void> _onJoin() async {
    if (!ApiService.instance.isAuthenticated) {
      _showWalletDialog();
      return;
    }
    setState(() { _joinLoading = true; });
    final ok = await ApiService.instance.joinGuild(widget.guildId);
    if (mounted) {
      setState(() { _joinLoading = false; });
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Joined guild successfully!'),
            backgroundColor: const Color(0xFF5A8A48),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        _load();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to join guild. Guild may be full.'),
            backgroundColor: const Color(0xFF81231E),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  Future<void> _onLeave() async {
    if (!ApiService.instance.isAuthenticated) {
      _showWalletDialog();
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E1F14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Leave Guild?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(
          'Are you sure you want to leave "${_detail?.guild.name}"?',
          style: const TextStyle(color: Color(0xFF9E8F72)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF7A6E52))),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF81231E)),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() { _joinLoading = true; });
    final ok = await ApiService.instance.leaveGuild(widget.guildId);
    if (mounted) {
      setState(() { _joinLoading = false; });
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Left guild.'),
            backgroundColor: const Color(0xFF1E1F14),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        _load();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to leave guild.'),
            backgroundColor: const Color(0xFF81231E),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  void _onTeamWorkflow() {
    if (_detail == null) return;
    showDialog<void>(
      context: context,
      builder: (_) => TeamWorkflowModal(guild: _detail!.guild),
    );
  }

  void _openInGuildMaster() {
    if (_detail == null) return;
    final agents = _detail!.guild.members
        .where((m) => m.agent != null)
        .map((m) => <String, dynamic>{
              'id': m.agentId,
              'title': m.agent!.title,
              'character_type': m.agent!.characterType.name,
              'subclass': m.agent!.subclass.name,
            })
        .toList();
    context.go('/guild-master', extra: <String, dynamic>{
      'guild_name': _detail!.guild.name,
      'agents': agents,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF181910),
      appBar: AppBar(
        backgroundColor: const Color(0xFF22231A),
        foregroundColor: Colors.white,
        title: Text(_detail?.guild.name ?? 'Guild Detail',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        actions: [
          if (_detail != null) ...[
            IconButton(
              icon: const Icon(Icons.auto_awesome, color: Color(0xFF8B5CF6)),
              tooltip: 'Open in Guild Master',
              onPressed: _openInGuildMaster,
            ),
            IconButton(
              icon: const Icon(Icons.account_tree_outlined, color: Color(0xFF81231E)),
              tooltip: 'Team Workflow',
              onPressed: _onTeamWorkflow,
            ),
          ],
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(
        color: Color(0xFF81231E),
        strokeWidth: 2.5,
      ));
    }
    if (_error != null) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.error_outline, color: Color(0xFF81231E), size: 40),
        const SizedBox(height: 12),
        Text(_error!, style: const TextStyle(color: Color(0xFF9E8F72))),
        TextButton(onPressed: _load, child: const Text('Retry')),
      ]));
    }
    if (_detail == null) return const Center(child: Text('Guild not found', style: TextStyle(color: Colors.white)));

    final guild = _detail!.guild;
    final rarityColor = _rarityColor(guild.rarity);
    final isMember = _isUserMember;
    final isCreator = _isCreator;
    final isFull = guild.memberCount >= 4;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Header ──
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(guild.roleIcon, style: const TextStyle(fontSize: 32)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(guild.name, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: rarityColor.withValues(alpha: 0.15),
                  border: Border.all(color: rarityColor.withValues(alpha: 0.5)),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(guild.rarity.toUpperCase(),
                  style: TextStyle(color: rarityColor, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 8),
              Text('${guild.memberCount}/4 members',
                style: const TextStyle(color: Color(0xFF7A6E52), fontSize: 12)),
            ]),
          ])),
        ]),

        const SizedBox(height: 16),

        // ── Join / Leave button ──
        if (!isCreator) ...[
          if (_joinLoading)
            const SizedBox(
              height: 38,
              child: Center(child: CircularProgressIndicator(color: Color(0xFF81231E), strokeWidth: 2)),
            )
          else if (isMember)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF81231E),
                  side: const BorderSide(color: Color(0xFF81231E), width: 1),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _onLeave,
                icon: const Icon(Icons.exit_to_app, size: 16),
                label: const Text('Leave Guild'),
              ),
            )
          else
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: isFull ? const Color(0xFF4A4A33) : const Color(0xFF5A8A48),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: isFull ? null : _onJoin,
                icon: Icon(isFull ? Icons.block : Icons.group_add, size: 16),
                label: Text(isFull ? 'Guild is Full' : 'Join Guild'),
              ),
            ),
          const SizedBox(height: 24),
        ] else ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF81231E).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF81231E).withValues(alpha: 0.3)),
            ),
            child: const Row(children: [
              Icon(Icons.star, color: Color(0xFF81231E), size: 14),
              SizedBox(width: 6),
              Text('You are the Guild Master', style: TextStyle(color: Color(0xFF81231E), fontSize: 12, fontWeight: FontWeight.w600)),
            ]),
          ),
          const SizedBox(height: 24),
        ],

        // ── Guild Stats ──
        _Section(
          title: 'Guild Stats',
          child: _GuildStatsRow(guild: guild),
        ),

        const SizedBox(height: 24),

        // ── Formation ──
        _Section(
          title: 'Formation',
          child: guild.members.isEmpty
              ? const Text('No members yet', style: TextStyle(color: Color(0xFF7A6E52)))
              : TeamFormationWidget(members: guild.members),
        ),

        const SizedBox(height: 24),

        // ── Synergy Bonuses ──
        _Section(
          title: 'Active Synergies',
          child: SynergyBadgeList(synergies: _detail!.synergy),
        ),

        const SizedBox(height: 24),

        // ── Combined Stat Bonuses ──
        if (_detail!.bonuses.isNotEmpty) ...[
          _Section(
            title: 'Combined Stat Bonuses',
            child: CombinedBonusBar(bonuses: _detail!.bonuses),
          ),
          const SizedBox(height: 24),
        ],

        // ── Member List ──
        _Section(
          title: 'Members',
          child: Column(
            children: guild.members.isEmpty
                ? [const Text('No members yet', style: TextStyle(color: Color(0xFF7A6E52)))]
                : guild.members.map((m) => _MemberRow(member: m)).toList(),
          ),
        ),

        if (guild.members.isNotEmpty) ...[
          const SizedBox(height: 28),
          // ── Guild Master CTA ──
          _GuildMasterCTA(onPressed: _openInGuildMaster),
        ],

        const SizedBox(height: 32),
      ]),
    );
  }

  Color _rarityColor(String rarity) => switch (rarity.toLowerCase()) {
    'legendary' => const Color(0xFF9B7B1A),
    'epic'      => const Color(0xFF70683B),
    'rare'      => const Color(0xFF5F6A54),
    'uncommon'  => const Color(0xFF5A8A48),
    _           => const Color(0xFF7A6E52),
  };
}

class _GuildStatsRow extends StatelessWidget {
  final GuildModel guild;
  const _GuildStatsRow({required this.guild});

  @override
  Widget build(BuildContext context) {
    final isFull = guild.memberCount >= 4;
    final slotColor = isFull ? const Color(0xFF81231E) : const Color(0xFF5A8A48);
    final createdFormatted = _formatDate(guild.createdAt);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2B1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF3D3E2A)),
      ),
      child: Row(children: [
        _StatCell(
          icon: Icons.group,
          iconColor: slotColor,
          label: 'Members',
          value: '${guild.memberCount}/4',
        ),
        _VertDivider(),
        _StatCell(
          icon: Icons.calendar_today,
          iconColor: const Color(0xFF7A6E52),
          label: 'Created',
          value: createdFormatted,
        ),
        _VertDivider(),
        _StatCell(
          icon: Icons.emoji_events,
          iconColor: const Color(0xFF81231E),
          label: 'Status',
          value: isFull ? 'Full' : 'Recruiting',
          valueColor: slotColor,
        ),
      ]),
    );
  }

  String _formatDate(DateTime dt) {
    final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }
}

class _StatCell extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final Color? valueColor;
  const _StatCell({required this.icon, required this.iconColor, required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(children: [
      Icon(icon, color: iconColor, size: 18),
      const SizedBox(height: 6),
      Text(value, style: TextStyle(
        color: valueColor ?? Colors.white,
        fontWeight: FontWeight.bold,
        fontSize: 13,
      )),
      const SizedBox(height: 2),
      Text(label, style: const TextStyle(color: Color(0xFF7A6E52), fontSize: 10)),
    ]),
  );
}

class _VertDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    width: 1, height: 40,
    color: const Color(0xFF3D3E2A),
    margin: const EdgeInsets.symmetric(horizontal: 8),
  );
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: const TextStyle(color: Color(0xFF9E8F72), fontSize: 11,
        fontWeight: FontWeight.w600, letterSpacing: 1)),
      const SizedBox(height: 12),
      child,
    ],
  );
}

// ── Guild Master CTA Card ─────────────────────────────────────────────────────

class _GuildMasterCTA extends StatelessWidget {
  final VoidCallback onPressed;
  const _GuildMasterCTA({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFF6366F1).withValues(alpha: 0.15),
              const Color(0xFF8B5CF6).withValues(alpha: 0.10),
            ],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.4)),
        ),
        child: Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                  blurRadius: 12,
                ),
              ],
            ),
            child: const Icon(Icons.auto_awesome, color: Color(0xFF8B5CF6), size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text(
                'Open in Guild Master',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 3),
              const Text(
                'Chat with your team and get AI-powered insights',
                style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12),
              ),
            ]),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.arrow_forward_ios, color: Color(0xFF6366F1), size: 14),
        ]),
      ),
    );
  }
}

class _MemberRow extends StatelessWidget {
  final GuildMemberModel member;
  const _MemberRow({required this.member});

  String get _roleIcon => switch (member.role) {
    'Brain'    => '🧠',
    'Shield'   => '🛡',
    'Scout'    => '⚡',
    'Innovator'=> '💡',
    'Striker'  => '⚔',
    _          => '●',
  };

  String _shortWallet(String wallet) {
    if (wallet.length <= 12) return wallet;
    return '${wallet.substring(0, 6)}...${wallet.substring(wallet.length - 4)}';
  }

  String _formatJoined(DateTime dt) {
    final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return 'Joined ${months[dt.month - 1]} ${dt.day}';
  }

  @override
  Widget build(BuildContext context) {
    final agent = member.agent;
    if (agent == null) return const SizedBox.shrink();
    final typeColor = agent.characterType.primaryColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2B1E),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: typeColor.withValues(alpha: 0.2)),
      ),
      child: Row(children: [
        Text(_roleIcon, style: const TextStyle(fontSize: 18)),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(agent.title,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
            maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text('${agent.characterType.displayName} · ${agent.subclass.displayName}',
            style: TextStyle(color: typeColor, fontSize: 10)),
          const SizedBox(height: 2),
          Row(children: [
            const Icon(Icons.account_balance_wallet, size: 10, color: Color(0xFF7A6E52)),
            const SizedBox(width: 3),
            Text(_shortWallet(agent.creatorWallet),
              style: const TextStyle(color: Color(0xFF7A6E52), fontSize: 10)),
            const SizedBox(width: 8),
            const Icon(Icons.schedule, size: 10, color: Color(0xFF5A5038)),
            const SizedBox(width: 3),
            Text(_formatJoined(member.joinedAt),
              style: const TextStyle(color: Color(0xFF5A5038), fontSize: 10)),
          ]),
        ])),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFF282918),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(member.role, style: const TextStyle(color: Color(0xFF9E8F72), fontSize: 10)),
        ),
      ]),
    );
  }
}
