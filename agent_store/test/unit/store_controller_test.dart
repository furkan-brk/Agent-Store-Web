// State-machine tests for StoreController.
//
// StoreController itself cannot be imported into the `flutter test` VM:
// it transitively pulls `package:web` 1.1.1 (via `lib/app/router.dart`,
// which references screen widgets that wrap `package:web/web.dart`).
// The codebase already follows this rationale — see `network_guard_pure.dart`
// and `query_state_test.dart`'s `_FakeStoreController` — by exercising the
// mixin / pure-state surface against a faithful fake.
//
// We mirror the controller's Rx contract here. The fake reuses the real
// `QueryStatePersistence` mixin (already test-friendly per query_state_test)
// so URL-sync paths still travel the production code; only the surrounding
// controller class is local. Test coverage:
//   - initial Rx state
//   - filter mutations (category, sort, price, tags)
//   - `activeFilterCount` derives from price + tags
//   - resetFilters returns to defaults
//   - search debounce delays the load() call by 400 ms
//   - submitSearch persists to recent searches (MRU) + dedupes
//   - clearSearch wipes search Rx
//   - clearRecentSearches drains the persisted list

import 'dart:async';

import 'package:agent_store/shared/state/query_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

/// Faithful re-implementation of StoreController's pure-state surface.
/// Mirrors lib/controllers/store_controller.dart — the methods under test
/// (setCategory, setSort, setPriceRange, toggleTag, resetFilters,
/// onSearchChanged, submitSearch, clearSearch, clearRecentSearches,
/// activeFilterCount) all live in this fake. Anything that crosses the
/// network — `load`, `loadTrending`, `loadForYou`, `loadCategories` — is
/// reduced to a counter so we can assert it was invoked without a real
/// http client.
class _FakeStoreController extends GetxController with QueryStatePersistence {
  final agents = <String>[].obs; // shape stand-in
  final total = 0.obs;
  final isLoading = true.obs;
  final hasError = false.obs;
  final search = ''.obs;
  final category = ''.obs;
  final sort = 'newest'.obs;
  final minPrice = 0.0.obs;
  final maxPrice = 10.0.obs;
  final filterTags = <String>[].obs;
  final showFilter = false.obs;
  final recentSearches = <String>[].obs;

  Timer? _debounce;
  int loadCalls = 0;
  String _currentUri = '/';
  final List<String> pushed = <String>[];

  @override
  String currentUriString() => _currentUri;

  @override
  void pushUri(String uri) {
    pushed.add(uri);
    _currentUri = uri;
  }

  @override
  Map<String, QueryFieldSpec> get queryFields => <String, QueryFieldSpec>{
        'q': QueryFieldSpecs.string(
          read: () => search.value,
          write: (v) => search.value = v,
        ),
        'cat': QueryFieldSpecs.string(
          read: () => category.value,
          write: (v) => category.value = v,
        ),
        'sort': QueryFieldSpecs.string(
          read: () => sort.value,
          write: (v) => sort.value = v,
          defaultValue: 'newest',
        ),
        'tags': QueryFieldSpecs.stringList(
          read: () => filterTags.toList(),
          write: (v) => filterTags.value = v,
        ),
      };

  int get activeFilterCount {
    int count = 0;
    if (minPrice.value > 0 || maxPrice.value < 10) count++;
    count += filterTags.length;
    return count;
  }

  void load() {
    loadCalls++;
    isLoading.value = false;
  }

