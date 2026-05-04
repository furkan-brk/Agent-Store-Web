// lib/shared/services/wallet_errors.dart
//
// Maps raw MetaMask + Monad RPC error codes to user-facing strings,
// material icons, and an optional "next-action" hint (so the snackbar
// can surface a CTA — e.g. switching network when the chain ID is
// wrong). The opaque numeric codes leak through MetaMask's JSON-RPC
// envelope into Dart `Exception.toString()` output verbatim, so we
// match against substrings instead of trying to parse the JSON shape.
//
// Pure Dart — no Flutter imports beyond IconData so unit tests can
// exercise the mapping without bootstrapping a TestWidgetsFlutter
// binding.

import 'package:flutter/material.dart';

/// Single mapping entry for a known wallet/RPC error code.
class WalletError {
  /// Short, user-facing message — usually one sentence ending with a
  /// period. Should NOT mention "MetaMask" by name; "wallet" is the
  /// more inclusive term.
  final String userMessage;

  /// Suggestion icon for the snackbar. Defaults to a generic warning.
  final IconData icon;

  /// Optional action key for the caller to interpret (e.g. trigger a
  /// chain switch flow). When null, no CTA is offered.
  final String? action;

  const WalletError({
    required this.userMessage,
    this.icon = Icons.error_outline_rounded,
    this.action,
  });
}

/// Curated mapping of error codes we have observed from MetaMask + the
/// Monad testnet RPC. Keys are the literal substrings present in the
/// thrown Exception (numeric codes are matched as their string form).
const Map<String, WalletError> walletErrorMap = {
  '-32603': WalletError(
    userMessage: 'Wallet rejected the request. Please try again.',
    icon: Icons.refresh_rounded,
  ),
  '4001': WalletError(
    userMessage: 'You rejected the request.',
    icon: Icons.cancel_outlined,
  ),
  '4100': WalletError(
    userMessage: "This action isn't authorized for your wallet.",
    icon: Icons.lock_outline,
  ),
  '4901': WalletError(
    userMessage: 'Wallet disconnected from the Monad network.',
    icon: Icons.wifi_off_rounded,
    action: 'reconnect',
  ),
  '4902': WalletError(
    userMessage: 'Switch to Monad Testnet (chain 10143).',
    icon: Icons.swap_horiz_rounded,
    action: 'switch_chain',
  ),
  '-32002': WalletError(
    userMessage: 'Wallet is busy with another request. Please wait.',
    icon: Icons.hourglass_top_rounded,
  ),
  'network_error': WalletError(
    userMessage: 'Network connection lost. Check your internet.',
    icon: Icons.wifi_off_rounded,
  ),
  'insufficient_funds': WalletError(
    userMessage: 'Not enough MON for gas. Top up at the faucet.',
    icon: Icons.account_balance_wallet_outlined,
    action: 'open_faucet',
  ),
};

/// Translates an arbitrary error (typically `Object`/`Exception`) into
/// a human-friendly message string. Falls back to a "Wallet error: X"
/// envelope so the underlying message is still surfaced when no code
/// matches.
String friendlyError(Object? error) {
  return classifyWalletError(error).userMessage;
}

/// Returns the matched [WalletError] for [error], or a generic fallback
/// when nothing matches. Callers that need the icon / action key (not
/// just the text) should use this directly instead of [friendlyError].
WalletError classifyWalletError(Object? error) {
  if (error == null) {
    return const WalletError(
      userMessage: 'Wallet error: unknown.',
    );
  }
  final raw = error.toString();
  final lower = raw.toLowerCase();

  // Substring scan in declaration order. The map is small (<10 entries)
  // so a linear pass is the simplest correct implementation.
  for (final entry in walletErrorMap.entries) {
    final key = entry.key;
    // Numeric codes are stored as bare strings so the substring scan
    // catches them whether the wallet wraps them in quotes, parens,
    // or "code: -32603" envelopes.
    if (raw.contains(key) || lower.contains(key.toLowerCase())) {
      return entry.value;
    }
  }

  // Strip "Exception:" boilerplate so the fallback envelope reads
  // cleanly when the underlying exception is generic.
  String trimmed = raw;
  if (trimmed.startsWith('Exception:')) {
    trimmed = trimmed.substring('Exception:'.length).trim();
  }
  if (trimmed.isEmpty) trimmed = 'unknown';

  return WalletError(
    userMessage: 'Wallet error: $trimmed',
  );
}
