import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/theme.dart';
import '../controllers/card_editor_controller.dart';
import '../data/card_presets.dart';

/// Top toolbar of the card editor screen.
///
/// Contains: title row + sync badge + Undo/Redo + Save + Clone + Export menu
/// + Close. Pure UI — every action is wired through callbacks so the screen
/// owns the side effects (router, dialogs, exports).
class EditorToolbar extends StatelessWidget {
  const EditorToolbar({
    super.key,
    required this.controller,
    required this.onSave,
    required this.onClone,
    required this.onExportJson,
    required this.onExportPng,
    required this.onExportSkillMd,
    required this.onClose,
    this.onPreviewChanges,
    this.onShowHistory,
  });

  final CardEditorController controller;
  final VoidCallback onSave;
  final VoidCallback onClone;
  final VoidCallback onExportJson;
  final VoidCallback onExportPng;
  final VoidCallback onExportSkillMd;
  final VoidCallback onClose;
  final VoidCallback? onPreviewChanges;
  final VoidCallback? onShowHistory;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.style, color: AppTheme.gold, size: 18),
          const SizedBox(width: 10),
          const Text(
            'Card Editor',
            style: TextStyle(color: AppTheme.textH, fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: 14),
          SyncStatusBadge(controller: controller),
          const Spacer(),
          PresetMenuButton(controller: controller),
          const SizedBox(width: 4),
          if (onPreviewChanges != null)
            PreviewChangesButton(
              controller: controller,
              onPressed: onPreviewChanges!,
            ),
          const SizedBox(width: 4),
          _UndoRedoCluster(controller: controller),
          const SizedBox(width: 12),
          _SaveButton(controller: controller, onPressed: onSave),
          const SizedBox(width: 8),
          _IconAction(icon: Icons.content_copy, tooltip: 'Clone agent', onPressed: onClone),
          if (onShowHistory != null) ...[
            const SizedBox(width: 4),
            _IconAction(
              icon: Icons.history_rounded,
              tooltip: 'Version history',
              onPressed: onShowHistory,
            ),
          ],
          const SizedBox(width: 4),
          _ExportMenu(onExportJson: onExportJson, onExportPng: onExportPng, onExportSkillMd: onExportSkillMd),
          const SizedBox(width: 4),
          _IconAction(icon: Icons.close, tooltip: 'Close (Esc)', onPressed: onClose),
        ],
      ),
    );
  }
}

class _UndoRedoCluster extends StatelessWidget {
  const _UndoRedoCluster({required this.controller});
  final CardEditorController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      // Touch the draft so this rebuilds when history pointers change.
      controller.draft.value;
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _IconAction(
            icon: Icons.undo,
            tooltip: 'Undo (Ctrl+Z)',
            onPressed: controller.canUndo ? controller.undo : null,
          ),
          _IconAction(
            icon: Icons.redo,
            tooltip: 'Redo (Ctrl+Y)',
            onPressed: controller.canRedo ? controller.redo : null,
          ),
        ],
      );
    });
  }
}

class _SaveButton extends StatelessWidget {
  const _SaveButton({required this.controller, required this.onPressed});
  final CardEditorController controller;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final saving = controller.syncStatus.value == SyncStatus.saving;
      return ElevatedButton.icon(
        onPressed: saving ? null : onPressed,
        icon: saving
            ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.textH),
              )
            : const Icon(Icons.save_outlined, size: 16),
        label: const Text('Save'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primary,
          foregroundColor: AppTheme.textH,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      );
    });
  }
}

class _ExportMenu extends StatelessWidget {
  const _ExportMenu({
    required this.onExportJson,
    required this.onExportPng,
    required this.onExportSkillMd,
  });
  final VoidCallback onExportJson;
  final VoidCallback onExportPng;
  final VoidCallback onExportSkillMd;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Export',
      icon: const Icon(Icons.download_outlined, color: AppTheme.textB, size: 18),
      color: AppTheme.card2,
      onSelected: (v) {
        if (v == 'json') onExportJson();
        if (v == 'png') onExportPng();
        if (v == 'skill_md') onExportSkillMd();
      },
      itemBuilder: (_) => const [
        PopupMenuItem(
          value: 'json',
          child: Row(children: [
            Icon(Icons.data_object, color: AppTheme.gold, size: 16),
            SizedBox(width: 8),
            Text('Export as JSON'),
          ]),
        ),
        PopupMenuItem(
          value: 'png',
          child: Row(children: [
            Icon(Icons.image_outlined, color: AppTheme.gold, size: 16),
            SizedBox(width: 8),
            Text('Export as PNG (3×)'),
          ]),
        ),
        PopupMenuItem(
          value: 'skill_md',
          child: Row(children: [
            Icon(Icons.extension_outlined, color: Color(0xFFEF4444), size: 16),
            SizedBox(width: 8),
            Text('Export as SKILL.md'),
          ]),
        ),
      ],
    );
  }
}

