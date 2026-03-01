import 'dart:async';
import 'package:get/get.dart';
import '../shared/models/agent_model.dart';
import '../shared/services/api_service.dart';

class StoreController extends GetxController {
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

  Timer? _debounce;

  int get activeFilterCount {
    int count = 0;
    if (minPrice.value > 0 || maxPrice.value < 10) count++;
    count += filterTags.length;
    return count;
  }

  @override
  void onInit() {
    super.onInit();
    load();
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
      load();
    });
  }

  void clearSearch() {
    _debounce?.cancel();
    search.value = '';
    load();
  }

  void setCategory(String cat) {
    search.value = '';
    category.value = cat;
    load();
  }

  void setSort(String s) {
    sort.value = s;
    load();
  }

  void toggleFilter() => showFilter.value = !showFilter.value;

  void setPriceRange(double min, double max) {
    minPrice.value = min;
    maxPrice.value = max;
    load();
  }

  void toggleTag(String tag) {
    if (filterTags.contains(tag)) {
      filterTags.remove(tag);
    } else {
      filterTags.add(tag);
    }
    load();
  }

  void resetFilters() {
    minPrice.value = 0;
    maxPrice.value = 10;
    filterTags.clear();
    load();
  }

  void _saveRecentSearch(String term) {
    if (term.trim().isEmpty) return;
    recentSearches.remove(term);
    recentSearches.insert(0, term);
    if (recentSearches.length > 8) recentSearches.removeRange(8, recentSearches.length);
  }

  void clearRecentSearches() => recentSearches.clear();
}
