// lib/features/agent_detail/widgets/tx_timeline.dart
//
// Visual 4-step stepper that mirrors the v3.7 [TxState] machine. The
// existing PurchaseStatusButton inlines the state name + a single
// pending spinner, which is fine for a button but loses the per-leg
// granularity for users on slow Monad RPC. This timeline is meant for
// a bottom-sheet companion that the AgentDetail screen can pop while
// the purchase is in flight.
//
// Pure widget code — accepts a TxState + optional txHash + optional
// failure reason and paints the Signed → Broadcast → Mined → Confirmed
// rail. Keeping it stateless lets the caller drive it from any Rx
// source (controller observable, manual setState, animated stub).

import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import 'tx_state.dart';

// Re-export so consumers can resolve TxState from this file alone — keeps
// imports tidy at the call site (one import for "the timeline + its enum").
export 'tx_state.dart' show TxState, TxStateX;

/// Discrete step indices for the timeline. Stable across releases —
/// adding a new step means adding a new constant and updating
/// `_stepLabels` / `_stepIcons` together.
enum TxTimelineStep {
  signed,
  broadcast,
  mined,
  confirmed,
}

/// Computed visual state for one rail step.
enum _StepStatus { upcoming, active, complete, failed }

class TxTimeline extends StatelessWidget {
  final TxState state;
  final String? txHash;
  final String? failureReason;

  const TxTimeline({
    super.key,
    required this.state,
    this.txHash,
    this.failureReason,
  });

  /// Maps a [TxState] to the index of the step that's currently
  /// "active" — earlier steps are complete, later steps are upcoming.
  /// `failed` keeps the last attempted step active so the X marker
  /// lands on the right column.
  int get _activeStep {
    switch (state) {
      case TxState.idle:
        return -1;
      case TxState.signingPending:
        return TxTimelineStep.signed.index;
      case TxState.txPending:
        return TxTimelineStep.broadcast.index;
      case TxState.confirming:
        return TxTimelineStep.mined.index;
      case TxState.confirmed:
        return TxTimelineStep.confirmed.index;
      case TxState.failed:
        // We don't know which leg failed — anchor on broadcast as the
        // most likely (signing fails before a hash exists; reconcile
        // failures arrive after a hash). Caller can override with a
        // free-form failureReason.
        return TxTimelineStep.broadcast.index;
    }
  }

  _StepStatus _statusFor(int index) {
    if (state == TxState.failed) {
      return index <= _activeStep ? _StepStatus.failed : _StepStatus.upcoming;
    }
    if (state == TxState.confirmed) return _StepStatus.complete;
    if (index < _activeStep) return _StepStatus.complete;
    if (index == _activeStep) return _StepStatus.active;
    return _StepStatus.upcoming;
  }

  static const _stepLabels = <String>[
    'Signed',
    'Broadcast',
    'Mined',
    'Confirmed',
  ];

  static const _stepIcons = <IconData>[
    Icons.draw_outlined,
    Icons.send_outlined,
    Icons.developer_board,
    Icons.check_circle_outline,
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(state.icon, color: state.pillColor, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                state.label,
                style: const TextStyle(
                  color: AppTheme.textH,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ]),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List.generate(_stepLabels.length, (i) {
              final status = _statusFor(i);
              final isLast = i == _stepLabels.length - 1;
              return Expanded(
                child: _TimelineCell(
                  label: _stepLabels[i],
                  icon: _stepIcons[i],
                  status: status,
                  showConnector: !isLast,
                  // Connector colour follows the *next* leg; a bridge
                  // between two complete steps reads "complete", a
                  // bridge into the active step reads "active".
                  nextStatus: !isLast ? _statusFor(i + 1) : null,
                ),
              );
            }),
          ),
          if (txHash != null && txHash!.isNotEmpty) ...[
            const SizedBox(height: 16),
            _TxHashRow(txHash: txHash!),
          ],
          if (state == TxState.failed && failureReason != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.error.withValues(alpha: 0.3)),
              ),
              child: Row(children: [
                const Icon(Icons.error_outline, color: AppTheme.error, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    failureReason!,
                    style: const TextStyle(
                      color: AppTheme.textH,
                      fontSize: 12,
                    ),
                  ),
                ),
              ]),
            ),
          ],
        ],
      ),
    );
  }
}

class _TimelineCell extends StatelessWidget {
  final String label;
  final IconData icon;
  final _StepStatus status;
  final bool showConnector;
  final _StepStatus? nextStatus;

  const _TimelineCell({
    required this.label,
    required this.icon,
    required this.status,
    required this.showConnector,
    this.nextStatus,
  });

  Color get _color {
    switch (status) {
      case _StepStatus.upcoming:
        return AppTheme.textM;
      case _StepStatus.active:
        return AppTheme.warning;
      case _StepStatus.complete:
        return AppTheme.success;
      case _StepStatus.failed:
        return AppTheme.error;
    }
  }

  Widget _marker() {
    final color = _color;
    if (status == _StepStatus.failed) {
      return Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          shape: BoxShape.circle,
          border: Border.all(color: color, width: 1.5),
        ),
        child: const Icon(Icons.close_rounded, color: AppTheme.error, size: 16),
      );
    }
    if (status == _StepStatus.complete) {
      return Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.18),
          shape: BoxShape.circle,
          border: Border.all(color: color, width: 1.5),
        ),
        child: Icon(Icons.check_rounded, color: color, size: 16),
      );
    }
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 1.5),
      ),
      child: Icon(icon, color: color, size: 14),
    );
  }

  @override
  Widget build(BuildContext context) {
    final connectorColor =
        (nextStatus == _StepStatus.complete || nextStatus == _StepStatus.active)
            ? _color
            : AppTheme.border;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(children: [
          _marker(),
          if (showConnector)
            Expanded(
              child: Container(
                height: 2,
                color: connectorColor,
              ),
            ),
        ]),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: Text(
            label,
            style: TextStyle(
              color: status == _StepStatus.upcoming
                  ? AppTheme.textM
                  : AppTheme.textH,
              fontSize: 11,
              fontWeight: status == _StepStatus.active ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

class _TxHashRow extends StatelessWidget {
  final String txHash;
  const _TxHashRow({required this.txHash});

  @override
  Widget build(BuildContext context) {
    final shortHash = txHash.length > 14
        ? '${txHash.substring(0, 8)}…${txHash.substring(txHash.length - 4)}'
        : txHash;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(children: [
        const Icon(Icons.link_rounded, size: 14, color: AppTheme.info),
        const SizedBox(width: 8),
        const Text('Tx', style: TextStyle(color: AppTheme.textM, fontSize: 11)),
        const SizedBox(width: 6),
        Expanded(
          child: SelectableText(
            shortHash,
            style: const TextStyle(
              color: AppTheme.textB,
              fontSize: 12,
              fontFamily: 'monospace',
            ),
          ),
        ),
      ]),
    );
  }
}
