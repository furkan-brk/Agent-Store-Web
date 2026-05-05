import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../features/legend/services/legend_service.dart';
import '../../../shared/services/api_service.dart';
import '../../../shared/services/mission_service.dart';
import '../../../shared/utils/app_snack_bar.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/page_header.dart';
import '../../../shared/widgets/skeleton_widgets.dart' show ShimmerBox, ShimmerScope;

// ─────────────────────────── Category definitions ────────────────────────────

class _Cat {
  final String label;
  final IconData icon;
  const _Cat(this.label, this.icon);
}

const _kCats = [
  _Cat('All', Icons.apps_rounded),
  _Cat('Code', Icons.code_rounded),
  _Cat('Writing', Icons.edit_note_rounded),
  _Cat('Data', Icons.analytics_rounded),
  _Cat('Design', Icons.palette_rounded),
  _Cat('Research', Icons.science_rounded),
];

// ─────────────────────────── Screen ──────────────────────────────────────────

class MissionMarketplaceScreen extends StatefulWidget {
  const MissionMarketplaceScreen({super.key});

  @override
  State<MissionMarketplaceScreen> createState() =>
      _MissionMarketplaceScreenState();
}

class _MissionMarketplaceScreenState extends State<MissionMarketplaceScreen> {
  final _search = TextEditingController();

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _missions = const [];
  String _category = 'All';
  String _query = '';
  final Set<String> _importing = {};
  final Set<String> _openingInLegend = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final cat = _category == 'All' ? null : _category;
      final result = await ApiService.instance.getPublicMissions(cat: cat);
      if (mounted) setState(() { _missions = result; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = '$e'; _loading = false; });
    }
  }

  List<Map<String, dynamic>> get _filtered {
    if (_query.isEmpty) return _missions;
    final q = _query.toLowerCase();
    return _missions
        .where((m) =>
            (m['title'] as String? ?? '').toLowerCase().contains(q) ||
            (m['description'] as String? ?? '').toLowerCase().contains(q))
        .toList();
  }

  Future<void> _import(Map<String, dynamic> mission) async {
    final id = mission['client_id'] as String? ?? '';
    if (id.isEmpty || _importing.contains(id)) return;
    setState(() => _importing.add(id));
    final result = await ApiService.instance.importPublicMission(id);
    if (!mounted) return;
    setState(() => _importing.remove(id));
    if (result != null) {
      await MissionService.instance.refresh();
      if (!mounted) return;
      AppSnackBar.success(context, 'Mission imported to your workspace ✓');
    } else {
      AppSnackBar.error(context, 'Import failed — try again');
    }
  }

  Future<void> _openInLegend(Map<String, dynamic> mission) async {
    final id = mission['client_id'] as String? ?? '';
    if (id.isEmpty || _openingInLegend.contains(id)) return;
    setState(() => _openingInLegend.add(id));
    try {
      final wfId = await ApiService.instance.missionToLegend(id);
      if (!mounted) return;
      if (wfId > 0) {
        await LegendService.instance.refresh();
        if (!mounted) return;
        AppSnackBar.success(context, 'Mission opened in Legend');
        context.go('/legend?id=$wfId');
      } else {
        AppSnackBar.error(context, 'Could not open in Legend — try again');
      }
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.error(context, 'Could not open in Legend: $e');
    } finally {
      if (mounted) setState(() => _openingInLegend.remove(id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageHeader(
            icon: Icons.storefront_rounded,
            title: 'Mission Marketplace',
            subtitle: 'Discover and import community missions',
          ),
          _buildToolbar(),
          const Divider(height: 1, color: AppTheme.border),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildToolbar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search bar
          SizedBox(
            height: 38,
            child: TextField(
              controller: _search,
              onChanged: (v) => setState(() => _query = v),
              style: const TextStyle(color: AppTheme.textH, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Search missions…',
                hintStyle:
                    const TextStyle(color: AppTheme.textM, fontSize: 13),
                prefixIcon: const Icon(Icons.search_rounded,
                    size: 18, color: AppTheme.textM),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded,
                            size: 16, color: AppTheme.textM),
                        onPressed: () {
                          _search.clear();
                          setState(() => _query = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: AppTheme.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppTheme.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppTheme.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide:
                      const BorderSide(color: AppTheme.primary, width: 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Category chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _kCats.map((cat) {
                final selected = _category == cat.label;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    selected: selected,
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(cat.icon,
                            size: 14,
                            color: selected
                                ? AppTheme.bg
                                : AppTheme.textM),
                        const SizedBox(width: 4),
                        Text(cat.label,
                            style: TextStyle(
                                fontSize: 12,
                                color: selected
                                    ? AppTheme.bg
                                    : AppTheme.textM)),
                      ],
                    ),
                    selectedColor: AppTheme.primary,
                    backgroundColor: AppTheme.surface,
                    side: BorderSide(
                        color:
                            selected ? AppTheme.primary : AppTheme.border),
                    onSelected: (_) {
                      setState(() => _category = cat.label);
                      _load();
                    },
                    showCheckmark: false,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return _buildSkeleton();
    if (_error != null) {
      return ErrorState(
        message: _error!,
        onRetry: _load,
      );
    }
    final list = _filtered;
    if (list.isEmpty) {
      return EmptyState(
        icon: Icons.storefront_outlined,
        title: 'No missions found',
        subtitle: _query.isNotEmpty
            ? 'Try different search terms'
            : 'No public missions in this category yet',
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      color: AppTheme.primary,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        itemCount: list.length,
        itemBuilder: (ctx, i) => _MissionCard(
          data: list[i],
          importing: _importing.contains(list[i]['client_id']),
          openingInLegend: _openingInLegend.contains(list[i]['client_id']),
          onImport: () => _import(list[i]),
          onOpenInLegend: () => _openInLegend(list[i]),
        ),
      ),
    );
  }

  Widget _buildSkeleton() {
    return ShimmerScope(
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        itemCount: 6,
        itemBuilder: (_, __) => const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: ShimmerBox(
            width: double.infinity,
            height: 100,
            radius: 10,
            color: AppTheme.card2,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────── Mission card ────────────────────────────────────

class _MissionCard extends StatefulWidget {
  final Map<String, dynamic> data;
  final bool importing;
  final bool openingInLegend;
  final VoidCallback onImport;
  final VoidCallback onOpenInLegend;

  const _MissionCard({
    required this.data,
    required this.importing,
    required this.openingInLegend,
    required this.onImport,
    required this.onOpenInLegend,
  });

  @override
  State<_MissionCard> createState() => _MissionCardState();
}

class _MissionCardState extends State<_MissionCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    final title = d['title'] as String? ?? 'Untitled';
    final description = d['description'] as String? ?? '';
    final category = d['category'] as String? ?? '';
    final creator = d['creator'] as String? ?? '';
    // v3.12 FE-L1-4: stack actions below content on narrow viewports so
    // long titles + buttons don't compete for the same row at 375×667.
    final narrow = MediaQuery.of(context).size.width < AppBreakpoints.narrow;

    final openInLegendBtn = SizedBox(
      width: 34,
      height: 34,
      child: widget.openingInLegend
          ? const Center(
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppTheme.gold),
              ),
            )
          : IconButton(
              tooltip: 'Open in Legend',
              icon: const Icon(Icons.flash_on, color: AppTheme.gold),
              iconSize: 18,
              padding: EdgeInsets.zero,
              constraints:
                  const BoxConstraints(minWidth: 34, minHeight: 34),
              onPressed: widget.onOpenInLegend,
            ),
    );

    final importBtn = SizedBox(
      height: 34,
      child: widget.importing
          ? const SizedBox(
              width: 34,
              child: Center(
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppTheme.primary),
                ),
              ),
            )
          : OutlinedButton.icon(
              onPressed: widget.onImport,
              icon: const Icon(Icons.download_rounded, size: 14),
              label: const Text('Import', style: TextStyle(fontSize: 12)),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primary,
                side: const BorderSide(color: AppTheme.primary),
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 0),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: _hovered ? AppTheme.surface : AppTheme.bg,
            border: Border.all(
              color:
                  _hovered ? AppTheme.primary.withValues(alpha:0.4) : AppTheme.border,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon column
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha:0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.flag_rounded,
                    size: 20, color: AppTheme.primary),
              ),
              const SizedBox(width: 12),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                                color: AppTheme.textH,
                                fontSize: 14,
                                fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (category.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.surface,
                              border: Border.all(color: AppTheme.border),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(category,
                                style: const TextStyle(
                                    color: AppTheme.textM, fontSize: 10)),
                          ),
                      ],
                    ),
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: const TextStyle(
                            color: AppTheme.textM, fontSize: 12),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (creator.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        'by ${_truncateWallet(creator)}',
                        style: const TextStyle(
                            color: AppTheme.textM, fontSize: 11),
                      ),
                    ],
                    if (narrow) ...[
                      const SizedBox(height: 10),
                      Row(children: [
                        openInLegendBtn,
                        const SizedBox(width: 6),
                        Flexible(child: importBtn),
                      ]),
                    ],
                  ],
                ),
              ),
              if (!narrow) ...[
                const SizedBox(width: 12),
                // v3.11.1 — "Open in Legend" quick-action.
                openInLegendBtn,
                const SizedBox(width: 6),
                importBtn,
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _truncateWallet(String w) {
    if (w.length <= 12) return w;
    return '${w.substring(0, 6)}…${w.substring(w.length - 4)}';
  }
}
