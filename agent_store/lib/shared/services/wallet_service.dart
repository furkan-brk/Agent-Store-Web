import 'dart:js_interop';

import 'package:flutter/foundation.dart';

// ── Top-level JS interop declarations ────────────────────────────────────────
// These map directly to window.agentStoreWallet.* functions defined in
// web/index.html.  They are only ever called when kIsWeb is true.

@JS('agentStoreWallet.requestAccounts')
external JSPromise<JSString> _nativeRequestAccounts();

@JS('agentStoreWallet.personalSign')
external JSPromise<JSString> _nativePersonalSign(JSString message, JSString address);

@JS('agentStoreWallet.switchToMonad')
external JSPromise<JSAny?> _nativeSwitchToMonad();

@JS('agentStoreWallet.sendTransaction')
external JSPromise<JSString> _nativeSendTransaction(JSString toAddress, JSString amountWei);

// ─────────────────────────────────────────────────────────────────────────────

/// Web3 wallet service — MetaMask integration via JS interop (web only).
/// The actual JS functions live in web/index.html as window.agentStoreWallet.
class WalletService {
  static WalletService? _instance;
  static WalletService get instance => _instance ??= WalletService._();
  WalletService._();

  String? _wallet;
  String? get connectedWallet => _wallet;
  bool get isConnected => _wallet != null;

  /// Requests MetaMask accounts and switches to Monad Testnet.
  /// Returns the connected wallet address, or null on failure.
  Future<String?> connectWallet() async {
    if (!kIsWeb) return null;
    try {
      // Switch chain first so MetaMask settles on the correct account for that chain.
      // Non-throwing in JS side — failures are logged as warnings only.
      await _jsSwitchToMonad();
      // Request accounts AFTER the chain switch so MetaMask returns the
      // account that is currently active on Monad (not on a different chain).
      final addr = await _jsRequestAccounts();
      if (addr == null) return null;
      _wallet = addr.toLowerCase();
      return _wallet;
    } catch (e) {
      debugPrint('connectWallet: $e');
      _wallet = null;
      return null;
    }
  }

  /// Signs [message] with the connected wallet via MetaMask personal_sign.
  /// Returns the hex signature string, or null on failure / user rejection.
  Future<String?> signMessage(String message) async {
    if (_wallet == null || !kIsWeb) return null;
    try {
      return await _jsPersonalSign(message, _wallet!);
    } catch (e) {
      debugPrint('signMessage: $e');
      return null;
    }
  }

  /// Sends [amountMon] MON tokens to [toAddress] via MetaMask.
  /// Returns the transaction hash, or null on failure/rejection.
  Future<String?> sendTransaction(String toAddress, double amountMon) async {
    if (_wallet == null || !kIsWeb) return null;
    try {
      // Convert MON to wei: 1 MON = 10^18 wei
      // Use BigInt to avoid floating point issues
      final amountWei = BigInt.from((amountMon * 1e18).round());
      final hexWei = '0x${amountWei.toRadixString(16)}';
      final result = await _nativeSendTransaction(toAddress.toJS, hexWei.toJS).toDart;
      return result.toDart;
    } catch (e) {
      debugPrint('sendTransaction: $e');
      return null;
    }
  }

  void disconnect() => _wallet = null;

  // ── JS bridge implementations ─────────────────────────────────────────────

  Future<String?> _jsRequestAccounts() async {
    final result = await _nativeRequestAccounts().toDart;
    return result.toDart;
  }

  Future<String?> _jsPersonalSign(String msg, String addr) async {
    final result = await _nativePersonalSign(msg.toJS, addr.toJS).toDart;
    return result.toDart;
  }

  Future<void> _jsSwitchToMonad() async {
    await _nativeSwitchToMonad().toDart;
  }
}
