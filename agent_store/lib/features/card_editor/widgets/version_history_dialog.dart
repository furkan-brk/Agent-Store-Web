// lib/features/card_editor/widgets/version_history_dialog.dart
//
// v3.11.3 — T10c — Lists snapshot versions of an agent and offers per-row
// "Restore" buttons. Restore goes through ConfirmDialog before invoking
// the rollback endpoint and reloading the card.

import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../shared/services/api_service.dart';
import '../../../shared/utils/app_snack_bar.dart';
import '../../../shared/widgets/confirm_dialog.dart';

/// Function shape that performs the actual API call. Lifted out for tests.
typedef VersionsFetcher = Future<List<Map<String, dynamic>>> Function(int agentId);
typedef RollbackInvoker = Future<Map<String, dynamic>?> Function(int agentId, int version);

class VersionHistoryDialog extends StatefulWidget {
  final int agentId;
  final VoidCallback onRollbackComplete;

  /// Test seam: the screen passes null in production and the API is hit
  /// directly. Tests inject a stub that returns canned JSON.
  final VersionsFetcher? fetchOverride;
  final RollbackInvoker? rollbackOverride;

  const VersionHistoryDialog({
    super.key,
    required this.agentId,
    required this.onRollbackComplete,
    this.fetchOverride,
    this.rollbackOverride,
  });

  static Future<void> show(
    BuildContext context, {
    required int agentId,
    required VoidCallback onRollbackComplete,
    VersionsFetcher? fetchOverride,
    RollbackInvoker? rollbackOverride,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => VersionHistoryDialog(
        agentId: agentId,
        onRollbackComplete: onRollbackComplete,
        fetchOverride: fetchOverride,
        rollbackOverride: rollbackOverride,
      ),
    );
  }

  @override
  State<VersionHistoryDialog> createState() => _VersionHistoryDialogState();
}

class _VersionHistoryDialogState extends State<VersionHistoryDialog> {
  bool _loading = true;
  List<Map<String, dynamic>> _versions = const [];
  int? _restoringVersion;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final fn = widget.fetchOverride ?? ApiService.instance.getAgentVersions;
    final list = await fn(widget.agentId);
    if (!mounted) return;
    setState(() {
      _versions = list;
      _loading = false;
    });
  }

  String _relative(String? iso) {
    if (iso == null || iso.isEmpty) return '—';
    final ts = DateTime.tryParse(iso);
    if (ts == null) return iso;
    final diff = DateTime.now().toUtc().difference(ts.toUtc());
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 30) return '${diff.inDays}d ago';
    return '${(diff.inDays / 30).floor()}mo ago';
  }

  Future<void> _restore(int version) async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Restore version $version?',
      message:
          'This snapshots the current state, then rolls back to version $version. You can roll forward again from history.',
      confirmLabel: 'Restore',
      icon: Icons.restore_rounded,
    );
    if (!confirmed || !mounted) return;
    setState(() => _restoringVersion = version);
    final fn = widget.rollbackOverride ?? ApiService.instance.rollbackAgentVersion;
    final result = await fn(widget.agentId, version);
    if (!mounted) return;
    setState(() => _restoringVersion = null);
    if (result == null) {
      AppSnackBar.error(context, 'Restore failed.');
      return;
    }
    AppSnackBar.success(context, 'Restored to version $version');
    Navigator.of(context).pop();
    widget.onRollbackComplete();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppTheme.border),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 12, 14),
              child: Row(children: [
                const Icon(Icons.history_rounded, color: AppTheme.gold, size: 20),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Version history',
                    style: TextStyle(
                      color: AppTheme.textH,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded,
                      color: AppTheme.textM, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ]),
            ),
            const Divider(height: 1, color: AppTheme.border),
            Flexible(
              child: _loading
                  ? const Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(
                        child: CircularProgressIndicator(color: AppTheme.gold),
                      ),
                    )
                  : _versions.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(36),
                          child: Center(
                            child: Text(
                              'No saved versions yet.',
                              style: TextStyle(color: AppTheme.textM),
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(14),
                          itemCount: _versions.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (_, i) {
                            final v = _versions[i];
                            final ver = (v['version'] as num?)?.toInt() ?? 0;
                            final created = v['created_at'] as String?;
                            final restoring = _restoringVersion == ver;
                            return Container(
                              padding:
                                  const EdgeInsets.fromLTRB(14, 12, 10, 12),
                              decoration: BoxDecoration(
                                color: AppTheme.card,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppTheme.border),
                              ),
                              child: Row(children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color:
                                        AppTheme.gold.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'v$ver',
                                    style: const TextStyle(
                                      color: AppTheme.gold,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'Version $ver',
                                        style: const TextStyle(
                                          color: AppTheme.textH,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _relative(created),
                                        style: const TextStyle(
                                          color: AppTheme.textM,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                TextButton.icon(
                                  onPressed: restoring ? null : () => _restore(ver),
                                  icon: restoring
                                      ? const SizedBox(
                                          width: 12,
                                          height: 12,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: AppTheme.gold),
                                        )
                                      : const Icon(Icons.restore_rounded,
                                          size: 14),
                                  label: const Text('Restore'),
                                  style: TextButton.styleFrom(
                                    foregroundColor: AppTheme.gold,
                                    textStyle: const TextStyle(fontSize: 12),
                                  ),
                                ),
                              ]),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
