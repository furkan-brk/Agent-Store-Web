import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../features/agent_detail/widgets/purchase_button.dart' show TxState, TxStateX;
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

  // v3.11.1 — Prompt is shown in preview form (first 500 chars) when ≥500
  // chars long. User toggles to expand the full body — telemetry hookup
  // (RecordActivity prompt_view_full event) is deferred to v3.11.3 KPI sprint.
  final promptShowFull = false.obs;

  // ── Purchase tx state machine (v3.7) ────────────────────────────────────
  // Surfaces the four legs of a purchase (signing, mempool, reconcile,
  // settled) separately so the UI can show distinct copy + an explorer link.
  // The legacy [isPurchaseLoading] bool stays in sync with [txState.isInFlight]
  // so the existing inline call sites keep working without refactor.
  final txState = TxState.idle.obs;
  final txHash = Rxn<String>();
  final txFailureReason = Rxn<String>();

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
      // Fetch agent data (always)
      final agentFuture = ApiService.instance.getAgent(agentId);

      // Fetch auth-dependent data in parallel when authenticated
      Future<bool>? purchaseFuture;
      Future<List<AgentModel>>? libraryFuture;
      Future<int>? creditsFuture;
      if (ApiService.instance.isAuthenticated) {
        purchaseFuture = ApiService.instance.getPurchaseStatus(agentId);
        libraryFuture = ApiService.instance.getLibrary();
        creditsFuture = ApiService.instance.getCredits();
      }

      agent.value = await agentFuture;

      if (purchaseFuture != null) {
        isPurchased.value = await purchaseFuture;
        final library = await libraryFuture ?? [];
        inLibrary.value = library.any((m) => m.id == agentId);
        credits.value = await creditsFuture ?? 999;
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
    if (isClosed) return;
    copied.value = true;
    await Future.delayed(const Duration(seconds: 2));
    if (isClosed) return;
    copied.value = false;
  }

  Future<AgentModel?> forkAgent() async {
    isForkLoading.value = true;
    final forked = await ApiService.instance.forkAgent(agentId);
    isForkLoading.value = false;
    return forked;
  }

  Future<bool> purchaseAgent(String hash, double amountMon) async {
    isPurchaseLoading.value = true;
    final ok = await ApiService.instance.purchaseAgent(agentId, hash, amountMon: amountMon);
    if (ok) {
      isPurchased.value = true;
      // Reload the agent to get the full prompt now that it is owned
      await load();
    }
    isPurchaseLoading.value = false;
    return ok;
  }

  /// Resets the tx state machine to [TxState.idle]. Called when the user
  /// dismisses a failure or starts a fresh purchase. Does not clear
  /// [isPurchased] — that's a server-confirmed flag, not a tx-machine flag.
  void resetTxState() {
    txState.value = TxState.idle;
    txHash.value = null;
    txFailureReason.value = null;
    isPurchaseLoading.value = false;
  }

  /// Drives a purchase end-to-end through the tx state machine.
  ///
  /// Steps:
  ///   1. signingPending — wallet popup. On reject → failed.
  ///   2. txPending      — wallet returned a hash; chain hasn't included it.
  ///   3. confirming     — backend reconciles the on-chain tx.
  ///   4. confirmed      — purchase recorded, agent reloaded, ownership flips.
  ///
  /// Each leg sets [txState], [txHash], or [txFailureReason] so the UI can
  /// render the correct pill and explorer link without polling internals.
  Future<bool> purchaseAgentFlow({
    required String creatorWallet,
    required double priceMon,
  }) async {
    if (txState.value.isInFlight) return false;
    resetTxState();
    txState.value = TxState.signingPending;
    isPurchaseLoading.value = true;
    try {
      final hash = await WalletService.instance.sendTransaction(creatorWallet, priceMon);
      if (hash == null || hash.isEmpty) {
        txState.value = TxState.failed;
        txFailureReason.value = 'Transaction cancelled in wallet.';
        isPurchaseLoading.value = false;
        return false;
      }
      txHash.value = hash;
      txState.value = TxState.txPending;

      // Brief pause so the user actually perceives the txPending state — the
      // backend reconcile usually starts within one block; we don't try to
      // poll the chain ourselves, we let the backend verify.
      txState.value = TxState.confirming;
      final ok = await ApiService.instance.purchaseAgent(agentId, hash, amountMon: priceMon);
      if (!ok) {
        txState.value = TxState.failed;
        txFailureReason.value = 'Backend could not confirm the transaction. The funds are safe — please retry.';
        isPurchaseLoading.value = false;
        return false;
      }
      isPurchased.value = true;
      await load();
      txState.value = TxState.confirmed;
      isPurchaseLoading.value = false;
      return true;
    } catch (e) {
      txState.value = TxState.failed;
      txFailureReason.value = 'Unexpected error: $e';
      isPurchaseLoading.value = false;
      return false;
    }
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
