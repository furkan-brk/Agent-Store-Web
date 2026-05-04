// Runtime chain-ID assertion for Monad testnet (chainID 10143). Surfaces
// a banner when the wallet is on the wrong network and exposes a one-tap
// switch via the existing wallet_service.dart helper.
//
// The pure decision logic ([computeNetworkState], [parseChainId],
// [NetworkState]) lives in network_guard_pure.dart so unit tests can
// exercise it without pulling wallet_service.dart's JS-interop chain.

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import 'network_guard_pure.dart';
import 'wallet_service.dart';

export 'network_guard_pure.dart' show NetworkState, computeNetworkState, parseChainId;

class NetworkGuard extends GetxController {
  /// Monad testnet chain ID (decimal). 0x279F == 10143.
  static const int expectedChainId = kExpectedChainId;

  /// True when the wallet's current chain matches [expectedChainId]. Defaults
  /// to true so the banner doesn't flash on cold start before we've heard
  /// from MetaMask.
  final RxBool onCorrectNetwork = true.obs;

  /// The most-recently observed chain ID, or null when MetaMask hasn't
  /// surfaced one yet (no wallet, no MetaMask installed, etc.).
  final RxnInt currentChainId = RxnInt();

  bool _listenerWired = false;

  /// Wires up MetaMask's `chainChanged` event listener and reads the
  /// current chain ID once. Safe to call multiple times — repeat calls
  /// are no-ops after the first successful subscription.
  ///
  /// On non-web targets this is a no-op (MetaMask is web-only).
  Future<void> initListener() async {
    if (!kIsWeb) return;
    final chainId = await readCurrentChainId();
    _applyChainId(chainId);
    if (_listenerWired) return;
    _listenerWired = true;
    // Push-side subscription via the agentStoreWallet bridge
    // (extended in v3.7-8.3).
    WalletService.instance.subscribeChainChanged(updateFromChainChanged);
  }

  /// Reads `window.ethereum.chainId` once via the agentStoreWallet bridge.
  /// Returns null when MetaMask is unavailable or the call fails.
  Future<int?> readCurrentChainId() async {
    if (!kIsWeb) return null;
    final raw = await WalletService.instance.readChainId();
    return parseChainId(raw);
  }

  /// Returns true when the wallet is currently on Monad testnet. Side-effect:
  /// updates [onCorrectNetwork] / [currentChainId] from the freshly-read value.
  Future<bool> assertCorrectNetwork() async {
    final chainId = await readCurrentChainId();
    _applyChainId(chainId);
    return onCorrectNetwork.value;
  }

  /// Asks MetaMask to switch to Monad testnet. Delegates to the existing
  /// `window.agentStoreWallet.switchToMonad` helper. Best-effort.
  Future<void> requestSwitchToMonad() async {
    if (!kIsWeb) return;
    try {
      await WalletService.instance.connectWallet();
    } catch (e) {
      debugPrint('NetworkGuard.requestSwitchToMonad: $e');
    }
    await assertCorrectNetwork();
  }

  /// Push-side hook: call this from the `chainChanged` event handler
  /// (wired up in v3.7-8.3) with the new chainId payload (hex or decimal).
  void updateFromChainChanged(String rawChainId) {
    final parsed = parseChainId(rawChainId);
    _applyChainId(parsed);
  }

  void _applyChainId(int? chainId) {
    final next = computeNetworkState(chainId);
    currentChainId.value = next.currentChainId;
    onCorrectNetwork.value = next.onCorrectNetwork;
  }
}
