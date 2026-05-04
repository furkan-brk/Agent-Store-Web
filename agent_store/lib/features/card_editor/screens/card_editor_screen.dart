import 'dart:js_interop';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import 'package:web/web.dart' as web;

import '../../../app/theme.dart';
import '../../../controllers/auth_controller.dart';
import '../../../shared/models/agent_model.dart';
import '../../../shared/services/api_service.dart';
import '../../../shared/services/conflict_resolver.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/conflict_dialog.dart';
import '../bindings/card_editor_binding.dart';
import '../controllers/card_editor_controller.dart';
import '../services/card_export_service.dart';
import '../widgets/editor_preview_panel.dart';
import '../widgets/editor_toolbar.dart';
import '../widgets/sections/editor_sections.dart';

/// Card Editor — split-view ekranı.
///
/// 1. Fetches the agent.
/// 2. Verifies the current wallet owns it (else redirects to detail with a snackbar).
/// 3. Builds the controller and renders toolbar + form/preview split.
/// 4. Wires keyboard shortcuts (Ctrl+Z/Y/S, Esc) and PopScope guard.
class CardEditorScreen extends StatefulWidget {
  const CardEditorScreen({super.key, required this.agentId});
  final int agentId;

  @override
  State<CardEditorScreen> createState() => _CardEditorScreenState();
}

class _CardEditorScreenState extends State<CardEditorScreen> {
  final _previewBoundaryKey = GlobalKey();
  Future<_LoadResult>? _loadFuture;

  @override
  void initState() {
    super.initState();
    _loadFuture = _load();
  }

  @override
  void dispose() {
    CardEditorBinding.unbind(widget.agentId);
    super.dispose();
  }

  Future<_LoadResult> _load() async {
    final agent = await ApiService.instance.getAgent(widget.agentId);
    if (agent == null) {
      return const _LoadResult.error('Agent not found');
    }
    final myWallet = AuthController.to.wallet?.toLowerCase();
    if (myWallet == null || myWallet.isEmpty) {
      return const _LoadResult.error('Connect your wallet to edit');
    }
    if (agent.creatorWallet.toLowerCase() != myWallet) {
      return const _LoadResult.error('You can only edit your own agents');
    }
    final controller = CardEditorBinding.bind(agent);
    return _LoadResult.ready(agent, controller);
  }

  // ── Actions ─────────────────────────────────────────────────────────────

  Future<void> _onClose(BuildContext context, CardEditorController c) async {
    if (c.isDirty) {
      final discard = await ConfirmDialog.show(
        context,
        title: 'Unsaved changes',
        message: 'You have unsaved edits. Save them before leaving?',
        confirmLabel: 'Save & close',
        cancelLabel: 'Discard',
        icon: Icons.warning_amber,
      );
      if (discard) {
        await c.forceSyncToBackend();
      }
    }
    if (!context.mounted) return;
    context.go('/agent/${widget.agentId}');
  }

  Future<void> _onClone(BuildContext context, CardEditorController c) async {
    final messenger = ScaffoldMessenger.of(context);
    // Save pending edits first so the fork uses the latest version.
    await c.forceSyncToBackend();
    final forked = await ApiService.instance.forkAgent(widget.agentId);
    if (!context.mounted) return;
    if (forked == null) {
      messenger.showSnackBar(const SnackBar(
        content: Text('Fork failed'),
        backgroundColor: AppTheme.error,
      ));
      return;
    }
    messenger.showSnackBar(SnackBar(
      content: Text('Cloned as #${forked.id} — opening editor'),
      backgroundColor: AppTheme.olive,
    ));
    context.go('/agent/${forked.id}/edit');
  }

