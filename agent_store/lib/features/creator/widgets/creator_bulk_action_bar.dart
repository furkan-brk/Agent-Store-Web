// v3.11.4: Bulk action bar for the Creator Dashboard.
//
// Pragmatic split — instead of weaving checkboxes throughout the existing
// 1400-LOC _CreatorAgentTable, this widget surfaces a "Bulk regenerate"
// entry point that opens a multi-select chooser and a cost-preview confirm
// dialog. Same end-user capability, much smaller footprint.
//
// Cost model (matches backend bulkActionCost): regenerate_image = 3 credits
// per agent. Total = ids.length × 3.

import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../shared/models/agent_model.dart';
import '../../../shared/services/api_service.dart';
import '../../../shared/widgets/confirm_dialog.dart';

const int kBulkRegenerateCostPerAgent = 3;

class CreatorBulkActionBar extends StatelessWidget {
  /// Owned agents to choose from in the multi-select.
  final List<AgentModel> agents;

  /// Buyer's current credit balance — used to gate the cost-preview dialog.
  final int userCredits;

  /// Called after a successful bulk action so the caller can refresh data.
  final VoidCallback? onAfterAction;

  /// Test seam: optional override for the bulk POST so widget tests don't
  /// hit ApiService.instance.
  final Future<bool> Function(List<int> ids)? bulkActionOverride;

  const CreatorBulkActionBar({
    super.key,
    required this.agents,
    required this.userCredits,
    this.onAfterAction,
    this.bulkActionOverride,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.card.withValues(alpha: 0.7),
        border: Border.all(color: AppTheme.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.checklist_rtl, size: 18, color: AppTheme.gold),
          const SizedBox(width: 10),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Bulk actions',
                  style: TextStyle(
                    color: AppTheme.textH,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${agents.length} owned · regenerate at $kBulkRegenerateCostPerAgent credits each',
                  style: const TextStyle(color: AppTheme.textM, fontSize: 11),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton.icon(
            icon: const Icon(Icons.image_outlined, size: 16),
            label: const Text('Regenerate images…'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.gold,
              side: const BorderSide(color: AppTheme.gold),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            ),
            onPressed: agents.isEmpty
                ? null
                : () => _openSelector(context),
          ),
        ],
      ),
    );
  }

  Future<void> _openSelector(BuildContext context) async {
    final picked = await showDialog<Set<int>>(
      context: context,
      builder: (_) => _BulkSelectorDialog(agents: agents),
    );
    if (picked == null || picked.isEmpty) return;
    if (!context.mounted) return;
    await _confirmAndRun(context, picked.toList());
  }

  Future<void> _confirmAndRun(BuildContext context, List<int> ids) async {
    final cost = ids.length * kBulkRegenerateCostPerAgent;
    final affordable = userCredits >= cost;
    final ok = await ConfirmDialog.show(
      context,
      title: 'Regenerate ${ids.length} agent images?',
      message: affordable
          ? '${ids.length} agents × $kBulkRegenerateCostPerAgent = $cost credits required. You have $userCredits.'
          : '${ids.length} agents × $kBulkRegenerateCostPerAgent = $cost credits required. You have only $userCredits — top up first.',
      confirmLabel: affordable ? 'Regenerate' : 'OK',
      isDestructive: !affordable,
      icon: Icons.image_outlined,
    );
    if (!ok || !affordable || !context.mounted) return;

    final fn = bulkActionOverride ??
        (List<int> picked) async {
          final res = await ApiService.instance
              .bulkAgentAction('regenerate_image', picked);
          // Empty map = transport failure; non-empty = backend ack.
          return res.isNotEmpty;
        };
    final success = await fn(ids);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(success
          ? 'Regenerate started for ${ids.length} agents'
          : 'Bulk regenerate failed — try again'),
    ));
    if (success) onAfterAction?.call();
  }
}

class _BulkSelectorDialog extends StatefulWidget {
  final List<AgentModel> agents;
  const _BulkSelectorDialog({required this.agents});

  @override
  State<_BulkSelectorDialog> createState() => _BulkSelectorDialogState();
}

class _BulkSelectorDialogState extends State<_BulkSelectorDialog> {
  final Set<int> _selected = {};

  void _toggle(int id) {
    setState(() {
      if (_selected.contains(id)) {
        _selected.remove(id);
      } else {
        _selected.add(id);
      }
    });
  }

  void _selectAll() {
    setState(() {
      _selected
        ..clear()
        ..addAll(widget.agents.map((a) => a.id));
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Text('Select agents'),
          const Spacer(),
          TextButton(
            onPressed: _selected.length == widget.agents.length ? null : _selectAll,
            child: const Text('Select all'),
          ),
        ],
      ),
      content: SizedBox(
        width: 420,
        height: 360,
        child: ListView.builder(
          itemCount: widget.agents.length,
          itemBuilder: (_, i) {
            final a = widget.agents[i];
            final checked = _selected.contains(a.id);
            return CheckboxListTile(
              dense: true,
              controlAffinity: ListTileControlAffinity.leading,
              value: checked,
              onChanged: (_) => _toggle(a.id),
              title: Text(a.title, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(
                '${a.category} · ${a.saveCount} saves',
                style: const TextStyle(fontSize: 11),
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(<int>{}),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _selected.isEmpty
              ? null
              : () => Navigator.of(context).pop(_selected),
          child: Text('Pick ${_selected.length}'),
        ),
      ],
    );
  }
}
