// Widget regression test for v3.12 (PR 2 / FIX 5) — FE-L0-2.
//
// Pre-fix, the legend toolbar wrapped its 12-button secondary cluster in a
// `SingleChildScrollView(reverse: true)`. The reverse:true mounted scroll
// at the right edge — so on iPad-landscape (1024px) and other <1100px
// viewports, the user saw the *rightmost* (Clear / ?) buttons and had to
// scroll LEFT to find the primary Execute CTA. The 1280px+ desktop case
// was fine.
//
// Fix:
//   1. `legendToolbarShouldCollapse(width)` returns true at <1100px.
//   2. The 12 secondary actions collapse into `LegendToolbarOverflowMenu`
//      (a PopupMenuButton) at the leading position.
//   3. Execute remains pinned to the trailing edge OUTSIDE any scroll
//      view — never scrolled off-screen.
//
// Mounting the full LegendScreen is impractical (5641 LOC, ApiService +
// LegendService deps), so we test the helper + overflow widget directly,
// plus a synthetic toolbar that mirrors the screen's pinning structure to
// verify Execute visibility at the four target viewport sizes.

import 'package:agent_store/features/legend/widgets/legend_toolbar_overflow.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('legendToolbarShouldCollapse breakpoint', () {
    test('800px desktop → collapse', () {
      expect(legendToolbarShouldCollapse(800), isTrue);
    });
    test('1024px iPad landscape → collapse', () {
      expect(legendToolbarShouldCollapse(1024), isTrue);
    });
    test('1099px just under threshold → collapse', () {
      expect(legendToolbarShouldCollapse(1099), isTrue);
    });
    test('1100px at threshold → no collapse (the exact value)', () {
      expect(legendToolbarShouldCollapse(1100), isFalse);
    });
    test('1280px common laptop → no collapse', () {
      expect(legendToolbarShouldCollapse(1280), isFalse);
    });
    test('1440px workstation → no collapse', () {
      expect(legendToolbarShouldCollapse(1440), isFalse);
    });
    test('isMobile=true short-circuits to true regardless of width', () {
      expect(legendToolbarShouldCollapse(1920, isMobile: true), isTrue);
    });
    test('breakpoint constant is exactly 1100', () {
      expect(kLegendToolbarCollapseWidth, 1100);
    });
  });

  group('LegendToolbarOverflowMenu', () {
    testWidgets('renders the trigger button with the Tools label',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(
            child: LegendToolbarOverflowMenu(
              items: [
                LegendToolbarOverflowItem(
                    icon: Icons.save, label: 'Save', onTap: () {}),
              ],
            ),
          ),
        ),
      ));
      expect(find.text('Tools'), findsOneWidget);
    });

    testWidgets('opens the menu and lists every item by label',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(
            child: LegendToolbarOverflowMenu(
              items: [
                LegendToolbarOverflowItem(
                    icon: Icons.upload, label: 'Import', onTap: () {}),
                LegendToolbarOverflowItem(
                    icon: Icons.download, label: 'Export', onTap: () {}),
                LegendToolbarOverflowItem(
                    icon: Icons.history, label: 'History', onTap: () {}),
              ],
            ),
          ),
        ),
      ));
      await tester.tap(find.byType(PopupMenuButton<int>));
      await tester.pumpAndSettle();
      expect(find.text('Import'), findsOneWidget);
      expect(find.text('Export'), findsOneWidget);
      expect(find.text('History'), findsOneWidget);
    });

    testWidgets('disabled items do not invoke onTap', (tester) async {
      var calls = 0;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(
            child: LegendToolbarOverflowMenu(
              items: [
                LegendToolbarOverflowItem(
                  icon: Icons.undo,
                  label: 'Undo',
                  disabled: true,
                  onTap: () => calls++,
                ),
              ],
            ),
          ),
        ),
      ));
      await tester.tap(find.byType(PopupMenuButton<int>));
      await tester.pumpAndSettle();
      // Disabled PopupMenuItem cannot be tapped — try and verify no call.
      // PopupMenuItem with enabled:false makes its InkWell null, so a tap
      // simply closes the menu.
      final undoFinder = find.text('Undo');
      expect(undoFinder, findsOneWidget);
      // Try tapping anyway — the disabled item should not fire onTap.
      await tester.tap(undoFinder, warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(calls, 0);
    });

    testWidgets('enabled items fire onTap and dismiss the menu',
        (tester) async {
      var calls = 0;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(
            child: LegendToolbarOverflowMenu(
              items: [
                LegendToolbarOverflowItem(
                    icon: Icons.save,
                    label: 'Save',
                    onTap: () => calls++),
              ],
            ),
          ),
        ),
      ));
      await tester.tap(find.byType(PopupMenuButton<int>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(calls, 1);
    });
  });

  group('Execute pinning (synthetic toolbar)', () {
    // We mirror the LegendScreen toolbar structure: pinned-leading row +
    // Expanded(secondary cluster) + pinned-trailing Execute. We verify
    // Execute is visible at the four target viewport widths.
    Widget syntheticToolbar(double width, {required bool compact}) =>
        MediaQuery(
          data: MediaQueryData(size: Size(width, 600)),
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: width,
                height: 52,
                child: Row(
                  children: [
                    // Pinned leading.
                    const _Btn(label: 'New'),
                    const SizedBox(width: 6),
                    const _Btn(label: 'Save'),
                    const SizedBox(width: 6),
                    Expanded(
                      child: compact
                          ? LegendToolbarOverflowMenu(items: [
                              for (final l in const [
                                'Starter',
                                'Templates',
                                'Auto Layout',
                                'Fit',
                                'Undo',
                                'Redo',
                                'Load',
                                'Export',
                                'Import',
                                'History',
                                'Compare',
                                'Clear'
                              ])
                                LegendToolbarOverflowItem(
                                    icon: Icons.circle,
                                    label: l,
                                    onTap: () {}),
                            ])
                          : SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  for (final l in const [
                                    'Starter',
                                    'Templates',
                                    'Auto Layout',
                                    'Fit',
                                    'Undo',
                                    'Redo',
                                    'Load',
                                    'Export',
                                    'Import',
                                    'History',
                                    'Compare',
                                    'Clear'
                                  ]) ...[
                                    _Btn(label: l),
                                    const SizedBox(width: 6),
                                  ],
                                ],
                              ),
                            ),
                    ),
                    // Pinned trailing — Execute MUST be visible.
                    const SizedBox(width: 6),
                    const _Btn(label: 'Execute', key: ValueKey('execute-btn')),
                  ],
                ),
              ),
            ),
          ),
        );

    final viewports = <double>[800, 1024, 1280, 1440];

    for (final width in viewports) {
      final compact = legendToolbarShouldCollapse(width);
      testWidgets(
        'Execute is visible at ${width.toInt()}px (compact=$compact)',
        (tester) async {
          tester.view.physicalSize = Size(width, 600);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          await tester
              .pumpWidget(syntheticToolbar(width, compact: compact));
          await tester.pumpAndSettle();
          expect(find.byKey(const ValueKey('execute-btn')), findsOneWidget);
          expect(find.text('Execute'), findsOneWidget);
          // New + Save pinned left, also visible.
          expect(find.text('New'), findsOneWidget);
          expect(find.text('Save'), findsOneWidget);

          if (compact) {
            // The secondary cluster collapsed → Tools trigger visible,
            // and individual secondary labels NOT in the body (they're
            // hidden inside the unopened popup).
            expect(find.text('Tools'), findsOneWidget);
            expect(find.text('Templates'), findsNothing);
            expect(find.text('Compare'), findsNothing);
          } else {
            // Wide viewport → secondary cluster inline. No Tools trigger.
            expect(find.text('Tools'), findsNothing);
            expect(find.text('Templates'), findsOneWidget);
            expect(find.text('Compare'), findsOneWidget);
          }
        },
      );
    }
  });
}

class _Btn extends StatelessWidget {
  const _Btn({required this.label, super.key});
  final String label;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {},
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFEEEEEE),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(label, style: const TextStyle(fontSize: 12)),
      ),
    );
  }
}