  Future<void> _onExportPng(BuildContext context, AgentModel agent) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await CardExportService.exportPng(_previewBoundaryKey, agent);
    if (!context.mounted) return;
    messenger.showSnackBar(SnackBar(
      content: Text(ok ? 'PNG downloaded' : 'PNG export failed'),
      backgroundColor: ok ? AppTheme.olive : AppTheme.error,
    ));
  }

  Future<void> _onExportSkillMd(BuildContext context, AgentModel agent) async {
    final messenger = ScaffoldMessenger.of(context);
    final content = await ApiService.instance.fetchAgentSkillMd(agent.id);
    if (!context.mounted) return;
    if (content == null) {
      messenger.showSnackBar(const SnackBar(
        content: Text('Could not download SKILL.md — not authorised or network error'),
        backgroundColor: AppTheme.error,
      ));
      return;
    }
    final slug = agent.title
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'-+$'), '');
    final blob = web.Blob(
      [content.toJS].toJS,
      web.BlobPropertyBag(type: 'text/markdown'),
    );
    final url = web.URL.createObjectURL(blob);
    final anchor = web.document.createElement('a') as web.HTMLAnchorElement;
    anchor.href = url;
    anchor.download = '$slug-SKILL.md';
    anchor.click();
    web.URL.revokeObjectURL(url);
    messenger.showSnackBar(const SnackBar(
      content: Text('SKILL.md downloaded'),
      backgroundColor: AppTheme.olive,
    ));
  }

  // ── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_LoadResult>(
      future: _loadFuture,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const _LoadingScaffold();
        }
        final result = snap.data;
        if (result == null || !result.success) {
          return _ErrorScaffold(message: result?.error ?? 'Unknown error', agentId: widget.agentId);
        }
        return _Editor(
          agent: result.agent!,
          controller: result.controller!,
          previewBoundaryKey: _previewBoundaryKey,
          onClose: _onClose,
          onClone: _onClone,
          onExportPng: _onExportPng,
          onExportSkillMd: _onExportSkillMd,
        );
      },
    );
  }
}

class _Editor extends StatefulWidget {
  const _Editor({
    required this.agent,
    required this.controller,
    required this.previewBoundaryKey,
    required this.onClose,
    required this.onClone,
    required this.onExportPng,
    required this.onExportSkillMd,
  });

  final AgentModel agent;
  final CardEditorController controller;
  final GlobalKey previewBoundaryKey;
  final Future<void> Function(BuildContext, CardEditorController) onClose;
  final Future<void> Function(BuildContext, CardEditorController) onClone;
  final Future<void> Function(BuildContext, AgentModel) onExportPng;
  final Future<void> Function(BuildContext, AgentModel) onExportSkillMd;

  @override
  State<_Editor> createState() => _EditorState();
}

class _EditorState extends State<_Editor> {
  Worker? _conflictWatcher;
  bool _conflictDialogOpen = false;

  AgentModel get agent => widget.agent;
  CardEditorController get controller => widget.controller;
  GlobalKey get previewBoundaryKey => widget.previewBoundaryKey;
  Future<void> Function(BuildContext, CardEditorController) get onClose => widget.onClose;
  Future<void> Function(BuildContext, CardEditorController) get onClone => widget.onClone;
  Future<void> Function(BuildContext, AgentModel) get onExportPng => widget.onExportPng;
  Future<void> Function(BuildContext, AgentModel) get onExportSkillMd => widget.onExportSkillMd;

  @override
  void initState() {
    super.initState();
    // v3.7-4.2: when the controller flips to SyncStatus.conflict, open
    // the shared ConflictDialog and route the user's choice back to the
    // controller's resolve* methods.
    _conflictWatcher = ever<SyncStatus>(controller.syncStatus, (s) {
      if (s == SyncStatus.conflict && !_conflictDialogOpen) {
        _showConflict();
      }
    });
  }

  @override
  void dispose() {
    _conflictWatcher?.dispose();
    super.dispose();
  }

