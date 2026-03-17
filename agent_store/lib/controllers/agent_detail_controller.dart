import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../shared/models/agent_model.dart';
import '../shared/services/api_service.dart';
import '../shared/services/notification_service.dart';
import '../shared/services/wallet_service.dart';

class AgentDetailController extends GetxController {
  final int agentId;
  AgentDetailController(this.agentId);

  final agent = Rxn<AgentModel>();
  final similar = <AgentModel>[].obs;
  final isLoading = true.obs;
  final inLibrary = false.obs;
  final isPurchased = false.obs;
  final isForkLoading = false.obs;
  final isPurchaseLoading = false.obs;
  final isLibraryLoading = false.obs;
  final credits = 999.obs;
  final copied = false.obs;

  // ── Trial state (encrypted CLI flow) ─────────────────────────────────────
  final isTrialLoading = false.obs;
  final trialUsed = false.obs;
  final trialCommand = Rxn<String>();
  final trialToken = Rxn<String>();
  final selectedTool = 'claude'.obs;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    isLoading.value = true;
    try {
      final futures = <Future<dynamic>>[
        ApiService.instance.getAgent(agentId),
      ];
      if (ApiService.instance.isAuthenticated) {
        futures.addAll([
          ApiService.instance.getPurchaseStatus(agentId),
          ApiService.instance.getLibrary(),
          ApiService.instance.getCredits(),
        ]);
      }
      final results = await Future.wait(futures);

      agent.value = results[0] as AgentModel?;

      if (results.length > 1) {
        isPurchased.value = results[1] as bool? ?? false;
        final library = results[2] as List<AgentModel>? ?? [];
        inLibrary.value = library.any((m) => m.id == agentId);
        credits.value = results[3] as int? ?? 999;
      }

      // Load similar agents
      if (agent.value != null) {
        try {
          final result = await ApiService.instance.listAgents(
            category: agent.value!.category,
            limit: 9,
          );
          similar.value = result.agents
              .where((m) => m.id != agentId)
              .take(8)
              .toList();
        } catch (_) {}
      }
    } catch (_) {}
    isLoading.value = false;
  }

  Future<void> toggleLibrary() async {
    if (!ApiService.instance.isAuthenticated) return;
    isLibraryLoading.value = true;
    if (inLibrary.value) {
      final ok = await ApiService.instance.removeFromLibrary(agentId);
      if (ok) inLibrary.value = false;
    } else {
      final ok = await ApiService.instance.addToLibrary(agentId);
      if (ok) {
        inLibrary.value = true;
        await NotificationService.instance.add('Agent saved to library!', type: 'save');
      }
    }
    isLibraryLoading.value = false;
  }

  Future<void> copyPrompt() async {
    final p = agent.value?.prompt;
    if (p == null) return;
    await Clipboard.setData(ClipboardData(text: p));
    copied.value = true;
    await Future.delayed(const Duration(seconds: 2));
    copied.value = false;
  }

  Future<AgentModel?> forkAgent() async {
    isForkLoading.value = true;
    final forked = await ApiService.instance.forkAgent(agentId);
    isForkLoading.value = false;
    return forked;
  }

  Future<bool> purchaseAgent(String txHash, double amountMon) async {
    isPurchaseLoading.value = true;
    final ok = await ApiService.instance.purchaseAgent(agentId, txHash, amountMon: amountMon);
    if (ok) {
      isPurchased.value = true;
      // Reload the agent to get the full prompt now that it is owned
      await load();
    }
    isPurchaseLoading.value = false;
    return ok;
  }

  bool get canFork => credits.value >= 5;

  /// True when the user is authenticated (wallet connected + JWT valid).
  bool get isLibraryAvailable => ApiService.instance.isAuthenticated;

  bool get isOwnAgent {
    final wallet = WalletService.instance.connectedWallet ?? '';
    final a = agent.value;
    if (a == null) return false;
    return a.creatorWallet.toLowerCase() == wallet.toLowerCase();
  }

  /// True when the user has access to the full prompt (creator, purchased, or free agent).
  bool get hasAccess {
    final a = agent.value;
    if (a == null) return false;
    if (isOwnAgent) return true;
    if (isPurchased.value) return true;
    if (a.owned) return true;
    if (a.price <= 0) return true;
    return false;
  }

  /// Generates an encrypted trial token and CLI command. The user pastes the
  /// command into their terminal; it downloads a Node.js script that runs
  /// locally with their own API key. The prompt never leaves the server
  /// unencrypted.
  Future<void> generateTrial(String message) async {
    if (isTrialLoading.value || trialUsed.value) return;
    isTrialLoading.value = true;
    try {
      final result = await ApiService.instance.generateTrialToken(
        agentId,
        selectedTool.value,
        message,
      );
      if (result != null) {
        trialCommand.value = result['command'] as String?;
        trialToken.value = result['token'] as String?;
      }
    } catch (e) {
      if (e.toString().contains('Trial already used')) {
        trialUsed.value = true;
      }
    } finally {
      isTrialLoading.value = false;
    }
  }

  Future<bool> rateAgent(int rating, {String comment = ''}) async {
    return ApiService.instance.rateAgent(agentId, rating, comment: comment);
  }
}
