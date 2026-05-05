// Widget tests for the workflow VersionDiffPanel (v3.11.3 — T7).
//
// Pin down the visual contract: added/removed/modified node badges and the
// summary chips that headline the panel.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_store/features/legend/widgets/version_diff_panel.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

Map<String, dynamic> _versionRow({
  required int version,
  required List<Map<String, dynamic>> nodes,
  String name = '',
}) {
  return {
    'version': version,
    'name': name,
    'fields_json': jsonEncode({'nodes': nodes, 'edges': []}),
  };
}

Map<String, dynamic> _node(
  String id, {
  String label = 'Node',
  String type = 'agent',
  double x = 0,
  double y = 0,
  String? refId,
}) {
  return {
    'id': id,
    'type': type,
    'label': label,
    'x': x,
    'y': y,
    if (refId != null) 'ref_id': refId,
  };
}

void main() {
  testWidgets('added node renders ADDED badge and the +N summary chip',
      (tester) async {
    await tester.pumpWidget(_wrap(VersionDiffPanel(
      fromVersion: _versionRow(version: 1, nodes: [_node('a', label: 'A')]),
      toVersion: _versionRow(version: 2, nodes: [
        _node('a', label: 'A'),
        _node('b', label: 'B'),
      ]),
      onClose: () {},
    )));
    await tester.pump();
    expect(find.text('ADDED'), findsOneWidget);
    expect(find.text('+1 added'), findsOneWidget);
    expect(find.text('B'), findsWidgets);
  });

  testWidgets('removed node renders REMOVED badge and the −N summary chip',
      (tester) async {
    await tester.pumpWidget(_wrap(VersionDiffPanel(
      fromVersion: _versionRow(version: 1, nodes: [
        _node('a', label: 'A'),
        _node('gone', label: 'OldNode'),
      ]),
      toVersion: _versionRow(version: 2, nodes: [_node('a', label: 'A')]),
      onClose: () {},
    )));
    await tester.pump();
    expect(find.text('REMOVED'), findsOneWidget);
    expect(find.text('−1 removed'), findsOneWidget);
    expect(find.text('OldNode'), findsWidgets);
  });

  testWidgets('modified node shows MODIFIED badge and field-level diff text',
      (tester) async {
    await tester.pumpWidget(_wrap(VersionDiffPanel(
      fromVersion: _versionRow(version: 1, nodes: [
        _node('a', label: 'Old Title'),
      ]),
      toVersion: _versionRow(version: 2, nodes: [
        _node('a', label: 'New Title'),
      ]),
      onClose: () {},
    )));
    await tester.pump();
    expect(find.text('MODIFIED'), findsOneWidget);
    expect(find.text('~1 changed'), findsOneWidget);
    // Field-level diff text appears verbatim.
    expect(find.textContaining("'Old Title'"), findsOneWidget);
    expect(find.textContaining("'New Title'"), findsOneWidget);
  });

  testWidgets('close button invokes onClose callback', (tester) async {
    var closed = 0;
    await tester.pumpWidget(_wrap(VersionDiffPanel(
      fromVersion: _versionRow(version: 1, nodes: [_node('a')]),
      toVersion: _versionRow(version: 2, nodes: [_node('a')]),
      onClose: () => closed++,
    )));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pump();
    expect(closed, 1);
  });
}
