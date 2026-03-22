import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'local_kv_store.dart';

// ── Top-level JS interop declarations ────────────────────────────────────────
// These map directly to window.agentStoreWallet.* functions defined in
// web/index.html.  They are only ever called when kIsWeb is true.

@JS('agentStoreWallet.requestAccounts')
external JSPromise<JSString> _nativeRequestAccounts();

@JS('agentStoreWallet.getAccounts')
external JSPromise<JSString> _nativeGetAccounts();

@JS('agentStoreWallet.personalSign')
external JSPromise<JSString> _nativePersonalSign(JSString message, JSString address);

@JS('agentStoreWallet.switchToMonad')
external JSPromise<JSAny?> _nativeSwitchToMonad();

@JS('agentStoreWallet.sendTransaction')
external JSPromise<JSString> _nativeSendTransaction(JSString toAddress, JSString amountWei);

// ─────────────────────────────────────────────────────────────────────────────

const _kWalletKey = 'wallet_address';

/// Web3 wallet service — MetaMask integration via JS interop (web only).
/// The actual JS functions live in web/index.html as window.agentStoreWallet.
class WalletService {
  static WalletService? _instance;
  static WalletService get instance => _instance ??= WalletService._();
  WalletService._();

  String? _wallet;
  String? get connectedWallet => _wallet;
  bool get isConnected => _wallet != null;

  /// Call once at app startup to restore a previously saved wallet address.
  /// After restoring from LocalKvStore, silently verifies that MetaMask
  /// still has the account connected via `eth_accounts` (no popup).
  /// If MetaMask no longer exposes the saved account, clears the stored value.
  Future<void> init() async {
    final savedWallet = await LocalKvStore.instance.getString(_kWalletKey);
    if (savedWallet == null || savedWallet.isEmpty) return;

    if (kIsWeb) {
      // Silently check if MetaMask still has this account connected
      final currentAccount = await _jsGetAccounts();
      if (currentAccount != null &&
          currentAccount.isNotEmpty &&
          currentAccount.toLowerCase() == savedWallet.toLowerCase()) {
        _wallet = savedWallet;
        debugPrint('WalletService.init: restored wallet $savedWallet');
      } else {
        // MetaMask no longer has this account connected — clear stored data
        debugPrint(
            'WalletService.init: MetaMask account mismatch or disconnected, clearing stored wallet');
        await LocalKvStore.instance.remove(_kWalletKey);
      }
    } else {
      // Non-web: just restore from prefs (no MetaMask to check)
      _wallet = savedWallet;
    }
  }

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
      // Persist to LocalKvStore so it survives page refresh
      await LocalKvStore.instance.setString(_kWalletKey, _wallet!);
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
      // Avoid floating-point precision loss by splitting into integer + fraction parts
      final monStr = amountMon.toStringAsFixed(18);
      final parts = monStr.split('.');
      final intPart = BigInt.parse(parts[0]);
      final fracStr = parts.length > 1
          ? parts[1].padRight(18, '0').substring(0, 18)
          : '0' * 18;
      final fracPart = BigInt.parse(fracStr);
      final amountWei = intPart * BigInt.from(10).pow(18) + fracPart;
      final hexWei = '0x${amountWei.toRadixString(16)}';
      final result =
          await _nativeSendTransaction(toAddress.toJS, hexWei.toJS).toDart;
      return result.toDart;
    } catch (e) {
      debugPrint('sendTransaction: $e');
      return null;
    }
  }

  Future<void> disconnect() async {
    _wallet = null;
    // Clear persisted wallet address
    await LocalKvStore.instance.remove(_kWalletKey);
  }

  // ── JS bridge implementations ─────────────────────────────────────────────

  Future<String?> _jsRequestAccounts() async {
    final result = await _nativeRequestAccounts().toDart;
    return result.toDart;
  }

  /// Silently checks which account MetaMask currently exposes (no popup).
  /// Returns the account address or null/empty if none.
  Future<String?> _jsGetAccounts() async {
    try {
      final result = await _nativeGetAccounts().toDart;
      return result.toDart;
    } catch (e) {
      debugPrint('_jsGetAccounts: $e');
      return null;
    }
  }

  Future<String?> _jsPersonalSign(String msg, String addr) async {
    final result = await _nativePersonalSign(msg.toJS, addr.toJS).toDart;
    return result.toDart;
  }

  Future<void> _jsSwitchToMonad() async {
    await _nativeSwitchToMonad().toDart;
  }
}