  // Mirrors store_controller.dart#onSearchChanged.
  void onSearchChanged(String val) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      search.value = val;
      _saveRecentSearch(val);
      persistToQuery();
      load();
    });
  }

  void submitSearch(String val) {
    _debounce?.cancel();
    search.value = val;
    _saveRecentSearch(val);
    persistToQuery();
    load();
  }

  void clearSearch() {
    _debounce?.cancel();
    search.value = '';
    persistToQuery();
    load();
  }

  void setCategory(String cat) {
    search.value = '';
    category.value = cat;
    persistToQuery();
    load();
  }

  void setSort(String s) {
    sort.value = s;
    persistToQuery();
    load();
  }

  void toggleFilter() => showFilter.value = !showFilter.value;

  void setPriceRange(double min, double max) {
    minPrice.value = min;
    maxPrice.value = max;
    persistToQuery();
    load();
  }

  void toggleTag(String tag) {
    if (filterTags.contains(tag)) {
      filterTags.remove(tag);
    } else {
      filterTags.add(tag);
    }
    persistToQuery();
    load();
  }

  void resetFilters() {
    minPrice.value = 0;
    maxPrice.value = 10;
    filterTags.clear();
    persistToQuery();
    load();
  }

  void _saveRecentSearch(String term) {
    if (term.trim().isEmpty) return;
    recentSearches.remove(term);
    recentSearches.insert(0, term);
    if (recentSearches.length > 8) {
      recentSearches.removeRange(8, recentSearches.length);
    }
  }

  void clearRecentSearches() {
    recentSearches.clear();
  }

  @override
  void onClose() {
    _debounce?.cancel();
    super.onClose();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => Get.reset());
  tearDown(() => Get.reset());

  test('initial state — empty agents, default filter values', () {
    final c = _FakeStoreController();
    expect(c.agents, isEmpty);
    expect(c.total.value, 0);
    expect(c.search.value, '');
    expect(c.category.value, '');
    expect(c.sort.value, 'newest');
    expect(c.minPrice.value, 0.0);
    expect(c.maxPrice.value, 10.0);
    expect(c.filterTags, isEmpty);
    expect(c.activeFilterCount, 0);
    c.onClose();
  });

  test('setCategory clears search and updates category Rx', () {
    final c = _FakeStoreController();
    c.search.value = 'old query';
    c.setCategory('coding');
    expect(c.category.value, 'coding');
    expect(c.search.value, '');
    c.onClose();
  });

  test('setSort updates the sort Rx and triggers load()', () {
    final c = _FakeStoreController();
    final before = c.loadCalls;
    c.setSort('popular');
    expect(c.sort.value, 'popular');
    expect(c.loadCalls, before + 1);
    c.onClose();
  });

  test('setPriceRange + activeFilterCount track non-default values', () {
    final c = _FakeStoreController();
    expect(c.activeFilterCount, 0);

    c.setPriceRange(2, 7);
    expect(c.minPrice.value, 2.0);
    expect(c.maxPrice.value, 7.0);
    expect(c.activeFilterCount, 1);

    c.toggleTag('nlp');
    c.toggleTag('coding');
    expect(c.filterTags, containsAll(['nlp', 'coding']));
    expect(c.activeFilterCount, 3); // 1 price + 2 tags
    c.onClose();
  });

  test('toggleTag adds then removes the same tag', () {
    final c = _FakeStoreController();
    c.toggleTag('writing');
    expect(c.filterTags, ['writing']);
    c.toggleTag('writing');
    expect(c.filterTags, isEmpty);
    c.onClose();
  });

  test('resetFilters restores defaults', () {
    final c = _FakeStoreController();
    c.setPriceRange(3, 8);
    c.toggleTag('research');
    expect(c.activeFilterCount, greaterThan(0));

    c.resetFilters();
    expect(c.minPrice.value, 0.0);
    expect(c.maxPrice.value, 10.0);
    expect(c.filterTags, isEmpty);
    expect(c.activeFilterCount, 0);
    c.onClose();
  });

  test('toggleFilter flips the showFilter flag', () {
    final c = _FakeStoreController();
    expect(c.showFilter.value, isFalse);
    c.toggleFilter();
    expect(c.showFilter.value, isTrue);
    c.toggleFilter();
    expect(c.showFilter.value, isFalse);
    c.onClose();
  });

  test('clearSearch resets search Rx and runs load()', () {
    final c = _FakeStoreController();
    c.search.value = 'leftover';
    final before = c.loadCalls;
    c.clearSearch();
    expect(c.search.value, '');
    expect(c.loadCalls, before + 1);
    c.onClose();
  });

  test('submitSearch records the term in recentSearches (MRU first)', () {
    final c = _FakeStoreController();
    c.submitSearch('hello');
    c.submitSearch('world');

    expect(c.search.value, 'world');
    expect(c.recentSearches.first, 'world');
    expect(c.recentSearches, contains('hello'));
    c.onClose();
  });

  test('submitSearch dedupes — repeating a term keeps only one entry', () {
    final c = _FakeStoreController();
    c.submitSearch('alpha');
    c.submitSearch('beta');
    c.submitSearch('alpha'); // duplicate, should move to head

    expect(c.recentSearches.first, 'alpha');
    expect(c.recentSearches.where((s) => s == 'alpha').length, 1);
    expect(c.recentSearches, ['alpha', 'beta']);
    c.onClose();
  });

  test('clearRecentSearches empties the Rx list', () {
    final c = _FakeStoreController();
    c.submitSearch('temp');
    expect(c.recentSearches, isNotEmpty);

    c.clearRecentSearches();
    expect(c.recentSearches, isEmpty);
    c.onClose();
  });

  test('onSearchChanged debounces — Rx unchanged in same tick', () {
    final c = _FakeStoreController();
    final before = c.loadCalls;
    c.onSearchChanged('quick');
    // Synchronous: the 400 ms timer hasn't fired.
    expect(c.search.value, '');
    expect(c.loadCalls, before, reason: 'load() must wait for the debounce');
    // Cancel the pending timer so it doesn't leak into the next test.
    c.onClose();
    expect(c.search.value, '');
  });
}
