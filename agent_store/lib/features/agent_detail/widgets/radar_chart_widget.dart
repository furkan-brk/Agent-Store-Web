import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class RadarChartWidget extends StatelessWidget {
  final Map<String, int> stats;
  final Color color;

  const RadarChartWidget({
    super.key,
    required this.stats,
    required this.color,
  });

  static const _labels = ['INT', 'POW', 'SPD', 'CRE', 'DEF'];

  @override
  Widget build(BuildContext context) {
    // Take the first 5 stats, normalize to 0–100
    final entries = stats.entries.take(5).toList();

    // Pad to 5 entries if fewer stats available
    while (entries.length < 5) {
      entries.add(const MapEntry('—', 0));
    }

    final dataEntries = entries
        .map((e) => RadarEntry(value: (e.value.clamp(0, 100)).toDouble()))
        .toList();

    return SizedBox(
      width: 200,
      height: 200,
      child: RadarChart(
        RadarChartData(
          dataSets: [
            RadarDataSet(
              dataEntries: dataEntries,
              fillColor: color.withValues(alpha: 0.3),
              borderColor: color,
              borderWidth: 1.5,
              entryRadius: 3,
            ),
          ],
          radarBorderData: BorderSide(color: color.withValues(alpha: 0.2), width: 1),
          tickCount: 4,
          ticksTextStyle: const TextStyle(color: Colors.transparent, fontSize: 8),
          tickBorderData: const BorderSide(color: Colors.transparent),
          gridBorderData: BorderSide(color: color.withValues(alpha: 0.15), width: 1),
          titleTextStyle: const TextStyle(color: Color(0xFF2B2C1E), fontSize: 10),
          getTitle: (index, angle) {
            final label = index < _labels.length ? _labels[index] : '';
            return RadarChartTitle(text: label, angle: 0);
          },
        ),
      ),
    );
  }
}
