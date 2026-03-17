import 'dart:async';

import 'package:get/get.dart';
import '../shared/services/api_service.dart';
import '../shared/services/mission_service.dart';
import '../shared/services/wallet_service.dart';
import '../shared/services/notification_service.dart';
import '../features/legend/services/legend_service.dart';

class AuthController extends GetxController {
  static AuthController get to => Get.find();

  // ── Observable state ──────────────────────────────────────────────────────
  final isConnected = false.obs;
  final isConnecting = false.obs;
  final isBuyingCredits = false.obs;
  final isLoadingCredits = false.obs;
  final credits = 0.obs;
  final username = ''.obs;
  final bio = ''.obs;
  final error = RxnString();

  // ── Derived ───────────────────────────────────────────────────────────────
  String? get wallet => WalletService.instance.connectedWallet;
  String get shortWallet {
    final w = wallet ?? '';
    return w.length > 10 ? '${w.substring(0, 6)}...${w.substring(w.length - 4)}' : w;
  }

  @override
  void onInit() {
    super.onInit();
    _restoreSession();
  }

  /// Restores saved session from SharedPreferences + verifies MetaMask state.
  /// Called once on app startup from onInit().
  Future<void> _restoreSession() async {
    // Both ApiService.init() and WalletService.init() were awaited in main()
    // before AuthController is created, so their state is already populated.
    final hasToken = ApiService.instance.isAuthenticated;
    final hasWallet = WalletService.instance.isConnected;

    if (hasToken && hasWallet) {
      isConnected.value = true;
      await loadCredits();
    } else if (hasToken && !hasWallet) {
      // JWT exists but MetaMask no longer has the account.
      // Keep the token alive so background data sync (missions, legend
      // workflows) can still read/write the DB. The user just can't
      // perform wallet-specific actions until they reconnect MetaMask.
      isConnected.value = false;
    }
    // If neither token nor wallet, user is simply not logged in — nothing to do.
  }

  // ── Wallet connect flow ────────────────────────────────────────────────────
  Future<void> connect() async {
    isConnecting.value = true;
    error.value = null;

    final walletAddr = await WalletService.instance.connectWallet();
    if (walletAddr == null) {
      error.value = 'Connection failed. Install MetaMask.';
      isConnecting.value = false;
      return;
    }

    final nonce = await ApiService.instance.getNonce(walletAddr);
    if (nonce == null) {
      error.value = 'Server error: could not get nonce.';
      isConnecting.value = false;
      return;
    }

    final message = 'Sign in to Agent Store\n\nNonce: $nonce';
    final sig = await WalletService.instance.signMessage(message);
    if (sig == null) {
      error.value = 'Signature rejected.';
      isConnecting.value = false;
      return;
    }

    final result = await ApiService.instance.verifySignature(
      wallet: walletAddr, nonce: nonce, signature: sig,
    );
    if (result == null) {
      error.value = 'Authentication failed.';
      isConnecting.value = false;
      return;
    }

    final token = result['token'] as String?;
    if (token == null) {
      error.value = 'Invalid server response.';
      isConnecting.value = false;
      return;
    }

    ApiService.instance.setToken(token);
    isConnected.value = true;
    isConnecting.value = false;

    await NotificationService.instance.add('Wallet connected successfully!', type: 'save');
    await loadCredits();

    // Notify services about the new wallet so they switch to per-wallet
    // storage and sync local-only data created while offline.
    unawaited(MissionService.instance.onWalletChanged(walletAddr));
    unawaited(LegendService.instance.onWalletChanged(walletAddr));
  }

  void disconnect() {
    WalletService.instance.disconnect();
    ApiService.instance.clearToken();
    isConnected.value = false;
    credits.value = 0;
    username.value = '';
    bio.value = '';

    // Clear in-memory missions/workflows so the next wallet doesn't inherit them.
    MissionService.instance.onWalletChanged(null);
    LegendService.instance.onWalletChanged(null);
  }

  Future<void> loadCredits() async {
    isLoadingCredits.value = true;
    final results = await Future.wait([
      ApiService.instance.getCredits(),
      ApiService.instance.getUserProfile(),
    ]);
    credits.value = results[0] as int;
    final profile = results[1] as Map<String, dynamic>?;
    username.value = profile?['username'] as String? ?? '';
    bio.value = profile?['bio'] as String? ?? '';
    isLoadingCredits.value = false;
  }

  Future<void> topUp(double amountMon) async {
    const treasuryWallet = '0x0000000000000000000000000000000000000001';
    isBuyingCredits.value = true;
    try {
      final txHash = await WalletService.instance.sendTransaction(treasuryWallet, amountMon);
      if (txHash == null) { isBuyingCredits.value = false; return; }
      final result = await ApiService.instance.topUpCredits(txHash, amountMon);
      if (result != null) {
        credits.value = result['new_balance'] as int? ?? credits.value;
        Get.snackbar('Credits Added', '${(amountMon * 100).toInt()} credits added!',
            snackPosition: SnackPosition.BOTTOM);
      }
    } catch (_) {}
    isBuyingCredits.value = false;
  }

  Future<bool> updateProfile(String newUsername, String newBio) async {
    final ok = await ApiService.instance.updateProfile(
      username: newUsername, bio: newBio,
    );
    if (ok) {
      username.value = newUsername;
      bio.value = newBio;
    }
    return ok;
  }
}
