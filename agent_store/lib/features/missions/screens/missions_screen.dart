import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../shared/models/mission_model.dart';
import '../../../shared/services/mission_service.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/page_header.dart';
import '../../../shared/widgets/skeleton_widgets.dart';

class _CategoryDef {
  final String name;
  final IconData icon;
  final Color color;
  const _CategoryDef(this.name, this.icon, this.color);
}

const _kCategories = [
  _CategoryDef('All', Icons.apps, AppTheme.textM),
  _CategoryDef('Code', Icons.code, Colors.blue),
  _CategoryDef('Writing', Icons.edit_note, Colors.green),
  _CategoryDef('Data', Icons.analytics, Colors.orange),
  _CategoryDef('Design', Icons.palette, Colors.pink),
  _CategoryDef('Research', Icons.science, Colors.purple),
];

class MissionsScreen extends StatefulWidget {
  const MissionsScreen({super.key});

  @override
  State<MissionsScreen> createState() => _MissionsScreenState();
}

class _MissionsScreenState extends State<MissionsScreen> {
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
  String _selectedCategory = 'All';
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadMissions();
  }

  Future<void> _loadMissions() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await MissionService.instance.refresh();
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Failed to load missions: $e');
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  static String _categorize(MissionModel m) {
    final text = '${m.title} ${m.prompt}'.toLowerCase();
    if (text.contains('code') || text.contains('api') || text.contains('debug') ||
        text.contains('test') || text.contains('function') || text.contains('bug')) {
      return 'Code';
    }
    if (text.contains('write') || text.contains('blog') || text.contains('email') ||
        text.contains('copy') || text.contains('content') || text.contains('article')) {
      return 'Writing';
    }
    if (text.contains('data') || text.contains('analy') || text.contains('report') ||
        text.contains('metric') || text.contains('dashboard')) {
      return 'Data';
    }
    if (text.contains('design') || text.contains('ui') || text.contains('ux') ||
        text.contains('layout') || text.contains('style')) {
      return 'Design';
    }
    if (text.contains('research') || text.contains('study') || text.contains('investigat') ||
        text.contains('review') || text.contains('compare')) {
      return 'Research';
    }
    return 'Code';
  }

  int get _thisWeekCount {
    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    return MissionService.instance.missions
        .where((m) => m.createdAt.isAfter(cutoff))
        .length;
  }

  List<MissionModel> get _filteredMissions {
    var all = MissionService.instance.missions;
    if (_selectedCategory != 'All') {
      all = all.where((m) => _categorize(m) == _selectedCategory).toList();
    }
    if (_searchQuery.isEmpty) return all;
    final q = _searchQuery.toLowerCase();
    return all
        .where((m) =>
            m.title.toLowerCase().contains(q) ||
            m.slug.toLowerCase().contains(q))
        .toList();
  }

  String? get _mostUsedName {
    final all = MissionService.instance.missions;
    if (all.isEmpty) return null;
    MissionModel best = all.first;
    for (final m in all) {
      if (m.useCount > best.useCount) best = m;
    }
    return best.useCount > 0 ? best.title : null;
  }

  Future<void> _deleteMission(MissionModel mission) async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Delete Mission?',
      message: 'Are you sure you want to delete "#${mission.slug}"? This cannot be undone.',
      confirmLabel: 'Delete',
      isDestructive: true,
      icon: Icons.delete_outline_rounded,
    );
    if (!confirmed) return;
    await MissionService.instance.deleteMission(mission.id);
    if (mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Mission "#${mission.slug}" deleted'),
        backgroundColor: AppTheme.card2,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
    }
  }

  Future<void> _duplicateMission(MissionModel m) async {
    await MissionService.instance.addMission(
      title: '${m.title} (copy)',
      prompt: m.prompt,
    );
    if (mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Mission duplicated'),
        backgroundColor: AppTheme.card2,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
    }
  }

  void _showCreateDialog() {
    final titleCtrl = TextEditingController();
    final promptCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => _CreateMissionDialog(
        titleCtrl: titleCtrl,
        promptCtrl: promptCtrl,
        onSave: () async {
          final title = titleCtrl.text.trim();
          final prompt = promptCtrl.text.trim();
          if (title.isEmpty || prompt.isEmpty) return;
          Navigator.of(ctx).pop();
          await MissionService.instance.addMission(title: title, prompt: prompt);
          if (mounted) {
            setState(() {});
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: const Text('Mission created. Use with #slug in chats.'),
              backgroundColor: AppTheme.card2,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ));
          }
        },
      ),
    );
  }

  void _showEditDialog(MissionModel m) {
    final titleCtrl = TextEditingController(text: m.title);
    final promptCtrl = TextEditingController(text: m.prompt);

    showDialog(
      context: context,
      builder: (ctx) => _CreateMissionDialog(
        titleCtrl: titleCtrl,
        promptCtrl: promptCtrl,
        isEdit: true,
        onSave: () async {
          final title = titleCtrl.text.trim();
          final prompt = promptCtrl.text.trim();
          if (title.isEmpty || prompt.isEmpty) return;
          Navigator.of(ctx).pop();
          await MissionService.instance.updateMission(
            id: m.id,
            title: title,
            prompt: prompt,
          );
          if (mounted) {
            setState(() {});
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: const Text('Mission updated'),
              backgroundColor: AppTheme.card2,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ));
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth <= 900;
    final bodyPad = isMobile ? 12.0 : (isTablet ? 16.0 : 24.0);
    final missions = MissionService.instance.missions;
    final filtered = _filteredMissions;

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Padding(
        padding: EdgeInsets.all(bodyPad),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // -- Page header
          PageHeader(
            icon: Icons.flag_rounded,
            title: 'Missions',
            subtitle: 'Save reusable task definitions here. Reference them in chats with #slug.',
            trailing: isMobile
                ? IconButton(
                    style: IconButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: AppTheme.textH,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _showCreateDialog,
                    icon: const Icon(Icons.add_rounded, size: 20),
                    tooltip: 'Create Mission',
                  )
                : FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: AppTheme.textH,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _showCreateDialog,
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Create Mission', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
          ),
          SizedBox(height: isMobile ? 14 : 20),

          // -- Search bar
          SizedBox(
            height: 42,
            child: TextField(
              controller: _searchCtrl,
              style: const TextStyle(color: AppTheme.textH, fontSize: 14),
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: InputDecoration(
                hintText: 'Search missions...',
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
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppTheme.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppTheme.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
                ),
              ),
            ),
          ),
          SizedBox(height: isMobile ? 10 : 14),

          // -- Stats row
          if (!_isLoading && missions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Wrap(spacing: 10, runSpacing: 8, children: [
                _StatChip(
                  icon: Icons.flag_rounded,
                  label: '${missions.length} mission${missions.length == 1 ? '' : 's'}',
                ),
                _StatChip(
                  icon: Icons.calendar_today_rounded,
                  label: '$_thisWeekCount this week',
                ),
                if (_mostUsedName != null)
                  _StatChip(
                    icon: Icons.trending_up_rounded,
                    label: _mostUsedName!,
                  ),
              ]),
            ),

          // -- Sync status banner
          ValueListenableBuilder<SyncStatus>(
            valueListenable: MissionService.instance.syncStatusNotifier,
            builder: (_, status, __) => switch (status) {
              SyncStatus.failed => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppTheme.gold.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.gold.withValues(alpha: 0.3)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.cloud_off_rounded, color: AppTheme.gold, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          MissionService.instance.syncError ?? 'Sync failed',
                          style: const TextStyle(color: AppTheme.gold, fontSize: 13),
                        ),
                      ),
                      TextButton(
                        onPressed: () => MissionService.instance.forceSyncToBackend(),
                        child: const Text('Retry Sync', style: TextStyle(color: AppTheme.gold, fontWeight: FontWeight.w600)),
                      ),
                    ]),
                  ),
                ),
              SyncStatus.syncing => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: const LinearProgressIndicator(
                      minHeight: 3,
                      color: AppTheme.primary,
                      backgroundColor: AppTheme.border,
                    ),
                  ),
                ),
              _ => const SizedBox.shrink(),
            },
          ),

          // -- Category filter chips
          if (!_isLoading && missions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  for (final cat in _kCategories) ...[
                    if (cat != _kCategories.first) const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => setState(() => _selectedCategory = cat.name),
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: _selectedCategory == cat.name
                                ? cat.color.withValues(alpha: 0.15)
                                : AppTheme.card,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _selectedCategory == cat.name ? cat.color : AppTheme.border,
                            ),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(cat.icon, size: 14,
                                color: _selectedCategory == cat.name ? cat.color : AppTheme.textM),
                            const SizedBox(width: 6),
                            Text(
                              cat.name,
                              style: TextStyle(
                                color: _selectedCategory == cat.name ? cat.color : AppTheme.textM,
                                fontSize: 12,
                                fontWeight: _selectedCategory == cat.name ? FontWeight.w600 : FontWeight.normal,
                              ),
                            ),
                          ]),
                        ),
                      ),
                    ),
                  ],
                ]),
              ),
            ),

          // -- Content area
          if (_isLoading)
            Expanded(
              child: ShimmerScope(
                child: ListView.separated(
                  padding: EdgeInsets.zero,
                  itemCount: 4,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, __) => const _MissionCardSkeleton(),
                ),
              ),
            )
          else if (_error != null)
            Expanded(
              child: ErrorState(
                message: _error!,
                onRetry: _loadMissions,
              ),
            )
          else if (missions.isEmpty)
            Expanded(
              child: Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppTheme.card,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: const Icon(Icons.flag_outlined, color: AppTheme.textM, size: 40),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'No missions yet',
                    style: TextStyle(color: AppTheme.textH, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Create your first reusable task definition',
                    style: TextStyle(color: AppTheme.textM, fontSize: 14),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: AppTheme.textH,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _showCreateDialog,
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Create Mission'),
                  ),
                ]),
              ),
            )
          else if (filtered.isEmpty && (_searchQuery.isNotEmpty || _selectedCategory != 'All'))
            Expanded(
              child: Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.search_off_rounded, color: AppTheme.textM, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    _searchQuery.isNotEmpty
                        ? 'No missions matching "$_searchQuery"'
                        : 'No $_selectedCategory missions',
                    style: const TextStyle(
                      color: AppTheme.textH,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _searchQuery.isNotEmpty
                        ? 'Try a different search term'
                        : 'Try a different category',
                    style: const TextStyle(color: AppTheme.textM, fontSize: 13),
                  ),
                ]),
              ),
            )
          else
            Expanded(
              child: ListView.separated(
                padding: EdgeInsets.zero,
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  final m = filtered[i];
                  return _MissionCard(
                    mission: m,
                    onEdit: () => _showEditDialog(m),
                    onDuplicate: () => _duplicateMission(m),
                    onDelete: () => _deleteMission(m),
                  );
                },
              ),
            ),
        ]),
      ),
    );
  }
}

