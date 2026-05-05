// lib/features/legend/widgets/observability_chart.dart
//
// v3.11.3 — T8 — Pure-Dart bar chart for per-node execution duration.
//
// Avoids a chart-library dependency on purpose: pixel-art project, dark
// theme, and we already own the CustomPainter idiom across the codebase
// (pixel_art_painter.dart). Each bar's height is proportional to its
// durationMs against the max in the set; colour reflects status:
//   - completed → success green
//   - failed    → primary crimson
//   - other     → muted border
//
// Empty datasets render an empty-state hint instead of a hard error so
// the parent observability screen can drop the chart in unconditionally.

import 'package:flutter/material.dart';
import '../../../app/theme.dart';

class ObservabilityBar {
  final String nodeId;
  final String label;
  final int durationMs;
  final String status; // 'completed' | 'failed' | other

  const ObservabilityBar({
    required this.nodeId,
    required this.label,
    required this.durationMs,
    required this.status,
  });
}

class ObservabilityChart extends StatelessWidget {
  final List<ObservabilityBar> bars;
  final double height;

  const ObservabilityChart({
    super.key,
    required this.bars,
    this.height = 220,
  });

  @override
  Widget build(BuildContext context) {
    if (bars.isEmpty) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text(
            'No node data yet',
            style: TextStyle(
              color: AppTheme.textM.withValues(alpha: 0.8),
              fontSize: 13,
            ),
          ),
        ),
      );
    }
    return SizedBox(
      height: height,
      child: CustomPaint(
        painter: _BarChartPainter(bars: bars),
        size: Size.infinite,
      ),
    );
  }
}

class _BarChartPainter extends CustomPainter {
  final List<ObservabilityBar> bars;
  _BarChartPainter({required this.bars});

  Color _colorFor(String status) {
    switch (status) {
      case 'completed':
        return AppTheme.success;
      case 'failed':
        return AppTheme.primary;
      default:
        return AppTheme.border2;
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (bars.isEmpty) return;
    const topPad = 18.0;
    const bottomPad = 36.0;
    const sidePad = 8.0;
    final chartH = (size.height - topPad - bottomPad).clamp(20.0, size.height);
    final chartW = (size.width - sidePad * 2).clamp(20.0, size.width);

    final maxMs = bars.map((b) => b.durationMs).fold<int>(0, (a, b) => a > b ? a : b);
    final safeMax = maxMs == 0 ? 1 : maxMs;

    // Baseline
    final axis = Paint()
      ..color = AppTheme.border
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(sidePad, topPad + chartH),
      Offset(sidePad + chartW, topPad + chartH),
      axis,
    );

    final n = bars.length;
    final slot = chartW / n;
    final barW = (slot * 0.6).clamp(4.0, 48.0);
    final gap = slot - barW;

    final labelStyle = TextStyle(
      color: AppTheme.textM.withValues(alpha: 0.85),
      fontSize: 9,
      fontWeight: FontWeight.w500,
    );
    final valueStyle = TextStyle(
      color: AppTheme.textH.withValues(alpha: 0.9),
      fontSize: 10,
      fontWeight: FontWeight.w600,
    );

    for (var i = 0; i < n; i++) {
      final bar = bars[i];
      final fraction = bar.durationMs / safeMax;
      final h = chartH * fraction;
      final left = sidePad + (slot * i) + (gap / 2);
      final top = topPad + (chartH - h);
      final rect = Rect.fromLTWH(left, top, barW, h.clamp(2.0, chartH));

      final fill = Paint()
        ..color = _colorFor(bar.status).withValues(alpha: 0.85);
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          rect,
          topLeft: const Radius.circular(3),
          topRight: const Radius.circular(3),
        ),
        fill,
      );

      // Duration label above the bar
      final valueText = TextPainter(
        text: TextSpan(text: '${bar.durationMs}ms', style: valueStyle),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout();
      if (h > 0) {
        valueText.paint(
          canvas,
          Offset(left + (barW - valueText.width) / 2, top - valueText.height - 2),
        );
      }

      // Node id label below the axis (truncate to 8 chars)
      final shortLabel = bar.nodeId.length <= 10
          ? bar.nodeId
          : '${bar.nodeId.substring(0, 8)}…';
      final labelText = TextPainter(
        text: TextSpan(text: shortLabel, style: labelStyle),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: slot - 2);
      labelText.paint(
        canvas,
        Offset(left + (barW - labelText.width) / 2, topPad + chartH + 6),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BarChartPainter old) {
    if (old.bars.length != bars.length) return true;
    for (var i = 0; i < bars.length; i++) {
      if (old.bars[i].durationMs != bars[i].durationMs) return true;
      if (old.bars[i].status != bars[i].status) return true;
      if (old.bars[i].nodeId != bars[i].nodeId) return true;
    }
    return false;
  }
}
