import 'package:get/get.dart';
import '../shared/models/agent_model.dart';
import '../shared/services/api_service.dart';
import '../shared/services/wallet_service.dart';

class CreatorController extends GetxController {
  final agents = <AgentModel>[].obs;
  final isLoading = true.obs;
  final error = RxnString();
  final searchQuery = ''.obs;

  int get totalSaves => agents.fold(0, (s, a) => s + a.saveCount);
  int get totalUses => agents.fold(0, (s, a) => s + a.useCount);
  double get totalRevenue => agents.fold(0.0, (s, a) => s + (a.price > 0 ? a.price : 0.0));

  void setSearchQuery(String q) => searchQuery.value = q;

  List<AgentModel> get filteredAgents {
    if (searchQuery.value.isEmpty) return agents;
    final q = searchQuery.value.toLowerCase();
    return agents.where((a) =>
      a.title.toLowerCase().contains(q) ||
      a.description.toLowerCase().contains(q)
    ).toList();
  }

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    if (!ApiService.instance.isAuthenticated) {
      isLoading.value = false;
      return;
    }
    isLoading.value = true;
    error.value = null;
    final data = await ApiService.instance.getUserProfile();
    if (data != null) {
      final rawAgents = data['created_agents'] as List<dynamic>? ?? [];
      agents.value = rawAgents.map((e) => AgentModel.fromJson(e as Map<String, dynamic>)).toList();
    } else {
      error.value = 'Failed to load creator stats.';
    }
    isLoading.value = false;
  }

  // Helper for wallet-based ownership check used in the creator table
  bool isOwner(AgentModel agent) {
    final w = WalletService.instance.connectedWallet;
    return w != null && agent.creatorWallet.toLowerCase() == w.toLowerCase();
  }
}
