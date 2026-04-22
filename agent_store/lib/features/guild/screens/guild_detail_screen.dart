import 'package:agent_store/features/character/character_types.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme.dart';
import '../../../shared/models/guild_model.dart';
import '../../../shared/services/api_service.dart';
import '../../../shared/services/wallet_service.dart';
import '../../../shared/widgets/pixel_character_widget.dart';
import '../../../shared/widgets/skeleton_widgets.dart';
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
  late final _GuildDetailCtrl ctrl;

  @override
  void initState() {
    super.initState();
    ctrl = Get.put(_GuildDetailCtrl(widget.guildId), tag: '${widget.guildId}');
  }

  @override
  void dispose() {
    Get.delete<_GuildDetailCtrl>(tag: '${widget.guildId}');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() => Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        foregroundColor: AppTheme.textH,
        elevation: 0,
        title: Text(
          ctrl.detail.value?.guild.name ?? 'Guild Detail',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textH),
        ),
        actions: [
          if (ctrl.detail.value != null) ...[
            _AppBarAction(
              icon: Icons.auto_awesome,
              color: const Color(0xFF8B5CF6),
              tooltip: 'Open in Guild Master',
              onPressed: () => _openInGuildMaster(ctrl, context),
            ),
            _AppBarAction(
              icon: Icons.account_tree_outlined,
              color: AppTheme.primary,
              tooltip: 'Team Workflow',
              onPressed: () {
                final d = ctrl.detail.value;
                if (d != null) showDialog<void>(context: context, builder: (_) => TeamWorkflowModal(guild: d.guild));
              },
            ),
          ],
          _AppBarAction(
            icon: Icons.refresh_rounded,
            color: AppTheme.textB,
            tooltip: 'Refresh',
            onPressed: ctrl.load,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _buildBody(ctrl, context),
    ));
  }

  Widget _buildBody(_GuildDetailCtrl ctrl, BuildContext context) {
    if (ctrl.isLoading.value) return _buildLoadingSkeleton();
    if (ctrl.error.value != null) {
      return Center(child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.error_outline_rounded, color: AppTheme.primary, size: 32),
          ),
          const SizedBox(height: 16),
          const Text('Failed to load guild', style: TextStyle(color: AppTheme.textH, fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(
            ctrl.error.value!,
            style: const TextStyle(color: AppTheme.textM, fontSize: 13),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: AppTheme.textH,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: ctrl.load,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Retry'),
          ),
        ]),
      ));
    }
    final d = ctrl.detail.value;
    if (d == null) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.groups_outlined, color: AppTheme.textM, size: 48),
        const SizedBox(height: 12),
        const Text('Guild not found', style: TextStyle(color: AppTheme.textH, fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: () => context.go('/guild'),
          icon: const Icon(Icons.arrow_back_rounded, size: 16),
          label: const Text('Back to Guilds'),
          style: TextButton.styleFrom(foregroundColor: AppTheme.gold),
        ),
      ]));
    }

    final guild = d.guild;
    final rarityColor = _rarityColor(guild.rarity);
    final isMember = ctrl.isUserMember;
    final isCreator = ctrl.isCreator;
    final isFull = guild.memberCount >= 4;

    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = AppBreakpoints.isMobile(screenWidth);
    final bodyPad = isMobile ? 12.0 : (screenWidth < 900 ? 16.0 : 24.0);

    return SingleChildScrollView(
      padding: EdgeInsets.all(bodyPad),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ---- Guild Header ----
        Container(
          padding: EdgeInsets.all(isMobile ? 14 : 20),
          decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: rarityColor.withValues(alpha: 0.3)),
            boxShadow: [BoxShadow(color: rarityColor.withValues(alpha: 0.06), blurRadius: 12)],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Guild icon
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: rarityColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: rarityColor.withValues(alpha: 0.3)),
                ),
                child: Center(child: Icon(guild.roleIconData, color: guild.roleIconColor, size: 26)),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(guild.name, style: TextStyle(color: AppTheme.textH, fontSize: isMobile ? 18 : 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Wrap(spacing: 10, runSpacing: 6, children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: rarityColor.withValues(alpha: 0.15),
                      border: Border.all(color: rarityColor.withValues(alpha: 0.4)),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      guild.rarity.toUpperCase(),
                      style: TextStyle(color: rarityColor, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                    ),
                  ),
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.group_rounded, size: 14, color: AppTheme.textM),
                    const SizedBox(width: 4),
                    Text(
                      '${guild.memberCount}/4 members',
                      style: const TextStyle(color: AppTheme.textM, fontSize: 12),
                    ),
                  ]),
                ]),
              ])),
            ]),
            const SizedBox(height: 16),

            // -- Join / Leave / Creator badge
            if (!isCreator) ...[
              if (ctrl.joinLoading.value)
                Container(
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppTheme.card2,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: AppTheme.primary, strokeWidth: 2))),
                )
              else if (isMember)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primary,
                      side: const BorderSide(color: AppTheme.primary, width: 1),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => _onLeave(ctrl, context),
                    icon: const Icon(Icons.exit_to_app_rounded, size: 16),
                    label: const Text('Leave Guild', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                )
              else
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: isFull ? AppTheme.card2 : const Color(0xFF5A8A48),
                      foregroundColor: isFull ? AppTheme.textM : AppTheme.textH,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: isFull ? null : () => ctrl.join(context),
                    icon: Icon(isFull ? Icons.block_rounded : Icons.group_add_rounded, size: 16),
                    label: Text(
                      isFull ? 'Guild is Full' : 'Join Guild',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
            ] else ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.gold.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.gold.withValues(alpha: 0.3)),
                ),
                child: const Row(children: [
                  Icon(Icons.star_rounded, color: AppTheme.gold, size: 16),
                  SizedBox(width: 8),
                  Text(
                    'You are the Guild Master',
                    style: TextStyle(color: AppTheme.gold, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ]),
              ),
            ],
          ]),
        ),
        SizedBox(height: isMobile ? 16 : 24),

        // ---- Guild Stats ----
        _Section(title: 'Guild Stats', icon: Icons.bar_chart_rounded, child: _GuildStatsRow(guild: guild)),
        SizedBox(height: isMobile ? 16 : 24),

        // ---- Formation ----
        _Section(
          title: 'Formation',
          icon: Icons.grid_view_rounded,
          child: guild.members.isEmpty
              ? const _EmptySection(message: 'No members yet', icon: Icons.person_add_outlined)
              : TeamFormationWidget(members: guild.members),
        ),
        SizedBox(height: isMobile ? 16 : 24),

        // ---- Active Synergies ----
        _Section(title: 'Active Synergies', icon: Icons.bolt_rounded, child: SynergyBadgeList(synergies: d.synergy)),
        SizedBox(height: isMobile ? 16 : 24),

        // ---- Combined Bonuses ----
        if (d.bonuses.isNotEmpty) ...[
          _Section(title: 'Combined Stat Bonuses', icon: Icons.trending_up_rounded, child: CombinedBonusBar(bonuses: d.bonuses)),
          SizedBox(height: isMobile ? 16 : 24),
        ],

        // ---- Members List ----
        _Section(
          title: 'Members',
          icon: Icons.people_rounded,
          child: guild.members.isEmpty
              ? const _EmptySection(message: 'No members yet', icon: Icons.group_outlined)
              : Column(children: guild.members.map((m) => _MemberRow(member: m)).toList()),
        ),

        // ---- Guild Master CTA ----
        if (guild.members.isNotEmpty) ...[
          const SizedBox(height: 28),
          _GuildMasterCTA(onPressed: () => _openInGuildMaster(ctrl, context)),
        ],
        const SizedBox(height: 32),
      ]),
    );
  }

  Widget _buildLoadingSkeleton() {
    return ShimmerScope(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Header skeleton
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.border),
            ),
            child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                ShimmerBox(width: 48, height: 48, radius: 12, color: AppTheme.card2),
                SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  ShimmerBox(width: 180, height: 20, radius: 4, color: AppTheme.card2),
                  SizedBox(height: 8),
                  Row(children: [
                    ShimmerBox(width: 64, height: 18, radius: 6, color: AppTheme.card2),
                    SizedBox(width: 10),
                    ShimmerBox(width: 80, height: 14, radius: 4, color: AppTheme.card2),
                  ]),
                ])),
              ]),
              SizedBox(height: 16),
              ShimmerBox(width: double.infinity, height: 42, radius: 10, color: AppTheme.card2),
            ]),
          ),
          const SizedBox(height: 24),

          // Stats skeleton
          const ShimmerBox(width: 100, height: 12, radius: 4, color: AppTheme.card2),
          const SizedBox(height: 12),
          const ShimmerBox(width: double.infinity, height: 80, radius: 12, color: AppTheme.card2),
          const SizedBox(height: 24),

          // Formation skeleton
          const ShimmerBox(width: 90, height: 12, radius: 4, color: AppTheme.card2),
          const SizedBox(height: 12),
          const ShimmerBox(width: double.infinity, height: 160, radius: 12, color: AppTheme.card2),
          const SizedBox(height: 24),

          // Members skeleton
          const ShimmerBox(width: 80, height: 12, radius: 4, color: AppTheme.card2),
          const SizedBox(height: 12),
          const ShimmerBox(width: double.infinity, height: 60, radius: 10, color: AppTheme.card2),
          const SizedBox(height: 10),
          const ShimmerBox(width: double.infinity, height: 60, radius: 10, color: AppTheme.card2),
        ]),
      ),
    );
  }

  void _openInGuildMaster(_GuildDetailCtrl ctrl, BuildContext context) {
    final d = ctrl.detail.value;
    if (d == null) return;
    final agents = d.guild.members
        .where((m) => m.agent != null)
        .map((m) => <String, dynamic>{
          'id': m.agentId,
          'title': m.agent!.title,
          'character_type': m.agent!.characterType.name,
          'subclass': m.agent!.subclass.name,
        })
        .toList();
    context.go('/guild-master', extra: <String, dynamic>{
      'guild_name': d.guild.name,
      'agents': agents,
    });
  }

  Future<void> _onLeave(_GuildDetailCtrl ctrl, BuildContext context) async {
    if (!ApiService.instance.isAuthenticated) { _showWalletDialog(context); return; }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Leave Guild?', style: TextStyle(color: AppTheme.textH, fontWeight: FontWeight.bold)),
        content: Text(
          'Are you sure you want to leave "${ctrl.detail.value?.guild.name}"?',
          style: const TextStyle(color: AppTheme.textB),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textM)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: AppTheme.textH),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final ok = await ctrl.leave();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok ? 'Left guild.' : 'Failed to leave guild.'),
        backgroundColor: ok ? AppTheme.card2 : AppTheme.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
    }
  }

  static void _showWalletDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Wallet Required', style: TextStyle(color: AppTheme.textH, fontWeight: FontWeight.bold)),
        content: const Text('Connect your wallet to join or leave guilds.', style: TextStyle(color: AppTheme.textB)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textM)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: AppTheme.textH),
            onPressed: () { Navigator.pop(context); context.go('/wallet'); },
            child: const Text('Connect Wallet'),
          ),
        ],
      ),
    );
  }

  static Color _rarityColor(String rarity) => switch (rarity.toLowerCase()) {
    'legendary' => AppTheme.gold,
    'epic'      => const Color(0xFF9B7B1A),
    'rare'      => const Color(0xFF5F8ABA),
    'uncommon'  => const Color(0xFF5A8A48),
    _           => AppTheme.textM,
  };
}

