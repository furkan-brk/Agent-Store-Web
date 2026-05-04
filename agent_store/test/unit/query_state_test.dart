// Tests for QueryStatePersistence — the URL <-> reactive state mixin.
// Uses a fake subclass that overrides the GoRouter hooks so we don't have
// to spin up a router in unit tests, and `fake_async` to verify the 200 ms
// debounce coalesces rapid edits into a single push.

import 'package:agent_store/shared/state/query_state.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

class _FakeStoreController extends GetxController with QueryStatePersistence {
  String search = '';
  String category = '';
  int page = 0;
  List<String> tags = <String>[];

  // Overridden GoRouter hooks ------------------------------------------------
  String _currentUri = '/store';
  final List<String> pushed = <String>[];

  @override
  String currentUriString() => _currentUri;

  @override
  void pushUri(String uri) {
    pushed.add(uri);
    _currentUri = uri; // simulate the round-trip
  }

  // Spec --------------------------------------------------------------------
  @override
  Map<String, QueryFieldSpec> get queryFields => <String, QueryFieldSpec>{
        'q': QueryFieldSpecs.string(read: () => search, write: (v) => search = v),
        'cat': QueryFieldSpecs.string(read: () => category, write: (v) => category = v),
        'page': QueryFieldSpecs.int_(read: () => page, write: (v) => page = v),
        'tags': QueryFieldSpecs.stringList(read: () => tags, write: (v) => tags = v),
      };
}

void main() {
  group('QueryStatePersistence — encode / decode round-trip', () {
    test('hydrate populates string, int, and list fields', () {
      final c = _FakeStoreController();
      c.hydrateFromQuery({'q': 'hello', 'cat': 'wizard', 'page': '3', 'tags': 'a,b,c'});
      expect(c.search, 'hello');
      expect(c.category, 'wizard');
      expect(c.page, 3);
      expect(c.tags, ['a', 'b', 'c']);
    });

    test('missing keys fall back to defaults', () {
      final c = _FakeStoreController();
      c.search = 'preset';
      c.hydrateFromQuery(const {});
      expect(c.search, '');
      expect(c.category, '');
      expect(c.page, 0);
      expect(c.tags, isEmpty);
    });

    test('malformed int falls back to default', () {
      final c = _FakeStoreController();
      c.hydrateFromQuery({'page': 'not-a-number'});
      expect(c.page, 0);
    });

    test('empty list query string decodes to empty list', () {
      final c = _FakeStoreController();
      c.tags = const ['x'];
      c.hydrateFromQuery({'tags': ''});
      expect(c.tags, isEmpty);
    });

    test('list with empty segments drops them', () {
      final c = _FakeStoreController();
      c.hydrateFromQuery({'tags': 'a,,b,'});
      expect(c.tags, ['a', 'b']);
    });
  });

  group('QueryStatePersistence — debounce', () {
    test('5 rapid changes coalesce into a single push', () {
      fakeAsync((async) {
        final c = _FakeStoreController();
        for (var i = 0; i < 5; i++) {
          c.search = 's$i';
          c.persistToQuery();
        }
        // No timer has fired yet.
        expect(c.pushed, isEmpty);

        // Fast-forward past the 200 ms window.
        async.elapse(const Duration(milliseconds: 250));

        expect(c.pushed, hasLength(1));
        expect(c.pushed.single, contains('q=s4'));
      });
    });

    test('persistToQueryNow bypasses the debounce', () {
      final c = _FakeStoreController();
      c.search = 'now';
      c.persistToQueryNow();
      expect(c.pushed, hasLength(1));
      expect(c.pushed.single, contains('q=now'));
    });

    test('disposing cancels the pending debounce timer', () {
      fakeAsync((async) {
        final c = _FakeStoreController();
        c.search = 'pending';
        c.persistToQuery();
        c.onClose();
        async.elapse(const Duration(milliseconds: 500));
        expect(c.pushed, isEmpty);
      });
    });
  });

  group('QueryStatePersistence — push semantics', () {
    test('default-equal values are omitted from the URL', () {
      final c = _FakeStoreController();
      c.search = '';
      c.category = '';
      c.page = 0;
      c.tags = const [];
      c.persistToQueryNow();
      // URL didn't change (no params, current is still /store with no query).
      expect(c.pushed, isEmpty);
    });

    test('mixed default + non-default writes only the non-defaults', () {
      final c = _FakeStoreController();
      c.search = 'foo';
      c.category = ''; // default
      c.page = 0; // default
      c.tags = const ['design'];
      c.persistToQueryNow();
      expect(c.pushed, hasLength(1));
      final pushed = c.pushed.single;
      expect(pushed, contains('q=foo'));
      expect(pushed, contains('tags=design'));
      expect(pushed, isNot(contains('cat=')));
      expect(pushed, isNot(contains('page=')));
    });

    test('no-op write is suppressed when URL already matches', () {
      final c = _FakeStoreController();
      c.search = 'a';
      c.persistToQueryNow();
      expect(c.pushed, hasLength(1));
      // Second flush with the same state should not push again.
      c.persistToQueryNow();
      expect(c.pushed, hasLength(1));
    });

    test('hydrate during a push is suppressed (no loop)', () {
      // The mixin sets _suppressHydrate while it's pushing; verify that
      // re-entering hydrateFromQuery during pushUri is ignored. We simulate
      // by wiring pushUri to call hydrateFromQuery against the new URL.
      final c = _ReentrantController();
      c.search = 'foo';
      c.persistToQueryNow();
      expect(c.search, 'foo', reason: 'self-triggered hydrate must not run');
    });
  });
}

/// Subclass that re-enters hydrateFromQuery from inside pushUri to verify
/// the suppress flag prevents an infinite write/read loop.
class _ReentrantController extends GetxController with QueryStatePersistence {
  String search = '';

  @override
  Map<String, QueryFieldSpec> get queryFields => <String, QueryFieldSpec>{
        'q': QueryFieldSpecs.string(read: () => search, write: (v) => search = v),
      };

  @override
  String currentUriString() => '/store';

  @override
  void pushUri(String uri) {
    // While inside pushUri the mixin should be in suppressHydrate=true mode.
    // If the guard works, this hydrate call is a no-op and search keeps its
    // value. If the guard is broken, search would be reset to '' (the
    // default for the missing 'q' key in our fake URL).
    hydrateFromQuery(const <String, String>{});
  }
}
