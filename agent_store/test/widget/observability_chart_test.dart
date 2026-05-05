// Widget tests for the ObservabilityChart bar chart (v3.11.3 — T8).
//
// CustomPainter visual contract is hard to assert pixel-perfect under
// flutter_test, so the tests focus on the public widget surface — empty
// state, finite-size painting, and shouldRepaint semantics.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_store/features/legend/widgets/observability_chart.dart';

Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(
        body: SizedBox(width: 400, height: 240, child: child),
      ),
    );

void main() {
  testWidgets('empty bar list renders the empty-state hint', (tester) async {
    await tester.pumpWidget(_wrap(const ObservabilityChart(bars: [])));
    expect(find.text('No node data yet'), findsOneWidget);
  });

  testWidgets('non-empty list mounts a CustomPaint', (tester) async {
    await tester.pumpWidget(_wrap(const ObservabilityChart(
      bars: [
        ObservabilityBar(
            nodeId: 'a', label: 'A', durationMs: 100, status: 'completed'),
        ObservabilityBar(
            nodeId: 'b', label: 'B', durationMs: 250, status: 'completed'),
        ObservabilityBar(
            nodeId: 'c', label: 'C', durationMs: 50, status: 'failed'),
      ],
    )));
    // The chart wraps a CustomPaint; "No node data yet" must NOT be present.
    expect(find.text('No node data yet'), findsNothing);
    expect(find.byType(CustomPaint), findsWidgets);
  });

  testWidgets('updating bars causes a repaint without throwing',
      (tester) async {
    const initial = [
      ObservabilityBar(
          nodeId: 'a', label: 'A', durationMs: 100, status: 'completed'),
    ];
    await tester.pumpWidget(_wrap(const ObservabilityChart(bars: initial)));
    await tester.pumpWidget(_wrap(const ObservabilityChart(
      bars: [
        ObservabilityBar(
            nodeId: 'a', label: 'A', durationMs: 200, status: 'failed'),
        ObservabilityBar(
            nodeId: 'b', label: 'B', durationMs: 50, status: 'completed'),
      ],
    )));
    expect(find.byType(ObservabilityChart), findsOneWidget);
  });
}