// -- Local micro-controller -------------------------------------------------------

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
    if (!ApiService.instance.isAuthenticated) { _GuildDetailScreenState._showWalletDialog(context); return; }
    joinLoading.value = true;
    final ok = await ApiService.instance.joinGuild(guildId);
    joinLoading.value = false;
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok ? 'Joined guild successfully!' : 'Failed to join guild. Guild may be full.'),
        backgroundColor: ok ? const Color(0xFF5A8A48) : AppTheme.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
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

// -- Supporting widgets ---------------------------------------------------------------

class _AppBarAction extends StatefulWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onPressed;
  const _AppBarAction({required this.icon, required this.color, required this.tooltip, required this.onPressed});

  @override
  State<_AppBarAction> createState() => _AppBarActionState();
}

class _AppBarActionState extends State<_AppBarAction> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Tooltip(
        message: widget.tooltip,
        child: IconButton(
          icon: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: _hovered ? widget.color.withValues(alpha: 0.12) : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(widget.icon, color: widget.color, size: 20),
          ),
          onPressed: widget.onPressed,
        ),
      ),
    );
  }
}

class _GuildStatsRow extends StatelessWidget {
  final GuildModel guild;
  const _GuildStatsRow({required this.guild});

  @override
  Widget build(BuildContext context) {
    final isFull = guild.memberCount >= 4;
    final slotColor = isFull ? AppTheme.primary : const Color(0xFF5A8A48);
    final isMobile = AppBreakpoints.isMobile(MediaQuery.sizeOf(context).width);
    return Container(
      padding: EdgeInsets.all(isMobile ? 10 : 16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(children: [
        _StatCell(icon: Icons.group_rounded, iconColor: slotColor, label: 'Members', value: '${guild.memberCount}/4'),
        _VertDivider(),
        _StatCell(icon: Icons.calendar_today_rounded, iconColor: AppTheme.textM, label: 'Created', value: _formatDate(guild.createdAt)),
        _VertDivider(),
        _StatCell(icon: Icons.emoji_events_rounded, iconColor: AppTheme.gold, label: 'Status', value: isFull ? 'Full' : 'Recruiting', valueColor: slotColor),
      ]),
    );
  }

  static String _formatDate(DateTime dt) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
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
  Widget build(BuildContext context) => Expanded(child: Column(children: [
    Icon(icon, color: iconColor, size: 20),
    const SizedBox(height: 6),
    Text(value, style: TextStyle(color: valueColor ?? AppTheme.textH, fontWeight: FontWeight.bold, fontSize: 13)),
    const SizedBox(height: 3),
    Text(label, style: const TextStyle(color: AppTheme.textM, fontSize: 10)),
  ]));
}

class _VertDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(width: 1, height: 40, color: AppTheme.border, margin: const EdgeInsets.symmetric(horizontal: 12));
}