class _IconAction extends StatelessWidget {
  const _IconAction({required this.icon, required this.tooltip, required this.onPressed});
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      style: IconButton.styleFrom(
        foregroundColor: AppTheme.textB,
        disabledForegroundColor: AppTheme.textM.withValues(alpha: 0.4),
      ),
    );
  }
}

/// PopupMenu button surfacing card stat-trait presets (v3.11.3 — T9a).
/// Filtered to the agent's character_type plus the universal "any" entries.
class PresetMenuButton extends StatelessWidget {
  const PresetMenuButton({super.key, required this.controller});
  final CardEditorController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final type = controller.draft.value.characterType;
      final available = presetsForCharacter(type);
      return PopupMenuButton<String>(
        tooltip: 'Apply a preset',
        position: PopupMenuPosition.under,
        color: AppTheme.card2,
        onSelected: (id) {
          final preset = available.firstWhere(
            (p) => p.id == id,
            orElse: () => available.first,
          );
          controller.applyPreset(preset);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            duration: const Duration(seconds: 2),
            content: Text('Applied preset: ${preset.name}'),
          ));
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.gold.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppTheme.gold.withValues(alpha: 0.35)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.auto_fix_high_outlined, size: 14, color: AppTheme.gold),
              SizedBox(width: 6),
              Text(
                'Presets',
                style: TextStyle(
                  color: AppTheme.gold,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(width: 4),
              Icon(Icons.expand_more, size: 14, color: AppTheme.gold),
            ],
          ),
        ),
        itemBuilder: (_) => [
          for (final p in available)
            PopupMenuItem<String>(
              value: p.id,
              child: SizedBox(
                width: 280,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      p.name,
                      style: const TextStyle(
                        color: AppTheme.textH,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      p.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppTheme.textM, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
        ],
      );
    });
  }
}

/// Outlined button that opens the original-vs-draft diff modal.
/// Disabled when there are no pending changes.
class PreviewChangesButton extends StatelessWidget {
  const PreviewChangesButton({
    super.key,
    required this.controller,
    required this.onPressed,
  });
  final CardEditorController controller;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      controller.draft.value;
      final dirty = controller.isDirty;
      return TextButton.icon(
        onPressed: dirty ? onPressed : null,
        icon: const Icon(Icons.compare_outlined, size: 14),
        label: const Text('Preview'),
        style: TextButton.styleFrom(
          foregroundColor: AppTheme.gold,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          disabledForegroundColor: AppTheme.textM.withValues(alpha: 0.4),
        ),
      );
    });
  }
}

/// Reactive pill displaying the current SyncStatus (idle/dirty/saving/saved/error).
class SyncStatusBadge extends StatelessWidget {
  const SyncStatusBadge({super.key, required this.controller});
  final CardEditorController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final s = controller.syncStatus.value;
      final (icon, label, color) = switch (s) {
        SyncStatus.idle => (Icons.check_circle_outline, 'Up to date', AppTheme.textM),
        SyncStatus.dirty => (Icons.edit_note, 'Unsaved changes', AppTheme.gold),
        SyncStatus.saving => (Icons.cloud_upload_outlined, 'Saving…', AppTheme.gold),
        SyncStatus.saved => (Icons.cloud_done_outlined, 'Saved', AppTheme.olive),
        SyncStatus.error => (Icons.error_outline, 'Save failed', AppTheme.error),
        SyncStatus.conflict => (Icons.merge_type, 'Conflict', AppTheme.primary),
      };
      return Tooltip(
        message: controller.lastError.value ?? '',
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 12),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      );
    });
  }
}
