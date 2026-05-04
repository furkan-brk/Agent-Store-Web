// Three-action dialog for optimistic-concurrency conflicts. Visual style
// mirrors [ConfirmDialog] — same vintage dark palette, same rounded shape.

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../services/conflict_resolver.dart';

Future<ConflictResolution> showConflictDialog(
  BuildContext context, {
  required String resourceTypeLabel,
  String localLabel = 'Your draft',
  DateTime? serverUpdatedAt,
}) async {
  final result = await showDialog<ConflictResolution>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _ConflictDialog(
      resourceTypeLabel: resourceTypeLabel,
      localLabel: localLabel,
      serverUpdatedAt: serverUpdatedAt,
    ),
  );
  return result ?? ConflictResolution.cancel;
}

class _ConflictDialog extends StatelessWidget {
  final String resourceTypeLabel;
  final String localLabel;
  final DateTime? serverUpdatedAt;

  const _ConflictDialog({
    required this.resourceTypeLabel,
    required this.localLabel,
    this.serverUpdatedAt,
  });

  String _formatTime(DateTime t) {
    final now = DateTime.now();
    final diff = now.difference(t);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} h ago';
    return '${diff.inDays} d ago';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppTheme.border),
      ),
      icon: const Icon(Icons.merge_type, color: AppTheme.gold, size: 28),
      title: const Text(
        'Conflicting changes',
        style: TextStyle(color: AppTheme.textH, fontWeight: FontWeight.bold),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'This $resourceTypeLabel was changed elsewhere. Keep your version, take the latest, or merge?',
            style: const TextStyle(color: AppTheme.textB),
          ),
          if (serverUpdatedAt != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.access_time, size: 14, color: AppTheme.textM),
                const SizedBox(width: 6),
                Text(
                  'Server version updated ${_formatTime(serverUpdatedAt!)}',
                  style: const TextStyle(color: AppTheme.textM, fontSize: 12),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          _OptionTile(
            icon: Icons.edit_note,
            label: 'Keep mine',
            description: 'Overwrite the server with $localLabel.',
            onTap: () => Navigator.of(context).pop(ConflictResolution.keepMine),
          ),
          const SizedBox(height: 8),
          _OptionTile(
            icon: Icons.cloud_download_outlined,
            label: 'Take theirs',
            description: 'Discard your changes and load the latest version.',
            onTap: () => Navigator.of(context).pop(ConflictResolution.takeTheirs),
          ),
          const SizedBox(height: 8),
          _OptionTile(
            icon: Icons.merge,
            label: 'Merge',
            description: 'Review both side-by-side and combine fields.',
            onTap: () => Navigator.of(context).pop(ConflictResolution.merge),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(ConflictResolution.cancel),
          child: const Text('Cancel', style: TextStyle(color: AppTheme.textM)),
        ),
      ],
    );
  }
}

class _OptionTile extends StatefulWidget {
  final IconData icon;
  final String label;
  final String description;
  final VoidCallback onTap;

  const _OptionTile({
    required this.icon,
    required this.label,
    required this.description,
    required this.onTap,
  });

  @override
  State<_OptionTile> createState() => _OptionTileState();
}

class _OptionTileState extends State<_OptionTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: _hovered ? AppTheme.card2 : AppTheme.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _hovered ? AppTheme.gold : AppTheme.border,
              width: _hovered ? 1.2 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(widget.icon, color: AppTheme.gold, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.label,
                      style: const TextStyle(
                        color: AppTheme.textH,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.description,
                      style: const TextStyle(color: AppTheme.textM, fontSize: 11),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppTheme.textM, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
