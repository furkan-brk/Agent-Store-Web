// Tests that VersionDiffPanel._decodeNodes (via the public widget) handles
// corrupt node JSON without crashing. We render the widget with bad data and
// assert it produces the Unfold/panel UI rather than a red-box exception.

import 'package:agent_store/features/legend/widgets/version_diff_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _versionWith(dynamic nodes) => {
      'id': 'v1',
      'version': 1,
      'name': 'Test',
      'nodes': nodes,
    };

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('VersionDiffPanel with corrupt node data', () {
    testWidgets('renders without exception when nodes list contains non-map entries',
        (tester) async {
      final from = _versionWith([
        {'id': 'n1', 'type': 'agent', 'x': 0.0, 'y': 0.0},
        42, // non-map — should be skipped
        'bad_string', // non-map — should be skipped
      ]);
      final to = _versionWith([
        {'id': 'n1', 'type': 'agent', 'x': 10.0, 'y': 0.0},
      ]);

      await tester.pumpWidget(_wrap(
        VersionDiffPanel(
          fromVersion: from,
          toVersion: to,
          onClose: () {},
        ),
      ));

      expect(tester.takeException(), isNull);
    });

    testWidgets('renders without exception when nodes is null', (tester) async {
      final from = _versionWith(null);
      final to = _versionWith(null);

      await tester.pumpWidget(_wrap(
        VersionDiffPanel(
          fromVersion: from,
          toVersion: to,
          onClose: () {},
        ),
      ));

      expect(tester.takeException(), isNull);
    });

    testWidgets('renders without exception when nodes is a malformed JSON string',
        (tester) async {
      final from = <String, dynamic>{
        'id': 'v1',
        'version': 1,
        'name': 'Test',
        'fields_json': '{not valid json{{',
      };
      final to = _versionWith([]);

      await tester.pumpWidget(_wrap(
        VersionDiffPanel(
          fromVersion: from,
          toVersion: to,
          onClose: () {},
        ),
      ));

      expect(tester.takeException(), isNull);
    });

    testWidgets('shows diff panel with valid nodes on both sides', (tester) async {
      final from = _versionWith([
        {'id': 'n1', 'type': 'start', 'x': 0.0, 'y': 0.0},
        {'id': 'n2', 'type': 'agent', 'x': 200.0, 'y': 0.0, 'label': 'Agent A'},
      ]);
      final to = _versionWith([
        {'id': 'n1', 'type': 'start', 'x': 0.0, 'y': 0.0},
        {'id': 'n3', 'type': 'agent', 'x': 200.0, 'y': 0.0, 'label': 'Agent B'},
      ]);

      await tester.pumpWidget(_wrap(
        VersionDiffPanel(
          fromVersion: from,
          toVersion: to,
          onClose: () {},
        ),
      ));

      expect(tester.takeException(), isNull);
      // Panel renders a close button
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
    });
  });
}
