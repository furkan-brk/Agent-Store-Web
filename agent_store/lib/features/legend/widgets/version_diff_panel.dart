// lib/features/legend/widgets/version_diff_panel.dart
//
// v3.11.3 — T7 — Side-by-side workflow version diff overlay.
//
// Compares two LegendWorkflowVersion snapshots (left = older "from" version,
// right = newer "to" version) and renders node-level diffs:
//   - Added (only in `to`)        → success border
//   - Removed (only in `from`)    → primary (crimson) border + strikethrough
//   - Modified (different content)→ gold border + field-level diff text
//   - Unchanged                   → muted border, no badge
//
// Pure presentational widget: parent passes already-fetched version JSON.
// Reusable as a modal body or full-screen overlay.

import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../models/workflow_models.dart';

enum _NodeDiffStatus { added, removed, modified, unchanged }

class _NodeDiffEntry {
  final String id;
  final WorkflowNode? from;
  final WorkflowNode? to;
  final _NodeDiffStatus status;
  final List<String> changedFields;

  const _NodeDiffEntry({
    required this.id,
    required this.from,
    required this.to,
    required this.status,
    this.changedFields = const [],
  });
}

class VersionDiffPanel extends StatelessWidget {
  /// JSON payload from `GET /workflows/:id/versions/:v` for the FROM version.
  /// Expected shape: `{ "id":..., "version":..., "name":..., "fields_json":"..." }`
  /// where `fields_json` decodes to `{ nodes: [...], edges: [...] }`.
  final Map<String, dynamic> fromVersion;

  /// JSON payload for the TO version.
  final Map<String, dynamic> toVersion;

  /// Called when the user dismisses the overlay (close button or backdrop tap).
  final VoidCallback onClose;

  const VersionDiffPanel({
    super.key,
    required this.fromVersion,
    required this.toVersion,
    required this.onClose,
  });

  /// Decodes a version row's `fields_json` (or `nodes_json`) string into a node list.
  /// Tolerates the field being either a JSON string or a parsed map.
  static List<WorkflowNode> _decodeNodes(Map<String, dynamic> version) {
    dynamic blob = version['fields_json'] ?? version['nodes_json'] ?? version['nodes'];
    if (blob is String && blob.isNotEmpty) {
      try {
        blob = jsonDecode(blob);
      } catch (_) {
        return const [];
      }
    }
    if (blob is Map<String, dynamic>) {
      final list = blob['nodes'];
      if (list is List) {
        return list
            .whereType<Map<String, dynamic>>()
            .map(WorkflowNode.fromJson)
            .toList();
      }
    }
    if (blob is List) {
      return blob
          .whereType<Map<String, dynamic>>()
          .map(WorkflowNode.fromJson)
          .toList();
    }
    return const [];
  }

  static List<_NodeDiffEntry> _diffNodes(
    List<WorkflowNode> from,
    List<WorkflowNode> to,
  ) {
    final fromMap = {for (final n in from) n.id: n};
    final toMap = {for (final n in to) n.id: n};
    final allIds = <String>{...fromMap.keys, ...toMap.keys};
    // Stable order: by from-version first, then new ids appended.
    final ordered = <String>[
      ...from.map((n) => n.id),
      ...to.map((n) => n.id).where((id) => !fromMap.containsKey(id)),
    ];
    final seen = <String>{};
    final entries = <_NodeDiffEntry>[];
    for (final id in ordered) {
      if (!seen.add(id) || !allIds.contains(id)) continue;
      final f = fromMap[id];
      final t = toMap[id];
      if (f == null && t != null) {
        entries.add(_NodeDiffEntry(id: id, from: null, to: t, status: _NodeDiffStatus.added));
      } else if (f != null && t == null) {
        entries.add(_NodeDiffEntry(id: id, from: f, to: null, status: _NodeDiffStatus.removed));
      } else if (f != null && t != null) {
        final changed = _changedFields(f, t);
        entries.add(_NodeDiffEntry(
          id: id,
          from: f,
          to: t,
          status: changed.isEmpty ? _NodeDiffStatus.unchanged : _NodeDiffStatus.modified,
          changedFields: changed,
        ));
      }
    }
    return entries;
  }

  static List<String> _changedFields(WorkflowNode a, WorkflowNode b) {
    final changes = <String>[];
    if (a.label != b.label) changes.add("label: '${a.label}' → '${b.label}'");
    if (a.type != b.type) changes.add('type: ${a.type.name} → ${b.type.name}');
    if (a.refId != b.refId) changes.add('ref: ${a.refId ?? "—"} → ${b.refId ?? "—"}');
    if ((a.x - b.x).abs() > 0.5 || (a.y - b.y).abs() > 0.5) {
      changes.add('pos: (${a.x.toStringAsFixed(0)}, ${a.y.toStringAsFixed(0)}) '
          '→ (${b.x.toStringAsFixed(0)}, ${b.y.toStringAsFixed(0)})');
    }
    final aMeta = jsonEncode(a.metadata ?? const {});
    final bMeta = jsonEncode(b.metadata ?? const {});
    if (aMeta != bMeta) changes.add('metadata changed');
    return changes;
  }