class _Section extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  const _Section({required this.title, required this.icon, required this.child});

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [
      Icon(icon, size: 14, color: AppTheme.textM),
      const SizedBox(width: 6),
      Text(
        title.toUpperCase(),
        style: const TextStyle(color: AppTheme.textM, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1),
      ),
    ]),
    const SizedBox(height: 12),
    child,
  ]);
}

class _EmptySection extends StatelessWidget {
  final String message;
  final IconData icon;
  const _EmptySection({required this.message, required this.icon});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(vertical: 24),
    decoration: BoxDecoration(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AppTheme.border),
    ),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, color: AppTheme.textM, size: 28),
      const SizedBox(height: 8),
      Text(message, style: const TextStyle(color: AppTheme.textM, fontSize: 12)),
    ]),
  );
}

class _GuildMasterCTA extends StatefulWidget {
  final VoidCallback onPressed;
  const _GuildMasterCTA({required this.onPressed});

  @override
  State<_GuildMasterCTA> createState() => _GuildMasterCTAState();
}

class _GuildMasterCTAState extends State<_GuildMasterCTA> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF6366F1).withValues(alpha: _hovered ? 0.2 : 0.1),
                const Color(0xFF8B5CF6).withValues(alpha: _hovered ? 0.15 : 0.06),
              ],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: _hovered ? 0.6 : 0.35)),
            boxShadow: _hovered
                ? [BoxShadow(color: const Color(0xFF6366F1).withValues(alpha: 0.15), blurRadius: 12)]
                : null,
          ),
          child: Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [BoxShadow(color: const Color(0xFF6366F1).withValues(alpha: 0.25), blurRadius: 12)],
              ),
              child: const Icon(Icons.auto_awesome, color: Color(0xFF8B5CF6), size: 22),
            ),
            const SizedBox(width: 14),
            const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Open in Guild Master', style: TextStyle(color: AppTheme.textH, fontSize: 14, fontWeight: FontWeight.bold)),
              SizedBox(height: 3),
              Text('Chat with your team and get AI-powered insights', style: TextStyle(color: AppTheme.textM, fontSize: 12)),
            ])),
            const SizedBox(width: 8),
            AnimatedSlide(
              duration: const Duration(milliseconds: 200),
              offset: Offset(_hovered ? 0.15 : 0, 0),
              child: const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFF6366F1), size: 14),
            ),
          ]),
        ),
      ),
    );
  }
}

