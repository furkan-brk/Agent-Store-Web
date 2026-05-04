// lib/features/agent_detail/widgets/tx_state.dart
//
// Pure-Dart TxState enum + behaviour extension. Lifted out of
// purchase_button.dart so unit tests can exercise the state machine
// without pulling package:web's `dart:js_interop` chain (which blocks
// `flutter test` on non-web targets).
//
// purchase_button.dart re-exports these so existing imports keep working.

import 'package:flutter/material.dart';

import '../../../app/theme.dart';

/// Discrete states a purchase transaction can be in. The flow is strictly
/// linear in the happy path: idle → signingPending → txPending → confirming
/// → confirmed. Any leg can transition to [failed]; a manual reset returns
/// to [idle] (e.g. for retry).
enum TxState {
  /// No transaction in flight. The button is the standard call-to-action.
  idle,

  /// Wallet popup is open. The user is being asked to sign the tx.
  /// On reject we go to [failed]; on accept we receive the txHash and move
  /// to [txPending].
  signingPending,

  /// Tx is in the Monad mempool — the wallet returned a hash but the chain
  /// hasn't included it in a block yet. UI shows a hash link to the explorer.
  txPending,

  /// Backend is reconciling the tx (verifying it on-chain, crediting the
  /// purchase, updating ownership). Usually <1s; surfaced separately so a
  /// stuck reconcile doesn't look like a stuck tx.
  confirming,

  /// Purchase recorded server-side; the agent is now owned. Terminal state.
  confirmed,

  /// Any leg failed (rejected signature, dropped tx, backend error). Carries
  /// an optional human-readable reason for the SnackBar / inline message.
  failed,
}

extension TxStateX on TxState {
  bool get isInFlight =>
      this == TxState.signingPending ||
      this == TxState.txPending ||
      this == TxState.confirming;

  /// User-facing label suitable for a button or pill. Keep terse — full
  /// rationale belongs in surrounding copy / tooltips.
  String get label {
    switch (this) {
      case TxState.idle:
        return 'Purchase';
      case TxState.signingPending:
        return 'Confirm in wallet…';
      case TxState.txPending:
        return 'Sending on-chain…';
      case TxState.confirming:
        return 'Verifying…';
      case TxState.confirmed:
        return 'Purchased';
      case TxState.failed:
        return 'Failed — retry';
    }
  }

  /// Background tint for the status pill. Picked from the existing AppTheme
  /// palette to keep the badge consistent with sync-status pills elsewhere.
  Color get pillColor {
    switch (this) {
      case TxState.idle:
        return AppTheme.gold;
      case TxState.signingPending:
        return AppTheme.warning;
      case TxState.txPending:
        return AppTheme.info;
      case TxState.confirming:
        return AppTheme.warning;
      case TxState.confirmed:
        return AppTheme.success;
      case TxState.failed:
        return AppTheme.error;
    }
  }

  IconData get icon {
    switch (this) {
      case TxState.idle:
        return Icons.shopping_cart_outlined;
      case TxState.signingPending:
        return Icons.draw_outlined;
      case TxState.txPending:
        return Icons.send_outlined;
      case TxState.confirming:
        return Icons.hourglass_top_outlined;
      case TxState.confirmed:
        return Icons.check_circle_outline;
      case TxState.failed:
        return Icons.error_outline;
    }
  }
}
