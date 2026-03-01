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
    collections.value = CollectionService.instance.getAll();
    if (ApiService.instance.isAuthenticated) load();
    else isLoading.value = false;
  }

  Future<void> load() async {
    // Show spinner only on first load; silently refresh when stale data exists
    if (saved.isEmpty && created.isEmpty) isLoading.value = true;
    final wallet = WalletService.instance.connectedWallet ?? '';
    final results = await Future.wait([
      ApiService.instance.getLibrary(),
      ApiService.instance.listAgents(limit: 50),
      ApiService.instance.getCredits(),
    ]);
    final savedList = results[0] as List<AgentModel>;
    final allAgents = (results[1] as ({List<AgentModel> agents, int total})).agents;
    final c = results[2] as int;
    final createdList = wallet.isNotEmpty
        ? allAgents.where((a) => a.creatorWallet.toLowerCase() == wallet.toLowerCase()).toList()
        : <AgentModel>[];

    saved.value = savedList;
    created.value = createdList;
    credits.value = c;
    refreshCollections();
    isLoading.value = false;
  }

  void refreshCollections() {
    collections.value = CollectionService.instance.getAll();
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
    final a = created[idx];
    created[idx] = AgentModel(
      id: a.id, title: a.title, description: a.description, prompt: a.prompt,
      category: a.category, creatorWallet: a.creatorWallet, characterType: a.characterType,
      subclass: a.subclass, rarity: a.rarity, stats: a.stats, traits: a.traits,
      tags: a.tags, useCount: a.useCount, saveCount: a.saveCount,
      generatedImage: a.generatedImage, createdAt: a.createdAt, price: newPrice,
    );
  }
}
