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

/// Bulk action kind. v3.11.5 expanded the bar from regenerate-only to
/// include free tag add / tag remove (covers könçürleme.md 3.2.4 #5
/// "Creator dashboard toplu aksiyon").
enum BulkActionKind { regenerate, tagAdd, tagRemove }

class CreatorBulkActionBar extends StatelessWidget {
  /// Owned agents to choose from in the multi-select.
  final List<AgentModel> agents;

  /// Buyer's current credit balance — used to gate the cost-preview dialog.
  final int userCredits;

  /// Called after a successful bulk action so the caller can refresh data.
  final VoidCallback? onAfterAction;

  /// Test seam: optional override for the bulk POST so widget tests don't
  /// hit ApiService.instance. The signature mirrors [BulkActionKind] so
  /// tag-add/remove tests can return synthetic results.
  final Future<bool> Function(List<int> ids, BulkActionKind kind, {List<String>? tags})? bulkActionOverride;

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
          // v3.11.5: split into a popup so tag actions are reachable.
          PopupMenuButton<BulkActionKind>(
            tooltip: 'Bulk actions',
            enabled: agents.isNotEmpty,
            onSelected: (kind) => _openSelector(context, kind),
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: BulkActionKind.regenerate,
                child: Row(children: [
                  Icon(Icons.image_outlined, size: 16, color: AppTheme.gold),
                  SizedBox(width: 8),
                  Text('Regenerate images…'),
                ]),
              ),
              PopupMenuItem(
                value: BulkActionKind.tagAdd,
                child: Row(children: [
                  Icon(Icons.label_outline, size: 16, color: AppTheme.gold),
                  SizedBox(width: 8),
                  Text('Add tag…'),
                ]),
              ),
              PopupMenuItem(
                value: BulkActionKind.tagRemove,
                child: Row(children: [
                  Icon(Icons.label_off_outlined, size: 16, color: AppTheme.gold),
                  SizedBox(width: 8),
                  Text('Remove tag…'),
                ]),
              ),
            ],
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                border: Border.all(color: agents.isEmpty
                    ? AppTheme.border
                    : AppTheme.gold),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.checklist, size: 16,
                      color: agents.isEmpty ? AppTheme.textM : AppTheme.gold),
                  const SizedBox(width: 6),
                  Text(
                    'Bulk action…',
                    style: TextStyle(
                      color: agents.isEmpty ? AppTheme.textM : AppTheme.gold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.arrow_drop_down, size: 16,
                      color: agents.isEmpty ? AppTheme.textM : AppTheme.gold),
                ],
              ),
            ),
          ),
          // Legacy path: keep the standalone "Regenerate images…" button as a
          // discoverable entry point for the most common action. Tests still
          // find it by label text.
          const SizedBox(width: 8),
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
                : () => _openSelector(context, BulkActionKind.regenerate),
          ),
        ],
      ),
    );
  }

  Future<void> _openSelector(BuildContext context, BulkActionKind kind) async {
    final picked = await showDialog<Set<int>>(
      context: context,
      builder: (_) => _BulkSelectorDialog(agents: agents),
    );
    if (picked == null || picked.isEmpty) return;
    if (!context.mounted) return;
    if (kind == BulkActionKind.regenerate) {
      await _confirmAndRun(context, picked.toList());
    } else {
      await _runTagAction(context, picked.toList(), kind);
    }
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
        (List<int> picked, BulkActionKind kind, {List<String>? tags}) async {
          final res = await ApiService.instance
              .bulkAgentAction('regenerate_image', picked);
          return res.isNotEmpty;
        };
    final success = await fn(ids, BulkActionKind.regenerate);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(success
          ? 'Regenerate started for ${ids.length} agents'
          : 'Bulk regenerate failed — try again'),
    ));
    if (success) onAfterAction?.call();
  }

  /// v3.11.5: tag add / remove. Free of charge — no credit gate.
  Future<void> _runTagAction(BuildContext context, List<int> ids, BulkActionKind kind) async {
    final tag = await _promptForTag(context, kind);
    if (tag == null || tag.isEmpty || !context.mounted) return;

    final fn = bulkActionOverride ??
        (List<int> picked, BulkActionKind k, {List<String>? tags}) async {
          final action = k == BulkActionKind.tagAdd ? 'tag_add' : 'tag_remove';
          final res = await ApiService.instance.bulkAgentAction(
            action, picked,
            payload: {'tags': tags ?? const []},
          );
          return res.isNotEmpty;
        };
    final success = await fn(ids, kind, tags: [tag]);
    if (!context.mounted) return;
    final verb = kind == BulkActionKind.tagAdd ? 'added' : 'removed';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(success
          ? 'Tag "$tag" $verb on ${ids.length} agents'
          : 'Bulk tag $verb failed — try again'),
    ));
    if (success) onAfterAction?.call();
  }

  Future<String?> _promptForTag(BuildContext context, BulkActionKind kind) {
    final ctrl = TextEditingController();
    final isAdd = kind == BulkActionKind.tagAdd;
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isAdd ? 'Add tag to selected' : 'Remove tag from selected'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Tag',
            hintText: isAdd ? 'e.g. featured' : 'tag to remove',
            border: const OutlineInputBorder(),
          ),
          onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(ctrl.text.trim()),
            child: Text(isAdd ? 'Add' : 'Remove'),
          ),
        ],
      ),
    );
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