// -- Stat chip widget --

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _StatChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: AppTheme.textM),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            style: const TextStyle(color: AppTheme.textB, fontSize: 12),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ]),
    );
  }
}

// -- Mission card with hover state --

class _MissionCard extends StatefulWidget {
  final MissionModel mission;
  final VoidCallback onEdit;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;

  const _MissionCard({
    required this.mission,
    required this.onEdit,
    required this.onDuplicate,
    required this.onDelete,
  });

  @override
  State<_MissionCard> createState() => _MissionCardState();
}

class _MissionCardState extends State<_MissionCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final m = widget.mission;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.all(isMobile ? 12 : 16),
        decoration: BoxDecoration(
          color: _hovered ? AppTheme.card2 : AppTheme.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _hovered ? AppTheme.gold.withValues(alpha: 0.5) : AppTheme.border,
          ),
          boxShadow: _hovered
              ? [BoxShadow(color: AppTheme.gold.withValues(alpha: 0.10), blurRadius: 16, offset: const Offset(0, 4))]
              : [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 4)],
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Left icon
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.assignment_rounded, color: AppTheme.primary, size: 18),
          ),
          const SizedBox(width: 12),

          // Center content
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                '#${m.slug}',
                style: const TextStyle(
                  color: AppTheme.gold,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                m.title,
                style: const TextStyle(
                  color: AppTheme.textH,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                m.prompt,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppTheme.textM, fontSize: 12, height: 1.4),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Text(
                  'Used ${m.useCount}x',
                  style: const TextStyle(color: AppTheme.textM, fontSize: 10, fontWeight: FontWeight.w500),
                ),
              ),
            ]),
          ),
          const SizedBox(width: 8),

          // Right action buttons
          if (isMobile)
            PopupMenuButton<String>(
              icon: Icon(
                Icons.more_vert_rounded,
                size: 20,
                color: _hovered ? AppTheme.textH : AppTheme.textM,
              ),
              color: AppTheme.card2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: const BorderSide(color: AppTheme.border),
              ),
              onSelected: (v) {
                switch (v) {
                  case 'edit':
                    widget.onEdit();
                  case 'duplicate':
                    widget.onDuplicate();
                  case 'delete':
                    widget.onDelete();
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'edit', child: Row(children: [
                  Icon(Icons.edit_outlined, size: 16, color: AppTheme.textB),
                  SizedBox(width: 8),
                  Text('Edit', style: TextStyle(color: AppTheme.textH, fontSize: 13)),
                ])),
                const PopupMenuItem(value: 'duplicate', child: Row(children: [
                  Icon(Icons.copy_outlined, size: 16, color: AppTheme.textB),
                  SizedBox(width: 8),
                  Text('Duplicate', style: TextStyle(color: AppTheme.textH, fontSize: 13)),
                ])),
                const PopupMenuItem(value: 'delete', child: Row(children: [
                  Icon(Icons.delete_outline, size: 16, color: AppTheme.primary),
                  SizedBox(width: 8),
                  Text('Delete', style: TextStyle(color: AppTheme.primary, fontSize: 13)),
                ])),
              ],
            )
          else
            Column(mainAxisSize: MainAxisSize.min, children: [
              _ActionIcon(
                icon: Icons.edit_outlined,
                tooltip: 'Edit',
                onTap: widget.onEdit,
                hovered: _hovered,
              ),
              _ActionIcon(
                icon: Icons.copy_outlined,
                tooltip: 'Duplicate',
                onTap: widget.onDuplicate,
                hovered: _hovered,
              ),
              _ActionIcon(
                icon: Icons.delete_outline,
                tooltip: 'Delete',
                onTap: widget.onDelete,
                hovered: _hovered,
                color: AppTheme.primary,
              ),
            ]),
        ]),
      ),
    );
  }
}

