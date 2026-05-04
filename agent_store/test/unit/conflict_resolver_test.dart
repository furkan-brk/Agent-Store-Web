// Tests for ConflictResolver — verifies that dispatch logic matches the
// spec across the four resolution paths (200 / keepMine / takeTheirs /
// cancel) and that ConflictCancelled is thrown for cancel.
//
// We mount a tiny host widget to obtain a real BuildContext for the dialog
// path, then drive the dialog buttons via tester.tap.

import 'dart:async';

import 'package:agent_store/shared/services/conflict_resolver.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Resource {
  final int revision;
  final String name;
  const _Resource(this.revision, this.name);
  static _Resource fromJson(Map<String, dynamic> j) =>
      _Resource(j['revision'] as int, j['name'] as String);
}

/// Mounts a button, taps it (which kicks off the ConflictResolver call),
/// and returns the [Completer] whose future will fire with the resolver's
/// outcome. Caller awaits this helper so the widget mount + button tap
/// finish before any subsequent `pumpAndSettle`. The completer's future
/// stays pending until the resolver finishes, which happens in response
/// to dialog interactions later in the test.
Future<Completer<_Resource>> _runResolver(
  WidgetTester tester, {
  required Future<_Resource> Function(int? ifMatch) request,
  int currentRevision = 1,
}) async {
  final completer = Completer<_Resource>();
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (ctx) {
          return Scaffold(
            body: ElevatedButton(
              onPressed: () async {
                try {
                  final r = await ConflictResolver().resolve<_Resource>(
                    context: ctx,
                    request: request,
                    currentRevision: currentRevision,
                    parseResource: _Resource.fromJson,
                    resourceTypeLabel: 'agent card',
                    localLabel: 'Your draft',
                  );
                  completer.complete(r);
                } catch (e) {
                  completer.completeError(e);
                }
              },
              child: const Text('go'),
            ),
          );
        },
      ),
    ),
  );
  await tester.tap(find.text('go'));
  return completer;
}

void main() {
  testWidgets('200 path returns resource directly without dialog', (tester) async {
    final c = await _runResolver(
      tester,
      request: (rev) async => const _Resource(1, 'mine'),
    );
    await tester.pumpAndSettle();
    final r = await c.future;
    expect(r.revision, 1);
    expect(r.name, 'mine');
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('409 + keepMine triggers a second request with new revision',
      (tester) async {
    var calls = 0;
    var lastIfMatch = -999;
    final c = await _runResolver(
      tester,
      request: (rev) async {
        calls++;
        lastIfMatch = rev ?? -1;
        if (calls == 1) {
          throw ConflictException({'revision': 7, 'name': 'theirs'});
        }
        return const _Resource(8, 'merged');
      },
    );
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);

    await tester.tap(find.text('Keep mine'));
    await tester.pumpAndSettle();

    final r = await c.future;
    expect(calls, 2);
    expect(lastIfMatch, 7, reason: 'second request must use server revision');
    expect(r.revision, 8);
    expect(r.name, 'merged');
  });

  testWidgets('409 + takeTheirs returns server resource without re-PATCH',
      (tester) async {
    var calls = 0;
    final c = await _runResolver(
      tester,
      request: (rev) async {
        calls++;
        throw ConflictException({'revision': 9, 'name': 'theirs'});
      },
    );
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);

    await tester.tap(find.text('Take theirs'));
    await tester.pumpAndSettle();

    final r = await c.future;
    expect(calls, 1, reason: 'no second request — we accept the server copy');
    expect(r.revision, 9);
    expect(r.name, 'theirs');
  });

  testWidgets('409 + cancel throws ConflictCancelled', (tester) async {
    final c = await _runResolver(
      tester,
      request: (rev) async {
        throw ConflictException({'revision': 9, 'name': 'theirs'});
      },
    );
    // Subscribe to the future BEFORE the user action that completes it with
    // an error — otherwise Dart treats the error as uncaught at the moment
    // of completeError() and the test framework fails the test.
    final cancelled = expectLater(c.future, throwsA(isA<ConflictCancelled>()));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    await cancelled;
  });

  testWidgets('409 + merge re-PATCHes with new revision (default behaviour)',
      (tester) async {
    var calls = 0;
    var lastIfMatch = -999;
    final c = await _runResolver(
      tester,
      request: (rev) async {
        calls++;
        lastIfMatch = rev ?? -1;
        if (calls == 1) {
          throw ConflictException({'revision': 5, 'name': 'theirs'});
        }
        return const _Resource(6, 'merged');
      },
    );
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);

    await tester.tap(find.text('Merge'));
    await tester.pumpAndSettle();

    final r = await c.future;
    expect(calls, 2);
    expect(lastIfMatch, 5);
    expect(r.name, 'merged');
  });
}
