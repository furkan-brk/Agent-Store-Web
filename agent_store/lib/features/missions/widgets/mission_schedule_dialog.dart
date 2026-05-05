// v3.11.4: Mission cron-schedule dialog.
//
// Renders 4 cron presets + a Custom field + an Enabled toggle. The dialog
// itself only owns input validation; the caller wires save/delete via the
// `onSave` and `onDelete` callbacks so we stay test-friendly without
// pulling in ApiService.

import 'package:flutter/material.dart';

import '../../../app/theme.dart';

class MissionSchedulePresets {
  static const List<({String label, String cron})> all = [
    (label: 'Hourly', cron: '0 * * * *'),
    (label: 'Daily 9am', cron: '0 9 * * *'),
    (label: 'Weekly Mon 9am', cron: '0 9 * * 1'),
    (label: 'Monthly 1st 9am', cron: '0 9 1 * *'),
  ];

  static const String customSentinel = '__custom__';
}

typedef MissionScheduleSaveCallback = Future<void> Function(String cron, bool enabled);
typedef MissionScheduleDeleteCallback = Future<void> Function();

class MissionScheduleDialog extends StatefulWidget {
  /// When non-null, dialog opens pre-filled with this cron + enabled state.
  /// (v3.11.5 may surface MissionModel.scheduleCron — for now caller passes
  /// nulls since the model doesn't carry the field.)
  final String? initialCron;
  final bool? initialEnabled;

  /// Called when the user taps Save. Caller does the API call + snackbar.
  final MissionScheduleSaveCallback onSave;

  /// Optional — when non-null a Delete button appears alongside Save.
  final MissionScheduleDeleteCallback? onDelete;

  const MissionScheduleDialog({
    super.key,
    required this.onSave,
    this.initialCron,
    this.initialEnabled,
    this.onDelete,
  });

  @override
  State<MissionScheduleDialog> createState() => _MissionScheduleDialogState();
}

class _MissionScheduleDialogState extends State<MissionScheduleDialog> {
  late String _selectedPreset; // cron value or customSentinel
  late TextEditingController _customCtrl;
  late bool _enabled;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _enabled = widget.initialEnabled ?? true;
    _customCtrl = TextEditingController(text: widget.initialCron ?? '');
    final initialCron = widget.initialCron;
    if (initialCron == null) {
      _selectedPreset = MissionSchedulePresets.all.first.cron;
    } else {
      // Snap to a preset when the cron exactly matches one; otherwise Custom.
      final match = MissionSchedulePresets.all
          .where((p) => p.cron == initialCron)
          .toList();
      _selectedPreset = match.isNotEmpty
          ? match.first.cron
          : MissionSchedulePresets.customSentinel;
    }
  }

  @override
  void dispose() {
    _customCtrl.dispose();
    super.dispose();
  }

  bool get _isCustom => _selectedPreset == MissionSchedulePresets.customSentinel;

  String get _resolvedCron =>
      _isCustom ? _customCtrl.text.trim() : _selectedPreset;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Schedule mission'),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Pick a cadence — the mission re-fires on a 60-second tick.',
              style: TextStyle(color: AppTheme.textM, fontSize: 12),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _selectedPreset,
              decoration: const InputDecoration(
                labelText: 'Cadence',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: [
                ...MissionSchedulePresets.all.map((p) => DropdownMenuItem(
                      value: p.cron,
                      child: Text(p.label),
                    )),
                const DropdownMenuItem(
                  value: MissionSchedulePresets.customSentinel,
                  child: Text('Custom (cron)'),
                ),
              ],
              onChanged: (v) => setState(() => _selectedPreset = v ?? _selectedPreset),
            ),
            if (_isCustom) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _customCtrl,
                decoration: const InputDecoration(
                  labelText: 'Cron expression',
                  helperText: '5 fields: minute hour day month weekday',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ],
            const SizedBox(height: 12),
            SwitchListTile.adaptive(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text('Enabled'),
              subtitle: const Text('Disable to keep the cron but pause firing'),
              value: _enabled,
              onChanged: (v) => setState(() => _enabled = v),
            ),
          ],
        ),
      ),
      actions: [
        if (widget.onDelete != null)
          TextButton(
            onPressed: _saving
                ? null
                : () async {
                    Navigator.of(context).pop();
                    await widget.onDelete!();
                  },
            child: const Text('Delete', style: TextStyle(color: AppTheme.primary)),
          ),
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _onSavePressed,
          child: _saving
              ? const SizedBox(
                  width: 14, height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }

  Future<void> _onSavePressed() async {
    final cron = _resolvedCron;
    if (cron.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cron expression cannot be empty')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.onSave(cron, _enabled);
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
