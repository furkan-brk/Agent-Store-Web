// Widget regression test for v3.12 (PR 2 / FIX 3) — FE-P0-3.
//
// LegendScreen has 4 inline `final ctrl = TextEditingController(...)` sites:
// label-edge (291), new-workflow (410), rename (935), execute (1257). Pre-fix,
// none disposed their controllers — every dialog open/close leaked one.
//
// We extracted two reusable widgets:
//   - LegendTextInputDialog (single-line; covers label-edge / new-workflow /
//     rename — config differs only in title/hint/initialValue/trim/allowEmpty)
//   - LegendExecuteInputDialog (multi-line w/ credit notice — execute)
// Both own their TextEditingController in State, dispose in dispose().
//
// We test these widgets directly (not via LegendScreen) — that file is
// 5641 lines, owns ~30 controllers/animations and pulls in ApiService +
// LegendService, which are not test-friendly.

import 'package:agent_store/features/legend/widgets/legend_text_input_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _harness(Widget child) =>
    MaterialApp(home: Scaffold(body: child));

void main() {
  group('LegendTextInputDialog', () {
    testWidgets(
      'disposes controller on unmount (no exceptions)',
      (tester) async {
        await tester.pumpWidget(_harness(LegendTextInputDialog(
          title: 'Rename Workflow',
          hint: 'Workflow name',
          confirmLabel: 'Rename',
          initialValue: 'My Flow',
          onConfirm: (_) {},
        )));
        // Seeded value renders.
        expect(find.text('My Flow'), findsOneWidget);

        // Tear down — triggers State.dispose.
        await tester.pumpWidget(
            const MaterialApp(home: Scaffold(body: SizedBox.shrink())));
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      '10× build/teardown cycles raise no exceptions',
      (tester) async {
        for (var i = 0; i < 10; i++) {
          await tester.pumpWidget(_harness(LegendTextInputDialog(
            title: 'Iter $i',
            confirmLabel: 'OK',
            initialValue: 'value-$i',
            onConfirm: (_) {},
          )));
          // Tear down immediately.
          await tester.pumpWidget(
              const MaterialApp(home: Scaffold(body: SizedBox.shrink())));
        }
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'trim=true, allowEmpty=true (label-edge contract)',
      (tester) async {
        String? captured;
        await tester.pumpWidget(_harness(LegendTextInputDialog(
          title: 'Label Edge',
          confirmLabel: 'Apply',
          initialValue: '  success  ',
          // defaults: trim=true, allowEmpty=true
          onConfirm: (v) => captured = v,
        )));
        await tester.tap(find.text('Apply'));
        await tester.pumpAndSettle();
        expect(captured, 'success');
      },
    );

    testWidgets(
      'trim=false (new-workflow contract — host trims itself)',
      (tester) async {
        String? captured;
        await tester.pumpWidget(_harness(LegendTextInputDialog(
          title: 'New Workflow',
          confirmLabel: 'Create',
          initialValue: 'Workflow 1',
          trim: false,
          onConfirm: (v) => captured = v,
        )));
        await tester.tap(find.text('Create'));
        await tester.pumpAndSettle();
        expect(captured, 'Workflow 1');
      },
    );

    testWidgets(
      'allowEmpty=false silently drops empty input (rename contract)',
      (tester) async {
        var calls = 0;
        await tester.pumpWidget(_harness(LegendTextInputDialog(
          title: 'Rename Workflow',
          confirmLabel: 'Rename',
          initialValue: '   ', // whitespace → trims to empty
          allowEmpty: false,
          onConfirm: (_) => calls++,
        )));
        await tester.tap(find.text('Rename'));
        await tester.pumpAndSettle();
        expect(calls, 0);
      },
    );

    testWidgets(
      'Cancel button does not invoke onConfirm',
      (tester) async {
        var calls = 0;
        late BuildContext ctx;
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: Builder(builder: (c) {
              ctx = c;
              return ElevatedButton(
                onPressed: () => showDialog<void>(
                  context: ctx,
                  builder: (_) => LegendTextInputDialog(
                    title: 'T',
                    confirmLabel: 'OK',
                    onConfirm: (_) => calls++,
                  ),
                ),
                child: const Text('open'),
              );
            }),
          ),
        ));
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(calls, 0);
      },
    );
  });

  group('LegendExecuteInputDialog', () {
    testWidgets(
      'disposes controller on unmount (no exceptions)',
      (tester) async {
        await tester.pumpWidget(_harness(LegendExecuteInputDialog(
          agentCount: 2,
          onConfirm: (_) {},
        )));
        expect(find.text('Execute Workflow'), findsOneWidget);
        // Credit notice reflects the agent count.
        expect(
            find.textContaining('2 agent nodes and will cost 2 credits'),
            findsOneWidget);

        await tester.pumpWidget(
            const MaterialApp(home: Scaffold(body: SizedBox.shrink())));
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'credit notice singularises at 1 agent',
      (tester) async {
        await tester.pumpWidget(_harness(LegendExecuteInputDialog(
          agentCount: 1,
          onConfirm: (_) {},
        )));
        expect(find.textContaining('1 agent node and will cost 1 credit'),
            findsOneWidget);
      },
    );

    testWidgets(
      'Execute button no-ops on empty input',
      (tester) async {
        var calls = 0;
        await tester.pumpWidget(_harness(LegendExecuteInputDialog(
          agentCount: 0,
          onConfirm: (_) => calls++,
        )));
        // Execute is built via ElevatedButton.icon — locate by label.
        await tester.tap(find.text('Execute'));
        await tester.pumpAndSettle();
        expect(calls, 0);
      },
    );

    testWidgets(
      '10× build/teardown cycles raise no exceptions',
      (tester) async {
        for (var i = 0; i < 10; i++) {
          await tester.pumpWidget(_harness(LegendExecuteInputDialog(
            agentCount: i % 4,
            onConfirm: (_) {},
          )));
          await tester.pumpWidget(
              const MaterialApp(home: Scaffold(body: SizedBox.shrink())));
        }
        expect(tester.takeException(), isNull);
      },
    );
  });
}
