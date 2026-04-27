import 'dart:async';
import 'dart:convert';
import 'package:get/get.dart';
import '../app/router.dart';
import '../shared/models/agent_model.dart';
import '../shared/services/api_service.dart';
import '../shared/services/local_kv_store.dart';
import '../shared/state/query_state.dart';

class StoreController extends GetxController with QueryStatePersistence {
  // ── State ─────────────────────────────────────────────────────────────────
  final agents = <AgentModel>[].obs;
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

  // ── Categories ───────────────────────────────────────────────────────────
  final categories = <Map<String, dynamic>>[].obs;

  // ── Trending ──────────────────────────────────────────────────────────────
  final trendingAgents = <AgentModel>[].obs;
  final trendingLoading = true.obs;

  Timer? _debounce;

  int get activeFilterCount {
    int count = 0;
    if (minPrice.value > 0 || maxPrice.value < 10) count++;
    count += filterTags.length;
    return count;
  }

  static const _kRecentSearchesKey = 'recent_searches';

  // ── Query state persistence ──────────────────────────────────────────────
  // Sync filter/search/sort to URL query params so deep-links and back/forward
  // navigation restore the user's view. Foundation primitive (v3.7-FND).
  @override
  Map<String, QueryFieldSpec> get queryFields => {
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
        // Price range as comma-separated min,max so it travels as one key.
        'price': QueryFieldSpec<List<double>>(
          read: () => [minPrice.value, maxPrice.value],
          write: (v) {
            if (v.length == 2) {
              minPrice.value = v[0];
              maxPrice.value = v[1];
            }
          },
          encode: (v) {
            if (v.length != 2) return '';
            // Default range is 0..10 — omit from URL when unchanged.
            if (v[0] == 0 && v[1] == 10) return '';
            return '${v[0]},${v[1]}';
          },
          decode: (s) {
            if (s.isEmpty) return const [0, 10];
            final parts = s.split(',');
            if (parts.length != 2) return const [0, 10];
            final lo = double.tryParse(parts[0]) ?? 0;
            final hi = double.tryParse(parts[1]) ?? 10;
            return [lo, hi];
          },
          defaultValue: const [0, 10],
        ),
      };

  @override
  String currentUriString() =>
      AppRouter.router.routerDelegate.currentConfiguration.uri.toString();

  @override
  void pushUri(String uri) => AppRouter.router.replace(uri);

  @override
  void onInit() {
    super.onInit();
    _loadRecentSearches();
    loadCategories();
    loadTrending();
    load();
  }

  @override
  void onReady() {
    super.onReady();
    // Hydrate from URL once the router has settled. If the user landed on
    // /?q=research&cat=wizard&sort=popular this restores all of them and
    // re-runs load() with the restored filters.
    final uri = Uri.parse(currentUriString());
    hydrateFromQuery(uri.queryParameters);
    if (uri.queryParameters.isNotEmpty) {
      // hydrate mutated filters silently — pull the matching list now.
      load();
    }
  }

  Future<void> loadCategories() async {
    try {
      final result = await ApiService.instance.getCategories();
      categories.value = result;
    } catch (_) {}
  }

  Future<void> loadTrending() async {
    // Skip if already loaded (controller is permanent)
    if (trendingAgents.isNotEmpty) return;
    trendingLoading.value = true;
    try {
      final list = await ApiService.instance.getTrending();
      trendingAgents.value = list;
    } catch (_) {}
    trendingLoading.value = false;
  }

  Future<void> _loadRecentSearches() async {
    try {
      final raw = await LocalKvStore.instance.getString(_kRecentSearchesKey) ?? '[]';
      recentSearches.value = (jsonDecode(raw) as List).cast<String>().take(8).toList();
    } catch (_) {}
  }

  @override
  void onClose() {
    _debounce?.cancel();
    super.onClose();
  }

  Future<void> load() async {
    // Show spinner only on first load; silently refresh when stale data exists
    if (agents.isEmpty) isLoading.value = true;
    hasError.value = false;
    try {
      final r = await ApiService.instance.listAgents(
        category: category.value,
        search: search.value,
        sort: sort.value,
        minPrice: minPrice.value > 0 ? minPrice.value : null,
        maxPrice: maxPrice.value < 10 ? maxPrice.value : null,
        tags: filterTags.isNotEmpty ? filterTags.toList() : null,
      );
      agents.value = r.agents;
      total.value = r.total;
    } catch (_) {
      if (agents.isEmpty) hasError.value = true;
    }
    isLoading.value = false;
  }

  void onSearchChanged(String val) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      search.value = val;
      _saveRecentSearch(val);
      persistToQuery();
      load();
    });
  }

  /// Immediately submit a search (enter key, tag click, recent search chip).
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
    if (recentSearches.length > 8) recentSearches.removeRange(8, recentSearches.length);
    LocalKvStore.instance.setString(_kRecentSearchesKey, jsonEncode(recentSearches.toList()));
  }

  void clearRecentSearches() {
    recentSearches.clear();
    LocalKvStore.instance.remove(_kRecentSearchesKey);
  }
}
