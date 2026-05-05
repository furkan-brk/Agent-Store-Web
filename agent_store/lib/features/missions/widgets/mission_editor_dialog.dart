// lib/features/missions/widgets/mission_editor_dialog.dart
//
// v3.12 (PR 2 / FIX 1) — Stateful Mission editor dialog.
//
// Originally lived as a private `_CreateMissionDialog` StatelessWidget inside
// `missions_screen.dart`. The host functions instantiated 2 TextEditingControllers
// per open and never called `.dispose()`, leaking on every Create/Edit cycle.
//
// This widget now owns and disposes its own controllers. Hosts pass an
// `onSave(title, prompt)` callback and (optionally) initial values.
//
// Kept as a public widget (no leading underscore) so dispose semantics can be
// regression-tested without exporting private symbols.

import 'package:flutter/material.dart';

import '../../../app/theme.dart';

/// Stateful dialog used for both Create and Edit Mission flows.
///
/// Owns its TextEditingControllers and disposes them when the dialog is torn
/// down — preventing the v3.11.x leak where the host function leaked 2
/// controllers per dialog open/close.
class MissionEditorDialog extends StatefulWidget {
  /// Receives the trimmed (title, prompt) tuple when the user taps Save.
  final void Function(String title, String prompt) onSave;
  final bool isEdit;
  final String initialTitle;
  final String initialPrompt;

  const MissionEditorDialog({
    super.key,
    required this.onSave,
    this.isEdit = false,
    this.initialTitle = '',
    this.initialPrompt = '',
  });

  @override
  State<MissionEditorDialog> createState() => _MissionEditorDialogState();
}

class _MissionEditorDialogState extends State<MissionEditorDialog> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _promptCtrl;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.initialTitle);
    _promptCtrl = TextEditingController(text: widget.initialPrompt);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _promptCtrl.dispose();
    super.dispose();
  }

  void _handleSave() {
    widget.onSave(_titleCtrl.text.trim(), _promptCtrl.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppTheme.border),
      ),
      title: Text(
        widget.isEdit ? 'Edit Mission' : 'Create Mission',
        style: const TextStyle(
            color: AppTheme.textH, fontSize: 18, fontWeight: FontWeight.bold),
      ),
      content: SizedBox(
        width: 440,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: _titleCtrl,
            style: const TextStyle(color: AppTheme.textH, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Mission title (e.g. Secure API audit)',
              hintStyle: const TextStyle(color: AppTheme.textM, fontSize: 13),
              filled: true,
              fillColor: AppTheme.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppTheme.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppTheme.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _promptCtrl,
            style: const TextStyle(color: AppTheme.textH, fontSize: 14),
            minLines: 3,
            maxLines: 8,
            decoration: InputDecoration(
              hintText: 'Mission prompt content...',
              hintStyle: const TextStyle(color: AppTheme.textM, fontSize: 13),
              filled: true,
              fillColor: AppTheme.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppTheme.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppTheme.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
              ),
            ),
          ),
        ]),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel', style: TextStyle(color: AppTheme.textM)),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AppTheme.primary,
            foregroundColor: AppTheme.textH,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: _handleSave,
          child: Text(widget.isEdit ? 'Save' : 'Create'),
        ),
      ],
    );
  }
}
