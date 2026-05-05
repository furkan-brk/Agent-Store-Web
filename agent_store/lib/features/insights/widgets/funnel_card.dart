// lib/features/insights/widgets/funnel_card.dart
//
// v3.11.3 — T11 — Single KPI tile for the cross-cutting funnel panel.
//
// Renders a label, a percentage value, and an optional delta-vs-previous-window
// chip. Color coding: ≥50% success, 20-50% gold, <20% primary — same scale
// the rest of the codebase uses for "good / warning / bad".

import 'package:flutter/material.dart';

import '../../../app/theme.dart';

class FunnelCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final double percent; // 0..1
  final double? deltaPercent; // change vs previous window, e.g. +0.05
  final IconData icon;
  final double width;

  const FunnelCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.percent,
    this.deltaPercent,
    required this.icon,
    this.width = 220,
  });

  Color _color() {
    if (percent >= 0.5) return AppTheme.success;
    if (percent >= 0.2) return AppTheme.gold;
    return AppTheme.primary;
  }

  String _formatPct(double p) => '${(p * 100).toStringAsFixed(p >= 0.1 ? 0 : 1)}%';

  @override
  Widget build(BuildContext context) {
    final color = _color();
    return Container(
      width: width,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: AppTheme.textH,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatPct(percent),
                style: TextStyle(
                  color: color,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                ),
              ),
              const Spacer(),
              if (deltaPercent != null) _DeltaChip(delta: deltaPercent!),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percent.clamp(0.0, 1.0),
              minHeight: 4,
              backgroundColor: AppTheme.bg.withValues(alpha: 0.55),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: const TextStyle(color: AppTheme.textM, fontSize: 11),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _DeltaChip extends StatelessWidget {
  final double delta;
  const _DeltaChip({required this.delta});

  @override
  Widget build(BuildContext context) {
    final positive = delta >= 0;
    final color = positive ? AppTheme.success : AppTheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            positive ? Icons.arrow_upward : Icons.arrow_downward,
            color: color,
            size: 11,
          ),
          const SizedBox(width: 2),
          Text(
            '${(delta * 100).toStringAsFixed(1)}%',
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
