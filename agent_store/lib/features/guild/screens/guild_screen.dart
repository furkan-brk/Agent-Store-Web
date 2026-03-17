import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme.dart';
import '../../../controllers/guild_controller.dart';
import '../../../shared/models/guild_model.dart';
import '../../../shared/services/api_service.dart';
import '../../../shared/widgets/skeleton_widgets.dart';
import '../../character/character_types.dart';

class GuildScreen extends StatefulWidget {
  const GuildScreen({super.key});

  @override
  State<GuildScreen> createState() => _GuildScreenState();
}

class _GuildScreenState extends State<GuildScreen> {
  late final GuildController _ctrl;
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _ctrl = Get.isRegistered<GuildController>()
        ? Get.find<GuildController>()
        : Get.put(GuildController(), permanent: true);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<GuildModel> get _filteredGuilds {
    if (_searchQuery.isEmpty) return _ctrl.guilds.toList();
    final q = _searchQuery.toLowerCase();
    return _ctrl.guilds.where((g) =>
      g.name.toLowerCase().contains(q) ||
      g.rarity.toLowerCase().contains(q)
    ).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final filtered = _filteredGuilds;
      return Scaffold(
        backgroundColor: AppTheme.bg,
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // -- Page header with icon
            Row(children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.groups_rounded, color: AppTheme.primary, size: 22),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Guilds', style: TextStyle(color: AppTheme.textH, fontSize: 24, fontWeight: FontWeight.bold)),
                  SizedBox(height: 2),
                  Text('2-4 agents united for synergy bonuses', style: TextStyle(color: AppTheme.textM, fontSize: 13)),
                ]),
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: AppTheme.textH,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => _onCreateGuild(context),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Create Guild', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ]),
            const SizedBox(height: 20),

            // -- Search bar
            SizedBox(
              height: 42,
              child: TextField(
                controller: _searchCtrl,
                style: const TextStyle(color: AppTheme.textH, fontSize: 14),
                onChanged: (v) => setState(() => _searchQuery = v),
                decoration: InputDecoration(
                  hintText: 'Search guilds...',
                  hintStyle: const TextStyle(color: AppTheme.textM, fontSize: 13),
                  filled: true,
                  fillColor: AppTheme.card,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.textM, size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18, color: AppTheme.textM),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.border)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.border)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.primary, width: 1.5)),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // -- Content area
            if (_ctrl.isLoading.value)
              Expanded(
                child: ShimmerScope(
                  child: GridView.builder(
                    padding: EdgeInsets.zero,
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 320, mainAxisExtent: 190,
                      crossAxisSpacing: 16, mainAxisSpacing: 16,
                    ),
                    itemCount: 8,
                    itemBuilder: (_, __) => const _GuildCardSkeleton(),
                  ),
                ),
              )
            else if (_ctrl.error.value != null)
              Expanded(child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 64, height: 64,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.error_outline_rounded, color: AppTheme.primary, size: 32),
                ),
                const SizedBox(height: 16),
                const Text('Something went wrong', style: TextStyle(color: AppTheme.textH, fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Text(
                  _ctrl.error.value!,
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
                  onPressed: _ctrl.load,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Retry'),
                ),
              ])))
            else if (_ctrl.guilds.isEmpty)
              Expanded(child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(
                    color: AppTheme.card,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: const Icon(Icons.groups_outlined, color: AppTheme.textM, size: 40),
                ),
                const SizedBox(height: 20),
                const Text('No guilds yet', style: TextStyle(color: AppTheme.textH, fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text('Be the first to create one!', style: TextStyle(color: AppTheme.textM, fontSize: 14)),
                const SizedBox(height: 24),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: AppTheme.textH,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => _onCreateGuild(context),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Create Guild'),
                ),
              ])))
            else if (filtered.isEmpty && _searchQuery.isNotEmpty)
              Expanded(child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.search_off_rounded, color: AppTheme.textM, size: 48),
                const SizedBox(height: 16),
                Text(
                  'No guilds matching "$_searchQuery"',
                  style: const TextStyle(color: AppTheme.textH, fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                const Text('Try a different search term', style: TextStyle(color: AppTheme.textM, fontSize: 13)),
              ])))
            else
              Expanded(child: RefreshIndicator(
                onRefresh: _ctrl.load,
                color: AppTheme.primary,
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 320, mainAxisExtent: 190,
                    crossAxisSpacing: 16, mainAxisSpacing: 16,
                  ),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) => _GuildCard(guild: filtered[i]),
                ),
              )),
          ]),
        ),
      );
    });
  }

  void _onCreateGuild(BuildContext context) {
    if (!ApiService.instance.isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Connect your wallet to create a guild'),
        backgroundColor: AppTheme.card2,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        action: SnackBarAction(label: 'Connect', textColor: AppTheme.gold, onPressed: () => context.go('/wallet')),
      ));
      return;
    }
    context.go('/guild/create');
  }
}

