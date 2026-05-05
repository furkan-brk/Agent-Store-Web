// lib/features/card_editor/widgets/sync_status_banner.dart
//
// FE-P1-10: Thin sync-status banner for the CardEditor. Mirrors the pattern
// used in missions_screen.dart so the user gets visible sync feedback even
// when the toolbar SyncStatusBadge scrolls off-screen on narrow viewports.
//
// We keep this widget CardEditor-local rather than reusing the Missions one
// because the two enums diverged (CardEditor has `dirty/saving/saved/conflict`,
// MissionService has `idle/syncing/failed/synced`). A future cross-cutting
// shared banner could unify these.

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/theme.dart';
import '../controllers/card_editor_controller.dart';

class SyncStatusBanner extends StatelessWidget {
  const SyncStatusBanner({super.key, required this.controller, this.onRetry});

  final CardEditorController controller;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final status = controller.syncStatus.value;
      switch (status) {
        case SyncStatus.error:
          return _bannerContainer(
            color: AppTheme.error,
            icon: Icons.cloud_off_rounded,
            text: 'Failed to save changes — your edits are kept locally',
            trailing: onRetry == null
                ? null
                : TextButton(
                    onPressed: onRetry,
                    child: const Text('Retry',
                        style: TextStyle(color: AppTheme.error, fontWeight: FontWeight.w600)),
                  ),
          );
        case SyncStatus.conflict:
          return _bannerContainer(
            color: AppTheme.gold,
            icon: Icons.merge_type_rounded,
            text: 'Conflict detected — pick a resolution to continue',
          );
        case SyncStatus.saving:
          return _bannerContainer(
            color: AppTheme.gold,
            icon: Icons.cloud_sync_rounded,
            text: 'Saving changes…',
          );
        case SyncStatus.dirty:
          return _bannerContainer(
            color: AppTheme.gold,
            icon: Icons.edit_note_rounded,
            text: 'Unsaved edits — auto-saving shortly',
          );
        case SyncStatus.idle:
        case SyncStatus.saved:
          return const SizedBox.shrink();
      }
    });
  }

  Widget _bannerContainer({
    required Color color,
    required IconData icon,
    required String text,
    Widget? trailing,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        border: Border(
          bottom: BorderSide(color: color.withValues(alpha: 0.3)),
        ),
      ),
      child: Row(children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: color, fontSize: 12.5, fontWeight: FontWeight.w500),
          ),
        ),
        if (trailing != null) trailing,
      ]),
    );
  }
}
