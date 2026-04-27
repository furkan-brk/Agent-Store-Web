import 'package:get/get.dart';
import '../app/router.dart';
import '../shared/models/agent_model.dart';
import '../shared/services/api_service.dart';
import '../shared/services/wallet_service.dart';
import '../shared/services/collection_service.dart';
import '../shared/state/query_state.dart';

class LibraryController extends GetxController with QueryStatePersistence {
  final saved = <AgentModel>[].obs;
  final created = <AgentModel>[].obs;
  final credits = 0.obs;
  final isLoading = true.obs;
  final collections = <AgentCollection>[].obs;
  final selectedCollectionId = RxnString();
  final tabIndex = 0.obs;

  // ── URL-persisted view state (v3.7-7.1) ─────────────────────────────────
  /// Lower-cased search query. Updated by the screen on debounced keystrokes
  /// and by hydrate-from-URL on cold load.
  final searchQuery = ''.obs;
  /// 'newest' | 'oldest' | 'rarity' | 'category'
  final sortBy = 'newest'.obs;
  /// Empty string = all categories.
  final filterCategory = ''.obs;

  int get totalSaves => created.fold(0, (s, a) => s + a.saveCount);
  int get totalUses => created.fold(0, (s, a) => s + a.useCount);

  List<AgentModel> get filteredSaved {
    if (selectedCollectionId.value == null) return saved.toList();
    final col = collections.firstWhereOrNull((c) => c.id == selectedCollectionId.value);
    if (col == null) return saved.toList();
    return saved.where((a) => col.agentIds.contains(a.id)).toList();
  }

  // ── Query state persistence ──────────────────────────────────────────────
  @override
  Map<String, QueryFieldSpec> get queryFields => {
        'q': QueryFieldSpecs.string(
          read: () => searchQuery.value,
          write: (v) => searchQuery.value = v,
        ),
        'sort': QueryFieldSpecs.string(
          read: () => sortBy.value,
          write: (v) => sortBy.value = v,
          defaultValue: 'newest',
        ),
        'cat': QueryFieldSpecs.string(
          read: () => filterCategory.value,
          write: (v) => filterCategory.value = v,
        ),
        'tab': QueryFieldSpecs.int_(
          read: () => tabIndex.value,
          write: (v) => tabIndex.value = v,
        ),
        'col': QueryFieldSpecs.string(
          read: () => selectedCollectionId.value ?? '',
          write: (v) => selectedCollectionId.value = v.isEmpty ? null : v,
        ),
      };

  @override
  String currentUriString() =>
      AppRouter.router.routerDelegate.currentConfiguration.uri.toString();

  @override
  void pushUri(String uri) => AppRouter.router.replace(uri);

  // Setters that route through persistToQuery so the URL stays in sync.
  void setSearchQuery(String q) {
    searchQuery.value = q.toLowerCase().trim();
    persistToQuery();
  }

  void setSortBy(String s) {
    sortBy.value = s;
    persistToQuery();
  }

  void setFilterCategory(String c) {
    filterCategory.value = c;
    persistToQuery();
  }

  void setTabIndex(int i) {
    tabIndex.value = i;
    persistToQuery();
  }

  @override
  void onInit() {
    super.onInit();
    CollectionService.instance.getAll().then((all) => collections.value = all);
    if (ApiService.instance.isAuthenticated) {
      load();
    } else {
      isLoading.value = false;
    }
  }

  @override
  void onReady() {
    super.onReady();
    final uri = Uri.parse(currentUriString());
    hydrateFromQuery(uri.queryParameters);
  }

  Future<void> load() async {
    // Show spinner only on first load; silently refresh when stale data exists
    if (saved.isEmpty && created.isEmpty) isLoading.value = true;
    final wallet = WalletService.instance.connectedWallet ?? '';
    final results = await Future.wait([
      ApiService.instance.getLibrary(),
      if (wallet.isNotEmpty)
        ApiService.instance.listAgents(limit: 50, creatorWallet: wallet)
      else
        Future.value((agents: <AgentModel>[], total: 0)),
      ApiService.instance.getCredits(),
    ]);
    final savedList = results[0] as List<AgentModel>;
    final createdResult = results[1] as ({List<AgentModel> agents, int total});
    final c = results[2] as int;

    saved.value = savedList;
    created.value = createdResult.agents;
    credits.value = c;
    refreshCollections();
    isLoading.value = false;
  }

  Future<void> refreshCollections() async {
    collections.value = await CollectionService.instance.getAll();
    if (selectedCollectionId.value != null &&
        !collections.any((c) => c.id == selectedCollectionId.value)) {
      selectedCollectionId.value = null;
    }
  }

  void toggleCollection(String id) {
    selectedCollectionId.value = selectedCollectionId.value == id ? null : id;
    persistToQuery();
  }

  void updateAgentPrice(int agentId, double newPrice) {
    final idx = created.indexWhere((a) => a.id == agentId);
    if (idx == -1) return;
    created[idx] = created[idx].copyWith(price: newPrice);
  }
}