// -- Guild card with hover state --

class _GuildCard extends StatefulWidget {
  final GuildModel guild;
  const _GuildCard({required this.guild});

  @override
  State<_GuildCard> createState() => _GuildCardState();
}

class _GuildCardState extends State<_GuildCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final guild = widget.guild;
    final rarityColor = _rarityColor(guild.rarity);
    final statusLabel = guild.memberCount >= 4 ? 'Full' : 'Recruiting';
    final statusColor = guild.memberCount >= 4 ? AppTheme.primary : const Color(0xFF5A8A48);
    final categoryLabel = _categoryLabel(guild);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () => context.go('/guild/${guild.id}'),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _hovered ? AppTheme.card2 : AppTheme.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _hovered ? rarityColor.withValues(alpha: 0.5) : AppTheme.border),
            boxShadow: _hovered
                ? [BoxShadow(color: rarityColor.withValues(alpha: 0.12), blurRadius: 16, offset: const Offset(0, 4))]
                : [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 4)],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // -- Header: icon + name
            Row(children: [
              Text(guild.roleIcon, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Expanded(child: Text(
                guild.name,
                style: const TextStyle(color: AppTheme.textH, fontWeight: FontWeight.bold, fontSize: 15),
                maxLines: 1, overflow: TextOverflow.ellipsis,
              )),
            ]),
            const SizedBox(height: 10),

            // -- Rarity + category chips
            Wrap(spacing: 8, runSpacing: 4, children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: rarityColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: rarityColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  guild.rarity.toUpperCase(),
                  style: TextStyle(color: rarityColor, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Text(
                  categoryLabel,
                  style: const TextStyle(color: AppTheme.textM, fontSize: 9, fontWeight: FontWeight.w500),
                ),
              ),
            ]),
            const Spacer(),

            // -- Footer: member count + status + chevron
            Row(children: [
              const Icon(Icons.group_rounded, size: 14, color: AppTheme.textM),
              const SizedBox(width: 4),
              Text(
                '${guild.memberCount}/4 members',
                style: const TextStyle(color: AppTheme.textM, fontSize: 11),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: statusColor.withValues(alpha: 0.25)),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(color: statusColor, fontSize: 9, fontWeight: FontWeight.bold),
                ),
              ),
              const Spacer(),
              AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: _hovered ? 1.0 : 0.4,
                child: const Icon(Icons.chevron_right_rounded, size: 18, color: AppTheme.textM),
              ),
            ]),
          ]),
        ),
      ),
    );
  }

  String _categoryLabel(GuildModel guild) {
    if (guild.members.isEmpty) return 'Open Roster';
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
    'legendary' => AppTheme.gold,
    'epic'      => const Color(0xFF9B7B1A),
    'rare'      => const Color(0xFF5F8ABA),
    'uncommon'  => const Color(0xFF5A8A48),
    _           => AppTheme.textM,
  };
}

// -- Skeleton card matching the dark theme --

class _GuildCardSkeleton extends StatelessWidget {
  const _GuildCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Icon + name row
        Row(children: [
          ShimmerBox(width: 30, height: 30, radius: 6, color: AppTheme.card2),
          SizedBox(width: 10),
          Expanded(child: ShimmerBox(width: double.infinity, height: 14, radius: 4, color: AppTheme.card2)),
        ]),
        SizedBox(height: 12),
        // Tag chips row
        Row(children: [
          ShimmerBox(width: 64, height: 20, radius: 6, color: AppTheme.card2),
          SizedBox(width: 8),
          ShimmerBox(width: 76, height: 20, radius: 6, color: AppTheme.card2),
        ]),
        Spacer(),
        // Footer: members count + status badge
        Row(children: [
          ShimmerBox(width: 96, height: 12, radius: 4, color: AppTheme.card2),
          Spacer(),
          ShimmerBox(width: 54, height: 12, radius: 4, color: AppTheme.card2),
        ]),
      ]),
    );
  }
}