// -- Small action icon button for card actions --

class _ActionIcon extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool hovered;
  final Color? color;

  const _ActionIcon({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    required this.hovered,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: hovered ? 1.0 : 0.4,
      child: IconButton(
        icon: Icon(icon, size: 17, color: color ?? AppTheme.textB),
        tooltip: tooltip,
        onPressed: onTap,
        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        padding: EdgeInsets.zero,
        splashRadius: 16,
      ),
    );
  }
}

// -- Create / Edit mission dialog --

class _CreateMissionDialog extends StatelessWidget {
  final TextEditingController titleCtrl;
  final TextEditingController promptCtrl;
  final VoidCallback onSave;
  final bool isEdit;

  const _CreateMissionDialog({
    required this.titleCtrl,
    required this.promptCtrl,
    required this.onSave,
    this.isEdit = false,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppTheme.border),
      ),
      title: Text(
        isEdit ? 'Edit Mission' : 'Create Mission',
        style: const TextStyle(color: AppTheme.textH, fontSize: 18, fontWeight: FontWeight.bold),
      ),
      content: SizedBox(
        width: 440,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: titleCtrl,
            style: const TextStyle(color: AppTheme.textH, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Mission title (e.g. Secure API audit)',
              hintStyle: const TextStyle(color: AppTheme.textM, fontSize: 13),
              filled: true,
              fillColor: AppTheme.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppTheme.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppTheme.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: promptCtrl,
            style: const TextStyle(color: AppTheme.textH, fontSize: 14),
            minLines: 3,
            maxLines: 8,
            decoration: InputDecoration(
              hintText: 'Mission prompt content...',
              hintStyle: const TextStyle(color: AppTheme.textM, fontSize: 13),
              filled: true,
              fillColor: AppTheme.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppTheme.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppTheme.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
              ),
            ),
          ),
        ]),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel', style: TextStyle(color: AppTheme.textM)),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AppTheme.primary,
            foregroundColor: AppTheme.textH,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: onSave,
          child: Text(isEdit ? 'Save' : 'Create'),
        ),
      ],
    );
  }
}