  @override
  Widget build(BuildContext context) {
    final fromNodes = _decodeNodes(fromVersion);
    final toNodes = _decodeNodes(toVersion);
    final entries = _diffNodes(fromNodes, toNodes);

    final addedCount = entries.where((e) => e.status == _NodeDiffStatus.added).length;
    final removedCount = entries.where((e) => e.status == _NodeDiffStatus.removed).length;
    final modifiedCount = entries.where((e) => e.status == _NodeDiffStatus.modified).length;

    return Material(
      color: Colors.black.withValues(alpha: 0.55),
      child: GestureDetector(
        onTap: onClose,
        behavior: HitTestBehavior.opaque,
        child: Center(
          child: GestureDetector(
            onTap: () {}, // swallow taps inside the panel
            child: Container(
              constraints: const BoxConstraints(maxWidth: 1100, maxHeight: 720),
              margin: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.border),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildHeader(addedCount, removedCount, modifiedCount),
                  const Divider(height: 1, color: AppTheme.border),
                  Flexible(
                    child: entries.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(48),
                            child: Text(
                              'No nodes in either version.',
                              style: TextStyle(
                                color: AppTheme.textM.withValues(alpha: 0.9),
                              ),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: entries.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (_, i) => _DiffRow(entry: entries[i]),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(int added, int removed, int modified) {
    final fromLabel =
        'v${fromVersion['version'] ?? "?"} ${fromVersion['name'] != null ? "· ${fromVersion['name']}" : ""}';
    final toLabel =
        'v${toVersion['version'] ?? "?"} ${toVersion['name'] != null ? "· ${toVersion['name']}" : ""}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
      child: Row(
        children: [
          const Icon(Icons.compare_arrows_rounded, color: AppTheme.gold, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Compare workflow versions',
                  style: TextStyle(
                    color: AppTheme.textH,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$fromLabel  →  $toLabel',
                  style: const TextStyle(color: AppTheme.textM, fontSize: 12),
                ),
              ],
            ),
          ),
          if (added > 0)
            _SummaryChip(label: '+$added added', color: AppTheme.success),
          if (removed > 0) ...[
            const SizedBox(width: 6),
            _SummaryChip(label: '−$removed removed', color: AppTheme.primary),
          ],
          if (modified > 0) ...[
            const SizedBox(width: 6),
            _SummaryChip(label: '~$modified changed', color: AppTheme.gold),
          ],
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.close_rounded, color: AppTheme.textM, size: 20),
            onPressed: onClose,
            tooltip: 'Close',
          ),
        ],
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final Color color;
  const _SummaryChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _DiffRow extends StatelessWidget {
  final _NodeDiffEntry entry;
  const _DiffRow({required this.entry});

  Color get _statusColor {
    switch (entry.status) {
      case _NodeDiffStatus.added:    return AppTheme.success;
      case _NodeDiffStatus.removed:  return AppTheme.primary;
      case _NodeDiffStatus.modified: return AppTheme.gold;
      case _NodeDiffStatus.unchanged: return AppTheme.border;
    }
  }

  String get _statusBadge {
    switch (entry.status) {
      case _NodeDiffStatus.added:    return 'ADDED';
      case _NodeDiffStatus.removed:  return 'REMOVED';
      case _NodeDiffStatus.modified: return 'MODIFIED';
      case _NodeDiffStatus.unchanged: return 'UNCHANGED';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _statusColor.withValues(alpha: 0.55), width: 1.4),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _SummaryChip(label: _statusBadge, color: _statusColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    entry.id,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppTheme.textM.withValues(alpha: 0.9),
                      fontSize: 11,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _NodeFacet(
                    title: 'From',
                    node: entry.from,
                    strikethrough: entry.status == _NodeDiffStatus.removed,
                  ),
                ),
                const SizedBox(width: 12),
                const Icon(Icons.arrow_forward_rounded,
                    color: AppTheme.textM, size: 16),
                const SizedBox(width: 12),
                Expanded(
                  child: _NodeFacet(
                    title: 'To',
                    node: entry.to,
                    strikethrough: false,
                  ),
                ),
              ],
            ),
            if (entry.changedFields.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.bg.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppTheme.gold.withValues(alpha: 0.25)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: entry.changedFields
                      .map((c) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Text(
                              c,
                              style: const TextStyle(
                                color: AppTheme.textB,
                                fontSize: 11.5,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ))
                      .toList(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _NodeFacet extends StatelessWidget {
  final String title;
  final WorkflowNode? node;
  final bool strikethrough;

  const _NodeFacet({
    required this.title,
    required this.node,
    required this.strikethrough,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.bg.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              color: AppTheme.textM,
              fontSize: 9,
              letterSpacing: 1.4,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          if (node == null)
            const Text(
              '— absent —',
              style: TextStyle(color: AppTheme.textM, fontSize: 12),
            )
          else ...[
            Text(
              node!.label.isEmpty ? '(no label)' : node!.label,
              style: TextStyle(
                color: AppTheme.textH,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                decoration: strikethrough ? TextDecoration.lineThrough : null,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              '${node!.type.name}  ·  (${node!.x.toStringAsFixed(0)}, ${node!.y.toStringAsFixed(0)})',
              style: const TextStyle(color: AppTheme.textM, fontSize: 11),
            ),
            if (node!.refId != null && node!.refId!.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                'ref: ${node!.refId}',
                style: const TextStyle(
                  color: AppTheme.textM,
                  fontSize: 10.5,
                  fontFamily: 'monospace',
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ],
      ),
    );
  }
}