  Future<void> _showConflict() async {
    if (!mounted) return;
    _conflictDialogOpen = true;
    try {
      final choice = await showConflictDialog(
        context,
        resourceTypeLabel: 'agent card',
        localLabel: 'Your draft',
      );
      if (!mounted) return;
      switch (choice) {
        case ConflictResolution.keepMine:
        case ConflictResolution.merge:
          await controller.resolveConflictKeepMine();
        case ConflictResolution.takeTheirs:
          controller.resolveConflictWithTheirs();
        case ConflictResolution.cancel:
          // Leave the controller in SyncStatus.conflict so the toolbar
          // badge still shows. User can pick later via the toolbar.
          break;
      }
    } finally {
      _conflictDialogOpen = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 980;

    return PopScope(
      canPop: !controller.isDirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await onClose(context, controller);
      },
      child: Shortcuts(
        shortcuts: const <ShortcutActivator, Intent>{
          SingleActivator(LogicalKeyboardKey.keyZ, control: true): _UndoIntent(),
          SingleActivator(LogicalKeyboardKey.keyY, control: true): _RedoIntent(),
          SingleActivator(LogicalKeyboardKey.keyZ, control: true, shift: true): _RedoIntent(),
          SingleActivator(LogicalKeyboardKey.keyS, control: true): _SaveIntent(),
        },
        child: Actions(
          actions: <Type, Action<Intent>>{
            _UndoIntent: CallbackAction<_UndoIntent>(onInvoke: (_) {
              controller.undo();
              return null;
            }),
            _RedoIntent: CallbackAction<_RedoIntent>(onInvoke: (_) {
              controller.redo();
              return null;
            }),
            _SaveIntent: CallbackAction<_SaveIntent>(onInvoke: (_) {
              controller.forceSyncToBackend();
              return null;
            }),
          },
          child: Focus(
            autofocus: true,
            child: Scaffold(
              backgroundColor: AppTheme.bg,
              body: Column(
                children: [
                  EditorToolbar(
                    controller: controller,
                    onSave: () => controller.forceSyncToBackend(),
                    onClone: () => onClone(context, controller),
                    onExportJson: () => CardExportService.exportJson(controller.draft.value),
                    onExportPng: () => onExportPng(context, controller.draft.value),
                    onExportSkillMd: () => onExportSkillMd(context, controller.draft.value),
                    onClose: () => onClose(context, controller),
                  ),
                  Expanded(
                    child: isWide
                        ? Row(
                            children: [
                              Expanded(
                                flex: 9,
                                child: _FormColumn(controller: controller),
                              ),
                              const VerticalDivider(width: 1, color: AppTheme.border),
                              Expanded(
                                flex: 11,
                                child: EditorPreviewPanel(
                                  controller: controller,
                                  boundaryKey: previewBoundaryKey,
                                ),
                              ),
                            ],
                          )
                        : ListView(
                            children: [
                              SizedBox(
                                height: 420,
                                child: EditorPreviewPanel(
                                  controller: controller,
                                  boundaryKey: previewBoundaryKey,
                                ),
                              ),
                              _FormColumn(controller: controller),
                            ],
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
}

class _FormColumn extends StatelessWidget {
  const _FormColumn({required this.controller});
  final CardEditorController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.bg,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          IdentitySection(controller: controller),
          PromptSection(controller: controller),
          TaxonomySection(controller: controller),
          StatsSection(controller: controller),
          NarrativeSection(controller: controller),
          VisualsSection(controller: controller),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

// ── Loading / error fallbacks ─────────────────────────────────────────────

class _LoadingScaffold extends StatelessWidget {
  const _LoadingScaffold();
  @override
  Widget build(BuildContext context) => const Scaffold(
        backgroundColor: AppTheme.bg,
        body: Center(child: CircularProgressIndicator(color: AppTheme.gold)),
      );
}

class _ErrorScaffold extends StatelessWidget {
  const _ErrorScaffold({required this.message, required this.agentId});
  final String message;
  final int agentId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, color: AppTheme.gold, size: 36),
            const SizedBox(height: 12),
            Text(message, style: const TextStyle(color: AppTheme.textH, fontSize: 15)),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => context.go('/agent/$agentId'),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Back to agent'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Result + intent types ─────────────────────────────────────────────────

class _LoadResult {
  const _LoadResult.ready(this.agent, this.controller)
      : success = true,
        error = null;
  const _LoadResult.error(this.error)
      : success = false,
        agent = null,
        controller = null;

  final bool success;
  final String? error;
  final AgentModel? agent;
  final CardEditorController? controller;
}

class _UndoIntent extends Intent {
  const _UndoIntent();
}

class _RedoIntent extends Intent {
  const _RedoIntent();
}

class _SaveIntent extends Intent {
  const _SaveIntent();
}