// -- Skeleton card for loading state --

class _MissionCardSkeleton extends StatelessWidget {
  const _MissionCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ShimmerBox(width: 36, height: 36, radius: 8, color: AppTheme.card2),
        SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ShimmerBox(width: 90, height: 12, radius: 4, color: AppTheme.card2),
            SizedBox(height: 6),
            ShimmerBox(width: double.infinity, height: 14, radius: 4, color: AppTheme.card2),
            SizedBox(height: 6),
            ShimmerBox(width: double.infinity, height: 10, radius: 4, color: AppTheme.card2),
            SizedBox(height: 4),
            ShimmerBox(width: 160, height: 10, radius: 4, color: AppTheme.card2),
            SizedBox(height: 8),
            ShimmerBox(width: 60, height: 16, radius: 4, color: AppTheme.card2),
          ]),
        ),
        SizedBox(width: 8),
        Column(mainAxisSize: MainAxisSize.min, children: [
          ShimmerBox(width: 24, height: 24, radius: 4, color: AppTheme.card2),
          SizedBox(height: 4),
          ShimmerBox(width: 24, height: 24, radius: 4, color: AppTheme.card2),
          SizedBox(height: 4),
          ShimmerBox(width: 24, height: 24, radius: 4, color: AppTheme.card2),
        ]),
      ]),
    );
  }
}