class _MemberRow extends StatefulWidget {
  final GuildMemberModel member;
  const _MemberRow({required this.member});

  @override
  State<_MemberRow> createState() => _MemberRowState();
}

class _MemberRowState extends State<_MemberRow> {
  bool _hovered = false;

  IconData get _roleIconData => switch (widget.member.role) {
    'Brain'     => Icons.psychology,
    'Shield'    => Icons.shield,
    'Scout'     => Icons.bolt,
    'Innovator' => Icons.lightbulb_outline,
    'Striker'   => Icons.gps_fixed,
    _           => Icons.circle,
  };

  String _shortWallet(String w) => w.length <= 12 ? w : '${w.substring(0, 6)}...${w.substring(w.length - 4)}';

  String _formatJoined(DateTime dt) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return 'Joined ${months[dt.month - 1]} ${dt.day}';
  }

  @override
  Widget build(BuildContext context) {
    final agent = widget.member.agent;
    if (agent == null) return const SizedBox.shrink();
    final typeColor = agent.characterType.primaryColor;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _hovered ? AppTheme.card2 : AppTheme.card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _hovered ? typeColor.withValues(alpha: 0.4) : AppTheme.border),
        ),
        child: Row(children: [
          PixelCharacterWidget(
            characterType: agent.characterType,
            rarity: agent.rarity,
            subclass: agent.subclass,
            size: 36,
            agentId: agent.id,
            generatedImage: agent.generatedImage,
            imageUrl: agent.imageUrl,
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              agent.title,
              style: const TextStyle(color: AppTheme.textH, fontWeight: FontWeight.bold, fontSize: 13),
              maxLines: 1, overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 3),
            Row(children: [
              Icon(_roleIconData, size: 14, color: typeColor),
              const SizedBox(width: 4),
              Text(
                '${widget.member.role} · ${agent.characterType.displayName}',
                style: TextStyle(color: typeColor, fontSize: 10),
              ),
            ]),
            const SizedBox(height: 4),
            Row(children: [
              const Icon(Icons.account_balance_wallet_outlined, size: 10, color: AppTheme.textM),
              const SizedBox(width: 3),
              Text(_shortWallet(agent.creatorWallet), style: const TextStyle(color: AppTheme.textM, fontSize: 10)),
              const SizedBox(width: 10),
              const Icon(Icons.schedule_rounded, size: 10, color: AppTheme.textM),
              const SizedBox(width: 3),
              Text(_formatJoined(widget.member.joinedAt), style: const TextStyle(color: AppTheme.textM, fontSize: 10)),
            ]),
          ])),
        ]),
      ),
    );
  }
}
