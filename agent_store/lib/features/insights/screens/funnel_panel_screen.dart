// lib/features/insights/screens/funnel_panel_screen.dart
//
// v3.11.3 — T11 — Cross-cutting KPI panel for creators. Surfaces 4 funnel
// conversion metrics over a selectable 7d / 30d / 90d window:
//   1. Suggest → Execute (Guild Master suggestion → Legend execute)
//   2. Edit → Publish    (Card editor save → publish)
//   3. Publish → First Save (median time to first library save)
//   4. Trial → Purchase  (trial token → purchase)
//
// Backend endpoint: GET /api/v1/admin/kpi/funnel?since=7d|30d|90d.

import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../shared/services/api_service.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/page_header.dart';
import '../../../shared/widgets/skeleton_widgets.dart';
import '../widgets/funnel_card.dart';

class FunnelPanelScreen extends StatefulWidget {
  /// Optional fetcher override for tests so we can avoid the live API.
  final Future<Map<String, dynamic>?> Function(String window)? fetchOverride;

  const FunnelPanelScreen({super.key, this.fetchOverride});

  @override
  State<FunnelPanelScreen> createState() => _FunnelPanelScreenState();
}

class _FunnelPanelScreenState extends State<FunnelPanelScreen> {
  String _window = '30d';
  bool _loading = true;
  Map<String, dynamic>? _data;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final fn = widget.fetchOverride ??
        (String w) => ApiService.instance.getFunnelMetrics(window: w);
    final data = await fn(_window);
    if (!mounted) return;
    setState(() {
      _data = data;
      _loading = false;
    });
  }

  void _selectWindow(String w) {
    if (w == _window) return;
    setState(() => _window = w);
    _load();
  }

  double _readPct(String key) {
    final raw = _data?[key];
    if (raw == null) return 0;
    if (raw is num) {
      // Backend may send either a 0..1 fraction or a 0..100 percentage —
      // normalise to the fraction the FunnelCard expects.
      return raw > 1 ? (raw / 100).clamp(0, 1).toDouble() : raw.toDouble().clamp(0, 1);
    }
    return 0;
  }

  double? _readDelta(String key) {
    final raw = _data?['${key}_delta'];
    if (raw is num) return raw.toDouble();
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PageHeader(
                icon: Icons.insights_rounded,
                iconColor: AppTheme.gold,
                title: 'Funnel insights',
                subtitle: 'Conversion KPIs across the creator surface area.',
              ),
              const SizedBox(height: 16),
              _WindowSelector(selected: _window, onSelect: _selectWindow),
              const SizedBox(height: 20),
              Expanded(
                child: _loading
                    ? _buildLoading()
                    : (_data == null
                        ? EmptyState(
                            icon: Icons.insights_outlined,
                            title: 'No KPI data yet',
                            subtitle:
                                'Insights will appear once you have published agents and seen activity in this window.',
                            actionLabel: 'Retry',
                            onAction: _load,
                          )
                        : _buildContent()),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return const ShimmerScope(
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          ShimmerBox(width: 220, height: 140, color: AppTheme.card),
          ShimmerBox(width: 220, height: 140, color: AppTheme.card),
          ShimmerBox(width: 220, height: 140, color: AppTheme.card),
          ShimmerBox(width: 220, height: 140, color: AppTheme.card),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return ListView(
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            FunnelCard(
              title: 'Suggest → Execute',
              subtitle: 'Guild Master suggestion that ran in Legend.',
              percent: _readPct('suggest_to_execute'),
              deltaPercent: _readDelta('suggest_to_execute'),
              icon: Icons.psychology_outlined,
            ),
            FunnelCard(
              title: 'Edit → Publish',
              subtitle: 'Card edits that result in a published agent.',
              percent: _readPct('edit_to_publish'),
              deltaPercent: _readDelta('edit_to_publish'),
              icon: Icons.publish_outlined,
            ),
            FunnelCard(
              title: 'Publish → First Save',
              subtitle: 'New agents that get a save within the window.',
              percent: _readPct('publish_to_first_save'),
              deltaPercent: _readDelta('publish_to_first_save'),
              icon: Icons.bookmark_added_outlined,
            ),
            FunnelCard(
              title: 'Trial → Purchase',
              subtitle: 'Trial tokens that converted to a purchase.',
              percent: _readPct('trial_to_purchase'),
              deltaPercent: _readDelta('trial_to_purchase'),
              icon: Icons.shopping_bag_outlined,
            ),
          ],
        ),
      ],
    );
  }
}

class _WindowSelector extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelect;

  static const _windows = [
    ('7d', '7 Days'),
    ('30d', '30 Days'),
    ('90d', '90 Days'),
  ];

  const _WindowSelector({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: _windows.map((pair) {
        final (key, label) = pair;
        final isSelected = selected == key;
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            child: InkWell(
              onTap: () => onSelect(key),
              borderRadius: BorderRadius.circular(20),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.gold.withValues(alpha: 0.15)
                      : AppTheme.card2,
                  border: Border.all(
                    color: isSelected
                        ? AppTheme.gold.withValues(alpha: 0.6)
                        : AppTheme.border,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? AppTheme.gold : AppTheme.textM,
                    fontSize: 12,
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
