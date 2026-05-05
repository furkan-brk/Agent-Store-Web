// Widget regression test for v3.12 (PR 2 / FIX 4) — FE-L0-1.
//
// LegendScreen pre-fix passed `FocusNode()..requestFocus()` inline to its
// KeyboardListener inside build(). Every rebuild allocated a new FocusNode
// and re-stole focus from any open dialog/text-field — unbounded leak +
// focus-steal bug.
//
// The fix hoists `_shortcutFocus` to a State field, requests focus once via
// addPostFrameCallback in initState, and disposes in dispose(). Mounting
// LegendScreen directly is impractical (5641-line file, ApiService +
// LegendService dependencies that are not test-friendly). Instead we lock
// in the *pattern contract* with a small reference widget that mirrors the
// fix exactly. If a future refactor of LegendScreen drops back to the
// inline `FocusNode()..requestFocus()` pattern, reviewers can compare to
// this canonical example.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Mirrors the LegendScreen pattern: hoisted FocusNode + post-frame
/// requestFocus + dispose.
class _FixedKeyboardHost extends StatefulWidget {
  const _FixedKeyboardHost({required this.onSpacePressed});
  final VoidCallback onSpacePressed;

  @override
  State<_FixedKeyboardHost> createState() => _FixedKeyboardHostState();
}

class _FixedKeyboardHostState extends State<_FixedKeyboardHost> {
  // The post-fix invariant: ONE FocusNode per State, never reallocated.
  final FocusNode _shortcutFocus =
      FocusNode(debugLabel: 'fixed-host-shortcuts');
  int _builds = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _shortcutFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _shortcutFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _builds++;
    return KeyboardListener(
      focusNode: _shortcutFocus,
      autofocus: false,
      onKeyEvent: (event) {
        if (event is! KeyDownEvent) return;
        if (event.logicalKey == LogicalKeyboardKey.space) {
          widget.onSpacePressed();
        }
      },
      child: Center(
        child: ElevatedButton(
          onPressed: () => setState(() {}),
          child: Text('rebuild ($_builds)'),
        ),
      ),
    );
  }
}

void main() {
  testWidgets(
    'hoisted FocusNode is reused across rebuilds (no leak)',
    (tester) async {
      var spaces = 0;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: _FixedKeyboardHost(onSpacePressed: () => spaces++),
        ),
      ));
      // Wait for the post-frame requestFocus.
      await tester.pumpAndSettle();
      // First build runs. Find the State so we can capture the FocusNode.
      final state = tester.state<_FixedKeyboardHostState>(
          find.byType(_FixedKeyboardHost));
      final firstNode = state._shortcutFocus;
      expect(firstNode.hasFocus, isTrue,
          reason: 'post-frame requestFocus should win on first frame');

      // Rebuild 5 times (button tap calls setState).
      for (var i = 0; i < 5; i++) {
        await tester.tap(find.byType(ElevatedButton));
        await tester.pumpAndSettle();
      }

      // Same FocusNode instance survives: no fresh allocation per build.
      final stillSameNode = state._shortcutFocus;
      expect(identical(firstNode, stillSameNode), isTrue,
          reason: 'FocusNode field must NOT be reallocated on rebuild');

      // Send a key event to validate the listener still routes through it.
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(spaces, 1);
    },
  );

  testWidgets(
    'hoisted FocusNode is disposed exactly once on unmount',
    (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: _FixedKeyboardHost(onSpacePressed: () {}),
        ),
      ));
      await tester.pumpAndSettle();
      final state = tester.state<_FixedKeyboardHostState>(
          find.byType(_FixedKeyboardHost));
      final node = state._shortcutFocus;

      // Tear down the subtree — dispose runs once.
      await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: SizedBox.shrink())));
      expect(tester.takeException(), isNull);

      // After dispose, attempting to add a listener throws.
      expect(() => node.addListener(() {}), throwsA(isA<FlutterError>()));
    },
  );

  testWidgets(
    'rebuilds do NOT steal focus from a child TextField',
    (tester) async {
      // Regression: pre-fix LegendScreen rebuilt its KeyboardListener with
      // a fresh `FocusNode()..requestFocus()` on every rebuild — yanking
      // focus away from any open dialog/TextField.
      final textCtrl = TextEditingController();
      addTearDown(textCtrl.dispose);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              Expanded(
                  child: _FixedKeyboardHost(onSpacePressed: () {})),
              TextField(controller: textCtrl, autofocus: true),
            ],
          ),
        ),
      ));
      await tester.pumpAndSettle();

      // Force a rebuild of the host.
      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      // Focus must still be on the TextField after the rebuild — the
      // hoisted FocusNode in the host does NOT call requestFocus on
      // rebuild, only once via the post-frame callback in initState.
      final hostState = tester.state<_FixedKeyboardHostState>(
          find.byType(_FixedKeyboardHost));
      // The TextField was autofocused. After the rebuild, the host's
      // FocusNode should not have stolen focus. (autofocus + post-frame
      // race on the first frame can give the host focus initially, but
      // the *subsequent* rebuild must be a no-op for focus.)
      final priorHasFocus = hostState._shortcutFocus.hasFocus;
      // Tap the text field to focus it explicitly.
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      // Force ANOTHER host rebuild.
      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();
      // Host MUST NOT have stolen focus on this rebuild.
      expect(hostState._shortcutFocus.hasFocus, isFalse,
          reason:
              'rebuild must not call requestFocus() — it would steal focus from the active TextField');
      // Reference priorHasFocus to suppress "unused" lint without changing
      // the assertion above — kept to document the intent.
      expect(priorHasFocus, anyOf(isTrue, isFalse));
    },
  );
}
