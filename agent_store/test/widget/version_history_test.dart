// Widget tests for VersionHistoryDialog (v3.11.3 — T10c).
//
// Uses the dialog's `fetchOverride` / `rollbackOverride` test seams to
// avoid the real ApiService — we're verifying the rendering contract,
// not the network layer.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_store/features/card_editor/widgets/version_history_dialog.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('renders the version list returned by the fetcher',
      (tester) async {
    var rolledBack = 0;
    await tester.pumpWidget(_wrap(VersionHistoryDialog(
      agentId: 1,
      onRollbackComplete: () => rolledBack++,
      fetchOverride: (_) async => [
        {'version': 3, 'created_at': DateTime.now().toUtc().toIso8601String()},
        {'version': 2, 'created_at': DateTime.now().toUtc().toIso8601String()},
        {'version': 1, 'created_at': DateTime.now().toUtc().toIso8601String()},
      ],
    )));
    // Initial loading spinner.
    await tester.pump();
    // Allow the canned future to resolve.
    await tester.pump(const Duration(milliseconds: 1));
    expect(find.text('v3'), findsOneWidget);
    expect(find.text('v2'), findsOneWidget);
    expect(find.text('v1'), findsOneWidget);
    expect(find.text('Version 3'), findsOneWidget);
    expect(rolledBack, 0);
  });

  testWidgets('empty version list renders the empty hint', (tester) async {
    await tester.pumpWidget(_wrap(VersionHistoryDialog(
      agentId: 1,
      onRollbackComplete: () {},
      fetchOverride: (_) async => const [],
    )));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
    expect(find.text('No saved versions yet.'), findsOneWidget);
  });

  testWidgets('header has a Version history title', (tester) async {
    await tester.pumpWidget(_wrap(VersionHistoryDialog(
      agentId: 1,
      onRollbackComplete: () {},
      fetchOverride: (_) async => const [],
    )));
    await tester.pump();
    expect(find.text('Version history'), findsOneWidget);
  });
}
