// lib/features/agent_detail/widgets/purchase_button.dart
//
// Tx state machine for the Agent Detail purchase flow (v3.7).
//
// The legacy flow used a single `isPurchaseLoading` bool, which collapsed three
// distinct waiting states (wallet popup, on-chain mempool, backend reconcile)
// into one opaque spinner. Users hit the buy button and stared at a spinner
// for 5–30s with no signal about *which* leg of the transaction they were on,
// and any failure looked the same. This widget surfaces the full state graph
// plus an explorer deep-link so the user can self-verify on-chain.

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

import '../../../app/theme.dart';
import 'tx_state.dart';

// Re-export so existing imports of `purchase_button.dart` (controllers,
// screens) keep resolving TxState/TxStateX without churn.
export 'tx_state.dart' show TxState, TxStateX;

/// Renders the purchase call-to-action driven by [TxState]. While in flight
/// the button is disabled and shows a spinner; on [TxState.txPending] /
/// [TxState.confirmed] a deep-link to the Monad testnet explorer is shown
/// next to the button so the user can independently verify the tx.
class PurchaseStatusButton extends StatelessWidget {
  final TxState state;
  final double priceMon;
  final String? txHash;
  final String? failureMessage;
  final VoidCallback onPressed;
  final bool fullWidth;

  const PurchaseStatusButton({
    super.key,
    required this.state,
    required this.priceMon,
    required this.onPressed,
    this.txHash,
    this.failureMessage,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = state.isInFlight || state == TxState.confirmed;
    final labelText = state == TxState.idle
        ? 'Purchase for ${priceMon.toStringAsFixed(2)} MON'
        : state.label;

    final button = ElevatedButton.icon(
      onPressed: disabled ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: state.pillColor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      icon: state.isInFlight
          ? const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
          : Icon(state.icon, size: 16),
      label: Text(labelText, style: const TextStyle(fontWeight: FontWeight.w600)),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: fullWidth ? double.infinity : null, child: button),
        if (txHash != null && txHash!.isNotEmpty) ...[
          const SizedBox(height: 6),
          _ExplorerLink(txHash: txHash!),
        ],
        if (state == TxState.failed && failureMessage != null) ...[
          const SizedBox(height: 6),
          Text(
            failureMessage!,
            style: const TextStyle(color: AppTheme.error, fontSize: 11),
          ),
        ],
      ],
    );
  }
}

/// Compact deep-link to the Monad testnet explorer. We never assume the user
/// can scroll their wallet history — the link is always one click away
/// regardless of which state the tx is in.
class _ExplorerLink extends StatelessWidget {
  final String txHash;
  const _ExplorerLink({required this.txHash});

  static const _explorerBase = 'https://testnet.monadexplorer.com/tx/';

  @override
  Widget build(BuildContext context) {
    final shortHash = txHash.length > 14
        ? '${txHash.substring(0, 8)}…${txHash.substring(txHash.length - 4)}'
        : txHash;
    return InkWell(
      onTap: () => web.window.open('$_explorerBase$txHash', '_blank'),
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.open_in_new, size: 11, color: AppTheme.info),
            const SizedBox(width: 4),
            Text(
              'View tx $shortHash',
              style: const TextStyle(
                color: AppTheme.info,
                fontSize: 11,
                fontFamily: 'monospace',
                decoration: TextDecoration.underline,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
