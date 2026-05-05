// lib/features/legend/widgets/legend_text_input_dialog.dart
//
// v3.12 (PR 2 / FIX 3) — Stateful single-line text-input dialog and a
// stateful execute-input dialog used by LegendScreen.
//
// Pre-fix, four sites in legend_screen.dart instantiated TextEditingControllers
// inline (label-edge, new-workflow, rename, execute) and never disposed them.
// We initially tried the `showDialog().whenComplete(ctrl.dispose)` pattern,
// but that disposes the controller as soon as Navigator.pop fires — while
// the dialog's exit transition is still rebuilding the TextField subtree
// against the (now-dead) controller, throwing
// "TextEditingController was used after being disposed".
//
// The robust fix is to make the dialog itself own its controller via a
// StatefulWidget — dispose then runs *after* the route's State is unmounted,
// which only happens after the exit animation completes.
//
// We expose two reusable widgets here:
//
// - `LegendTextInputDialog` — single-line input (label-edge, new-workflow,
//   rename). Receives an `onConfirm(String value)` callback.
// - `LegendExecuteInputDialog` — multi-line execute input with a credit
//   notice header. Receives an `onConfirm(String message)` callback.

import 'package:flutter/material.dart';

import '../../../app/theme.dart';

// ── Single-line text input ──────────────────────────────────────────────────

class LegendTextInputDialog extends StatefulWidget {
  final String title;
  final String? hint;
  final String confirmLabel;
  final String initialValue;

  /// Whether to trim the input before invoking onConfirm. The label-edge
  /// dialog wants the trimmed value (and substitutes null when empty);
  /// new-workflow/rename pass the raw value (the host trims itself).
  final bool trim;

  /// Whether an empty (post-trim) value is allowed to invoke onConfirm.
  /// rename rejects empties silently; new-workflow/label-edge accept them.
  final bool allowEmpty;

  /// Invoked when the user taps the confirm action. The widget pops the
  /// dialog *before* invoking the callback so the host's awaiting code
  /// doesn't see a still-mounted dialog.
  final void Function(String value) onConfirm;

  const LegendTextInputDialog({
    super.key,
    required this.title,
    required this.confirmLabel,
    required this.onConfirm,
    this.hint,
    this.initialValue = '',
    this.trim = true,
    this.allowEmpty = true,
  });

  @override
  State<LegendTextInputDialog> createState() => _LegendTextInputDialogState();
}

class _LegendTextInputDialogState extends State<LegendTextInputDialog> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _handleConfirm() {
    final raw = _ctrl.text;
    final value = widget.trim ? raw.trim() : raw;
    if (!widget.allowEmpty && value.isEmpty) {
      // Silently no-op — caller's contract for the rename flow.
      Navigator.pop(context);
      return;
    }
    Navigator.pop(context);
    widget.onConfirm(value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.card,
      title: Text(widget.title,
          style: const TextStyle(color: AppTheme.textH)),
      content: TextField(
        controller: _ctrl,
        autofocus: true,
        style: const TextStyle(color: AppTheme.textH),
        decoration: InputDecoration(
          hintText: widget.hint,
          hintStyle: widget.hint == null
              ? null
              : const TextStyle(color: AppTheme.textM),
        ),
        onSubmitted: (_) => _handleConfirm(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel',
              style: TextStyle(color: AppTheme.textM)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
          onPressed: _handleConfirm,
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}

// ── Execute Workflow input ──────────────────────────────────────────────────

class LegendExecuteInputDialog extends StatefulWidget {
  final int agentCount;
  final void Function(String message) onConfirm;

  const LegendExecuteInputDialog({
    super.key,
    required this.agentCount,
    required this.onConfirm,
  });

  @override
  State<LegendExecuteInputDialog> createState() =>
      _LegendExecuteInputDialogState();
}

class _LegendExecuteInputDialogState extends State<LegendExecuteInputDialog> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _handleExecute() {
    final msg = _ctrl.text.trim();
    if (msg.isEmpty) return;
    Navigator.pop(context);
    widget.onConfirm(msg);
  }

  @override
  Widget build(BuildContext context) {
    final agentCount = widget.agentCount;
    return AlertDialog(
      backgroundColor: AppTheme.card,
      title: const Row(
        children: [
          Icon(Icons.rocket_launch_outlined, color: AppTheme.gold, size: 20),
          SizedBox(width: 8),
          Text('Execute Workflow',
              style: TextStyle(color: AppTheme.textH, fontSize: 16)),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.bg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.border),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline,
                      size: 14, color: AppTheme.gold),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This workflow has $agentCount agent node${agentCount != 1 ? 's' : ''} and will cost $agentCount credit${agentCount != 1 ? 's' : ''}.',
                      style: const TextStyle(
                          color: AppTheme.textM, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text('Input Message',
                style: TextStyle(
                    color: AppTheme.textH,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextField(
              controller: _ctrl,
              autofocus: true,
              maxLines: 4,
              style: const TextStyle(color: AppTheme.textH, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Enter the input message for your workflow...',
                hintStyle:
                    TextStyle(color: AppTheme.textM.withValues(alpha: 0.6)),
                filled: true,
                fillColor: AppTheme.bg,
                contentPadding: const EdgeInsets.all(12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppTheme.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppTheme.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide:
                      const BorderSide(color: AppTheme.gold, width: 2),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel',
              style: TextStyle(color: AppTheme.textM)),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.gold,
            foregroundColor: AppTheme.bg,
          ),
          icon: const Icon(Icons.rocket_launch, size: 16),
          label: const Text('Execute'),
          onPressed: _handleExecute,
        ),
      ],
    );
  }
}
