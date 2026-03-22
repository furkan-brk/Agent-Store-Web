import 'package:get/get.dart';
import '../shared/models/agent_model.dart';
import '../shared/services/api_service.dart';
import '../shared/services/wallet_service.dart';
import '../shared/services/collection_service.dart';

class LibraryController extends GetxController {
  final saved = <AgentModel>[].obs;
  final created = <AgentModel>[].obs;
  final credits = 0.obs;
  final isLoading = true.obs;
  final collections = <AgentCollection>[].obs;
  final selectedCollectionId = RxnString();
  final tabIndex = 0.obs;

  int get totalSaves => created.fold(0, (s, a) => s + a.saveCount);
  int get totalUses => created.fold(0, (s, a) => s + a.useCount);

  List<AgentModel> get filteredSaved {
    if (selectedCollectionId.value == null) return saved.toList();
    final col = collections.firstWhereOrNull((c) => c.id == selectedCollectionId.value);
    if (col == null) return saved.toList();
    return saved.where((a) => col.agentIds.contains(a.id)).toList();
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
  }

  void updateAgentPrice(int agentId, double newPrice) {
    final idx = created.indexWhere((a) => a.id == agentId);
    if (idx == -1) return;
    created[idx] = created[idx].copyWith(price: newPrice);
  }
}
