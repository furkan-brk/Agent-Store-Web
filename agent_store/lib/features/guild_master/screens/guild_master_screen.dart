// lib/features/guild_master/screens/guild_master_screen.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import 'package:web/web.dart' as web;
import 'dart:js_interop';
import '../../../app/theme.dart';
import '../../../controllers/guild_master_controller.dart';
import '../../../features/character/character_types.dart';
import '../../../features/legend/models/workflow_models.dart';
import '../../../features/legend/services/legend_service.dart';
import '../../../shared/utils/app_snack_bar.dart';
import '../widgets/mention_composer.dart';
import '../widgets/suggest_panel.dart';

// ── File-level helpers ────────────────────────────────────────────────────────

String _fmt(DateTime t) {
  final h = t.hour.toString().padLeft(2, '0');
  final m = t.minute.toString().padLeft(2, '0');
  return '$h:$m';
}

void _downloadMarkdown(String filename, String content) {
  final blob = web.Blob(
    [content.toJS].toJS,
    web.BlobPropertyBag(type: 'text/markdown'),
  );
  final url = web.URL.createObjectURL(blob);
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = filename;
  web.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  web.URL.revokeObjectURL(url);
}

void _exportChat(GuildMasterController ctrl) {
  final teamName = ctrl.suggestion.value?['suggested_name'] as String? ?? 'Guild Session';
  final agents = ctrl.teamAgents.map((a) => a['title'] as String? ?? 'Agent').join(', ');
  final buf = StringBuffer();
  buf.writeln('# Guild Session: $teamName');
  buf.writeln('## Team: $agents');
  buf.writeln();
  buf.writeln('---');
  buf.writeln();
  buf.writeln('## Messages');
  buf.writeln();
  for (final msg in ctrl.allMessages) {
    if (msg.isPrivateMarker) continue;
    final who = msg.isUser ? 'User' : (msg.agentTitle ?? 'Agent');
    buf.writeln('[${_fmt(msg.timestamp)}] **$who**: ${msg.text}');
    buf.writeln();
  }
  _downloadMarkdown('guild_session_${DateTime.now().millisecondsSinceEpoch}.md', buf.toString());
}

void _sendTeamToLegend(BuildContext context, GuildMasterController ctrl) {
  final name = ctrl.suggestion.value?['suggested_name'] as String? ?? 'Guild Team';
  final wf = LegendService.instance.newWorkflow(name);
  final nodes = <WorkflowNode>[];
  final edges = <WorkflowEdge>[];

  final startId = '${wf.id}_start';
  nodes.add(WorkflowNode(id: startId, type: WorkflowNodeType.start, label: 'START', x: 60, y: 100));

  for (int i = 0; i < ctrl.teamAgents.length; i++) {
    final agent = ctrl.teamAgents[i];
    final nodeId = '${wf.id}_agent_$i';
    nodes.add(WorkflowNode(
      id: nodeId,
      type: WorkflowNodeType.agent,
      label: agent['title'] as String? ?? 'Agent',
      x: 60 + (i + 1) * 260.0,
      y: 100,
      refId: agent['id']?.toString(),
    ));
    final prevId = i == 0 ? startId : '${wf.id}_agent_${i - 1}';
    edges.add(WorkflowEdge(id: '${prevId}_$nodeId', fromId: prevId, toId: nodeId));
  }

  final endId = '${wf.id}_end';
  final lastX = 60 + (ctrl.teamAgents.length + 1) * 260.0;
  nodes.add(WorkflowNode(id: endId, type: WorkflowNodeType.end, label: 'END', x: lastX, y: 100));
  if (nodes.length > 1) {
    final prev = nodes[nodes.length - 2];
    edges.add(WorkflowEdge(id: '${prev.id}_$endId', fromId: prev.id, toId: endId));
  }

  LegendService.instance.saveWorkflow(wf.copyWithNodes(nodes, edges));
  context.go('/legend');
}

const _kExamplePrompts = [
  'Build a full-stack web app with auth and payments',
  'Research and summarize a complex topic with citations',
  'Design and review a secure microservices architecture',
  'Write, test, and deploy a data pipeline',
];

// ── Shared utilities ──────────────────────────────────────────────────────────

IconData _charTypeIcon(CharacterType t) => switch (t) {
      CharacterType.wizard => Icons.auto_awesome,
      CharacterType.strategist => Icons.psychology,
      CharacterType.oracle => Icons.bar_chart,
      CharacterType.guardian => Icons.shield,
      CharacterType.artisan => Icons.brush,
      CharacterType.bard => Icons.edit,
      CharacterType.scholar => Icons.school,
      CharacterType.merchant => Icons.trending_up,
    };

/// Small icon-only back button that returns the user to the guilds list.
class _BackToGuildsButton extends StatelessWidget {
  const _BackToGuildsButton();

  @override
  Widget build(BuildContext context) => Tooltip(
        message: 'Back to Guilds',
        child: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.textB, size: 20),
          splashRadius: 20,
          onPressed: () => context.go('/guild'),
        ),
      );
}

// ── Screen root ───────────────────────────────────────────────────────────────

class GuildMasterScreen extends StatelessWidget {
  final List<Map<String, dynamic>>? initialAgents;
  final String? initialGuildName;

  const GuildMasterScreen({super.key, this.initialAgents, this.initialGuildName});

  @override
  Widget build(BuildContext context) {
    late final GuildMasterController ctrl;
    if (initialAgents != null && initialAgents!.isNotEmpty) {
      if (Get.isRegistered<GuildMasterController>(tag: 'guild_from_detail')) {
        Get.delete<GuildMasterController>(tag: 'guild_from_detail');
      }
      ctrl = Get.put(
        GuildMasterController(
          initialAgents: initialAgents,
          initialGuildName: initialGuildName,
        ),
        tag: 'guild_from_detail',
      );
    } else if (Get.isRegistered<GuildMasterController>()) {
      ctrl = Get.find<GuildMasterController>();
    } else {
      ctrl = Get.put(GuildMasterController());
    }

    return Obx(() => switch (ctrl.phase.value) {
          GuildMasterPhase.input => _buildInput(context, ctrl),
          GuildMasterPhase.loading => _buildLoading(),
          GuildMasterPhase.ready => _buildReady(context, ctrl),
        });
  }

  // ── Input phase ─────────────────────────────────────────────────────────────

  Widget _buildInput(BuildContext context, GuildMasterController ctrl) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 0),
          child: Row(children: [_BackToGuildsButton()]),
        ),
        Expanded(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xxl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [AppTheme.primary, AppTheme.primary.withValues(alpha: 0.6)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppTheme.border2, width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primary.withValues(alpha: 0.35),
                              blurRadius: 24,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.auto_awesome, color: AppTheme.textH, size: 32),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    const Text('Guild Master',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppTheme.textH, fontSize: 28, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    const Text('AI-Powered Team Builder',
                        textAlign: TextAlign.center, style: TextStyle(color: AppTheme.textB, fontSize: 14)),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Describe your project or challenge and Guild Master will assemble the ideal team of AI agents to tackle it together.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.textM.withValues(alpha: 0.85), fontSize: 12, height: 1.5),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    const Text('Try one of these:',
                        textAlign: TextAlign.center, style: TextStyle(color: AppTheme.textM, fontSize: 11)),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      alignment: WrapAlignment.center,
                      children: _kExamplePrompts
                          .map((ex) => ActionChip(
                                label: Text(ex, style: const TextStyle(color: AppTheme.textB, fontSize: 10)),
                                backgroundColor: AppTheme.card,
                                side: const BorderSide(color: AppTheme.border),
                                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 0),
                                onPressed: () => ctrl.setExampleHint(ex),
                              ))
                          .toList(),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    _ProblemPromptComposer(ctrl: ctrl),
                    Obx(() {
                      if (ctrl.error.value != null) {
                        return Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.md),
                          child: Row(children: [
                            Icon(Icons.error_outline, size: 14, color: cs.error),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(ctrl.error.value!, style: TextStyle(color: cs.error, fontSize: 13)),
                            ),
                          ]),
                        );
                      }
                      return const SizedBox.shrink();
                    }),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Loading phase ────────────────────────────────────────────────────────────

  Widget _buildLoading() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 0),
          child: Row(children: [_BackToGuildsButton()]),
        ),
        Expanded(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 48,
                  height: 48,
                  child: CircularProgressIndicator(
                      color: AppTheme.primary, strokeWidth: 3, backgroundColor: Color(0x4D3D3020)),
                ),
                SizedBox(height: AppSpacing.xl),
                Text('Analyzing your challenge…',
                    style: TextStyle(color: AppTheme.textB, fontSize: 15, fontWeight: FontWeight.w500)),
                SizedBox(height: AppSpacing.sm),
                Text('Selecting the best agents for your team', style: TextStyle(color: AppTheme.textM, fontSize: 12)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Ready phase ──────────────────────────────────────────────────────────────

  Widget _buildReady(BuildContext context, GuildMasterController ctrl) {
    return LayoutBuilder(builder: (context, constraints) {
      final isNarrow = AppBreakpoints.isMobile(constraints.maxWidth);
      if (isNarrow) {
        final panelH = (constraints.maxHeight * 0.32).clamp(220.0, 320.0);
        return Column(children: [
          SizedBox(height: panelH, child: _LeftPanel(ctrl: ctrl)),
          Expanded(child: _ChatArea(ctrl: ctrl)),
        ]);
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(width: 340, child: _LeftPanel(ctrl: ctrl)),
          Expanded(child: _ChatArea(ctrl: ctrl)),
        ],
      );
    });
  }
}

// ── Left Panel — agent list with multi-select ─────────────────────────────────

class _LeftPanel extends StatelessWidget {
  final GuildMasterController ctrl;
  const _LeftPanel({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(right: BorderSide(color: AppTheme.border)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.md),
          child: Obx(() => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top row: back + eyebrow label + select shortcut
                  Row(children: [
                    const _BackToGuildsButton(),
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(Icons.shield, color: AppTheme.primary, size: 14),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    const Expanded(
                      child: Text('YOUR TEAM',
                          style: TextStyle(
                              color: AppTheme.primary, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.group_add_rounded, size: 14),
                      label: const Text('Select', style: TextStyle(fontSize: 11)),
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () => _showAgentPickerDialog(context, ctrl),
                    ),
                  ]),
                  const SizedBox(height: AppSpacing.sm),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ctrl.suggestion.value?['suggested_name'] as String? ?? 'Custom Squad',
                          style: const TextStyle(color: AppTheme.textH, fontSize: 18, fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          ctrl.suggestion.value?['reasoning'] as String? ?? '',
                          style: const TextStyle(color: AppTheme.textB, fontSize: 12, height: 1.4),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 10),
                        // v3.8 explainability + history surface. "View plan"
                        // shows the structured GuildSuggestion in a sheet;
                        // "Sessions" lists every persisted conversation
                        // for the wallet so the user can resume one.
                        Row(
                          children: [
                            TextButton.icon(
                              onPressed: () => _showSuggestPanelSheet(context, ctrl),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                minimumSize: const Size(0, 28),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                visualDensity: VisualDensity.compact,
                                foregroundColor: AppTheme.gold,
                              ),
                              icon: const Icon(Icons.menu_book_outlined, size: 14),
                              label: const Text('View plan', style: TextStyle(fontSize: 12)),
                            ),
                            const SizedBox(width: 6),
                            TextButton.icon(
                              onPressed: () => _showSessionsSheet(context, ctrl),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                minimumSize: const Size(0, 28),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                visualDensity: VisualDensity.compact,
                                foregroundColor: AppTheme.textB,
                              ),
                              icon: const Icon(Icons.history, size: 14),
                              label: const Text('Sessions', style: TextStyle(fontSize: 12)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        // v3.8 action bridges: Save as Mission / Open in Legend.
                        // Disabled while the bridge call is in flight or
                        // before a session is registered server-side
                        // (offline first run).
                        _BridgeActions(ctrl: ctrl),
                      ],
                    ),
                  ),
                ],
              )),
        ),
        const Divider(color: AppTheme.border, height: 1),

        // Agent list
        Expanded(
          child: Obx(() {
            if (ctrl.teamAgents.isEmpty) {
              return Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.group_off_outlined, color: AppTheme.textM.withValues(alpha: 0.5), size: 40),
                  const SizedBox(height: AppSpacing.md),
                  const Text('No agents found', style: TextStyle(color: AppTheme.textM, fontSize: 13)),
                ]),
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
              itemCount: ctrl.teamAgents.length,
              itemBuilder: (_, i) {
                final agent = ctrl.teamAgents[i];
                final id = (agent['id'] as num).toInt();
                return _AgentCheckTile(
                  agent: agent,
                  agentId: id,
                  ctrl: ctrl,
                );
              },
            );
          }),
        ),

        // Selection status + reset
        const Divider(color: AppTheme.border, height: 1),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Obx(() => Text(
                    '${ctrl.selectedAgentIds.length} of ${ctrl.teamAgents.length} active',
                    style: const TextStyle(color: AppTheme.textM, fontSize: 11),
                    textAlign: TextAlign.center,
                  )),
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.textB,
                  side: const BorderSide(color: AppTheme.border),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('New Problem'),
                onPressed: ctrl.reset,
              ),
              const SizedBox(height: AppSpacing.sm),
              Obx(() => ctrl.teamAgents.isNotEmpty
                  ? FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.primary.withValues(alpha: 0.15),
                        foregroundColor: AppTheme.primary,
                        side: const BorderSide(color: AppTheme.primary, width: 0.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.account_tree_outlined, size: 16),
                      label: const Text('Open in Legend'),
                      onPressed: () => _sendTeamToLegend(context, ctrl),
                    )
                  : const SizedBox.shrink()),
            ],
          ),
        ),
      ]),
    );
  }
}

// ── Agent tile with checkbox ──────────────────────────────────────────────────

class _AgentCheckTile extends StatefulWidget {
  final Map<String, dynamic> agent;
  final int agentId;
  final GuildMasterController ctrl;
  const _AgentCheckTile({required this.agent, required this.agentId, required this.ctrl});

  @override
  State<_AgentCheckTile> createState() => _AgentCheckTileState();
}

class _AgentCheckTileState extends State<_AgentCheckTile> {
  bool _hovered = false;

  void _showAgentDetail(BuildContext context) {
    final agent = widget.agent;
    final charType = characterTypeFromString(agent['character_type'] as String? ?? '');
    final color = charType.primaryColor;
    final agentId = widget.agentId;
    final outerContext = context;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppTheme.border2,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: color.withValues(alpha: 0.4)),
                ),
                child: Icon(_charTypeIcon(charType), color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      agent['title'] as String? ?? 'Agent',
                      style: const TextStyle(color: AppTheme.textH, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(charType.displayName,
                            style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
                      ),
                      const SizedBox(width: 6),
                      Text(agent['category'] as String? ?? '',
                          style: const TextStyle(color: AppTheme.textM, fontSize: 10)),
                    ]),
                  ],
                ),
              ),
            ]),
            const SizedBox(height: 12),
            const Divider(color: AppTheme.border),
            const SizedBox(height: 8),
            if ((agent['description'] as String?)?.isNotEmpty == true) ...[
              const Text('Description',
                  style: TextStyle(color: AppTheme.textM, fontSize: 11, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(
                agent['description'] as String? ?? '',
                style: const TextStyle(color: AppTheme.textB, fontSize: 13, height: 1.4),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 10),
            ],
            if ((agent['prompt'] as String?)?.isNotEmpty == true) ...[
              const Text('Prompt Preview',
                  style: TextStyle(color: AppTheme.textM, fontSize: 11, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Text(
                  (agent['prompt'] as String? ?? '').length > 300
                      ? '${(agent['prompt'] as String).substring(0, 300)}...'
                      : agent['prompt'] as String,
                  style: const TextStyle(
                      color: AppTheme.textB, fontSize: 11, height: 1.5, fontFamily: 'monospace'),
                ),
              ),
              const SizedBox(height: 12),
            ],
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.open_in_new, size: 14),
                  label: const Text('View Full'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primary,
                    side: const BorderSide(color: AppTheme.primary),
                  ),
                  onPressed: () {
                    Navigator.pop(sheetCtx);
                    outerContext.push('/agent/$agentId');
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Obx(() {
                  final isLeader = widget.ctrl.leaderAgentId.value == agentId;
                  return FilledButton.icon(
                    icon: Icon(isLeader ? Icons.star_border_rounded : Icons.star_rounded, size: 14),
                    label: Text(isLeader ? 'Remove Leader' : 'Set Leader'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.gold,
                      foregroundColor: const Color(0xFF1E1A14),
                    ),
                    onPressed: () {
                      Navigator.pop(sheetCtx);
                      widget.ctrl.setLeader(agentId);
                    },
                  );
                }),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final charType = characterTypeFromString(widget.agent['character_type'] as String? ?? '');
    final color = charType.primaryColor;

    return Obx(() {
      final selected = widget.ctrl.selectedAgentIds.contains(widget.agentId);
      final isActiveTab = widget.ctrl.activeTabId.value == widget.agentId;
      final isLeader = widget.ctrl.leaderAgentId.value == widget.agentId;

      return MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: () => widget.ctrl.switchToTab(widget.agentId),
          onLongPress: () => _showAgentDetail(context),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: isActiveTab
                  ? color.withValues(alpha: 0.10)
                  : _hovered
                      ? AppTheme.card2
                      : AppTheme.card,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected
                    ? color.withValues(alpha: isActiveTab ? 0.6 : 0.35)
                    : _hovered
                        ? AppTheme.border2
                        : AppTheme.border,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Row(children: [
              // Active / inactive dot indicator (replaces Checkbox)
              GestureDetector(
                onTap: () => widget.ctrl.toggleAgentSelection(widget.agentId),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected ? color.withValues(alpha: 0.18) : AppTheme.surface,
                    border: Border.all(
                      color: selected ? color : AppTheme.border2.withValues(alpha: 0.5),
                      width: selected ? 2 : 1,
                    ),
                  ),
                  child: selected
                      ? Center(
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: color,
                              boxShadow: [
                                BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 4),
                              ],
                            ),
                          ),
                        )
                      : null,
                ),
              ),
              const SizedBox(width: 8),
              // Character icon with optional leader star
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: color.withValues(alpha: 0.4)),
                    ),
                    child: Icon(_charTypeIcon(charType), color: color, size: 18),
                  ),
                  if (isLeader)
                    Positioned(
                      top: -4,
                      right: -4,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: AppTheme.gold,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppTheme.surface, width: 1.5),
                        ),
                        child: const Icon(Icons.star_rounded, size: 8, color: Color(0xFF1E1A14)),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 10),
              // Name + role
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.agent['title'] as String? ?? 'Agent',
                      style: TextStyle(
                          color: isActiveTab ? color : AppTheme.textH, fontSize: 13, fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      isLeader ? '★ Team Leader' : charType.displayName,
                      style: TextStyle(
                          color: isLeader ? AppTheme.gold : color.withValues(alpha: 0.8),
                          fontSize: 10,
                          fontWeight: isLeader ? FontWeight.w600 : FontWeight.normal),
                    ),
                  ],
                ),
              ),
              if (isActiveTab) Icon(Icons.chat_bubble_rounded, color: color, size: 14),
            ]),
          ),
        ),
      );
    });
  }
}

// ── Chat area with tabs ───────────────────────────────────────────────────────

class _ChatArea extends StatelessWidget {
  final GuildMasterController ctrl;
  const _ChatArea({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Container(
        height: 36,
        color: AppTheme.surface,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        child: Row(children: [
          Obx(() {
            final name = ctrl.suggestion.value?['suggested_name'] as String? ?? 'Guild Session';
            return Text(name,
                style: const TextStyle(
                    color: AppTheme.textM, fontSize: 11, fontWeight: FontWeight.w600));
          }),
          const Spacer(),
          Tooltip(
            message: 'Export chat as Markdown',
            child: IconButton(
              icon: const Icon(Icons.download_outlined, color: AppTheme.textM, size: 16),
              onPressed: () => _exportChat(ctrl),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            ),
          ),
        ]),
      ),
      _TabBar(ctrl: ctrl),
      Expanded(child: _MessageList(ctrl: ctrl)),
      _InputArea(ctrl: ctrl),
    ]);
  }
}

// ── Tab bar ───────────────────────────────────────────────────────────────────

class _TabBar extends StatelessWidget {
  final GuildMasterController ctrl;
  const _TabBar({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      child: Obx(() {
        final activeId = ctrl.activeTabId.value;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            _TabItem(
              label: 'All',
              icon: Icons.forum_outlined,
              color: AppTheme.primary,
              isActive: activeId == null,
              onTap: () => ctrl.switchToTab(null),
            ),
            ...ctrl.teamAgents.map((agent) {
              final id = (agent['id'] as num).toInt();
              final charType = characterTypeFromString(agent['character_type'] as String? ?? '');
              return _TabItem(
                label: agent['title'] as String? ?? 'Agent',
                icon: _charTypeIcon(charType),
                color: charType.primaryColor,
                isActive: activeId == id,
                onTap: () => ctrl.switchToTab(id),
              );
            }),
          ]),
        );
      }),
    );
  }
}

class _TabItem extends StatefulWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool isActive;
  final VoidCallback onTap;
  const _TabItem({
    required this.label,
    required this.icon,
    required this.color,
    required this.isActive,
    required this.onTap,
  });

  @override
  State<_TabItem> createState() => _TabItemState();
}

class _TabItemState extends State<_TabItem> {
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
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 0),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: widget.isActive ? widget.color : Colors.transparent,
                width: 2,
              ),
            ),
            color: _hovered && !widget.isActive ? AppTheme.card.withValues(alpha: 0.5) : Colors.transparent,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.icon,
                size: 14,
                color: widget.isActive ? widget.color : AppTheme.textM,
              ),
              const SizedBox(width: 6),
              Text(
                widget.label,
                style: TextStyle(
                  color: widget.isActive ? widget.color : AppTheme.textM,
                  fontSize: 12,
                  fontWeight: widget.isActive ? FontWeight.w600 : FontWeight.normal,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Message list ──────────────────────────────────────────────────────────────

class _MessageList extends StatefulWidget {
  final GuildMasterController ctrl;
  const _MessageList({required this.ctrl});

  @override
  State<_MessageList> createState() => _MessageListState();
}

class _MessageListState extends State<_MessageList> {
  final _scrollCtrl = ScrollController();

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  void scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final activeId = widget.ctrl.activeTabId.value;
      final thread = widget.ctrl.getThread(activeId);
      final loading = widget.ctrl.isChatLoading.value;
      final crossLoading = widget.ctrl.isCrossLoading.value;

      if (thread.isNotEmpty || loading || crossLoading) scrollToBottom();

      if (thread.isEmpty && !loading) {
        return Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.forum_outlined, color: AppTheme.textM.withValues(alpha: 0.4), size: 48),
            const SizedBox(height: AppSpacing.md),
            const Text('Ask your team anything!',
                style: TextStyle(color: AppTheme.textB, fontSize: 15, fontWeight: FontWeight.w500)),
            const SizedBox(height: AppSpacing.xs),
            Text(
              activeId == null
                  ? 'Messages broadcast to all selected agents'
                  : 'Messages to this agent and team discussions appear here',
              style: const TextStyle(color: AppTheme.textM, fontSize: 12),
            ),
          ]),
        );
      }

      final itemCount = thread.length + (loading ? 1 : 0) + (crossLoading ? 1 : 0);

      return ListView.builder(
        controller: _scrollCtrl,
        padding: const EdgeInsets.all(AppSpacing.lg),
        itemCount: itemCount,
        itemBuilder: (_, i) {
          if (i == thread.length && loading) {
            return const Padding(
              padding: EdgeInsets.only(top: AppSpacing.sm),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),
                ),
              ),
            );
          }
          if (i == thread.length + (loading ? 1 : 0) && crossLoading) {
            return Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.sync, size: 12, color: AppTheme.gold.withValues(alpha: 0.7)),
                const SizedBox(width: 6),
                const Text('Team discussing…', style: TextStyle(color: AppTheme.textM, fontSize: 11)),
              ]),
            );
          }

          final msg = thread[i];
          if (msg.isUser) return _UserBubble(text: msg.text, timestamp: msg.timestamp);
          if (msg.isPrivateMarker) return _PrivateMarkerRow(agentName: msg.text);
          return _AgentResponseCard(message: msg);
        },
      );
    });
  }
}

// ── Input area with Monaco editor ────────────────────────────────────────────

class _InputArea extends StatefulWidget {
  final GuildMasterController ctrl;
  const _InputArea({required this.ctrl});

  @override
  State<_InputArea> createState() => _InputAreaState();
}

class _InputAreaState extends State<_InputArea> {
  final _composerKey = GlobalKey<MentionComposerState>();

  Future<void> _send() async {
    if (widget.ctrl.isChatLoading.value || widget.ctrl.isCrossLoading.value) return;
    if (widget.ctrl.selectedAgentIds.isEmpty) {
      if (mounted) {
        AppSnackBar.info(context, 'Select at least one agent from the panel');
      }
      return;
    }
    final value = _composerKey.currentState?.getValue().trim() ?? '';
    if (value.isEmpty) return;
    _composerKey.currentState?.clear();
    await widget.ctrl.sendBroadcast(value);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(top: BorderSide(color: AppTheme.border)),
      ),
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Monaco editor + mention dropdown
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Obx(() => MentionComposer(
                        key: _composerKey,
                        height: 80,
                        submitOnEnter: true,
                        agentProvider: () => widget.ctrl.libraryAgents,
                        libraryLoading: widget.ctrl.isLibraryLoading.value,
                        onSubmit: (val) async {
                          await widget.ctrl.sendBroadcast(val);
                        },
                      )),
                ),
              ),
              const SizedBox(width: 10),

              // Send button
              Obx(() => SizedBox(
                    width: 46,
                    height: 80,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: AppTheme.textH,
                        disabledBackgroundColor: AppTheme.primary.withValues(alpha: 0.4),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: EdgeInsets.zero,
                      ),
                      onPressed: widget.ctrl.isChatLoading.value ||
                              widget.ctrl.isCrossLoading.value ||
                              widget.ctrl.selectedAgentIds.isEmpty
                          ? null
                          : _send,
                      child: const Icon(Icons.send_rounded, size: 18),
                    ),
                  )),
            ],
          ),

          // Hint + error
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'Type @ to mention agents · # for missions · Shift+Enter for newline',
              style: TextStyle(color: AppTheme.textM.withValues(alpha: 0.6), fontSize: 10),
            ),
          ),
          Obx(() {
            final err = widget.ctrl.error.value;
            if (err == null) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(children: [
                const Icon(Icons.error_outline, size: 12, color: AppTheme.primary),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(err, style: const TextStyle(color: AppTheme.primary, fontSize: 11)),
                ),
              ]),
            );
          }),
        ],
      ),
    );
  }
}

// ── Problem prompt composer (input phase) ─────────────────────────────────────

class _ProblemPromptComposer extends StatefulWidget {
  final GuildMasterController ctrl;
  const _ProblemPromptComposer({required this.ctrl});

  @override
  State<_ProblemPromptComposer> createState() => _ProblemPromptComposerState();
}

class _ProblemPromptComposerState extends State<_ProblemPromptComposer> {
  final _composerKey = GlobalKey<MentionComposerState>();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();

    // Show error snackbar when findTeam() fails
    ever(widget.ctrl.error, (err) {
      if (err != null && mounted) {
        AppSnackBar.error(context, err);
      }
    });

    // Respond to example chip taps
    ever(widget.ctrl.exampleHint, (hint) {
      if (hint != null && mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _composerKey.currentState?.setValue(hint);
          widget.ctrl.exampleHint.value = null;
        });
      }
    });

    // Pre-fill with last problem text on first mount (after error recovery)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final saved = widget.ctrl.lastProblem;
      if (saved.isNotEmpty) {
        _composerKey.currentState?.setValue(saved);
      }
    });
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);
    try {
      final trimmed = (_composerKey.currentState?.getValue() ?? '').trim();
      if (trimmed.isEmpty) return;
      await widget.ctrl.findTeam(trimmed);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Monaco editor + mention dropdown
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSizing.cardRadius - 2),
            border: Border.all(color: AppTheme.border),
            boxShadow: const [BoxShadow(color: Color(0x20000000), blurRadius: 8, offset: Offset(0, 2))],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppSizing.cardRadius - 2),
            child: Obx(() => MentionComposer(
                  key: _composerKey,
                  height: 160,
                  submitOnEnter: false,
                  agentProvider: () => widget.ctrl.libraryAgents,
                  libraryLoading: widget.ctrl.isLibraryLoading.value,
                )),
          ),
        ),

        const SizedBox(height: AppSpacing.xl - 4),

        SizedBox(
          height: 48,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: AppTheme.textH,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: _isSubmitting
                ? const SizedBox(
                    width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.textH))
                : const Icon(Icons.groups, size: 18),
            label: const Text('Find My Team', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            onPressed: _isSubmitting ? null : _submit,
          ),
        ),
      ],
    );
  }
}

// ── Agent picker dialog ───────────────────────────────────────────────────────

void _showAgentPickerDialog(BuildContext context, GuildMasterController ctrl) {
  showDialog<void>(
    context: context,
    builder: (_) => _AgentPickerDialog(ctrl: ctrl),
  );
}

class _AgentPickerDialog extends StatefulWidget {
  final GuildMasterController ctrl;
  const _AgentPickerDialog({required this.ctrl});

  @override
  State<_AgentPickerDialog> createState() => _AgentPickerDialogState();
}

class _AgentPickerDialogState extends State<_AgentPickerDialog> {
  final Set<int> _picked = {};
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final all = widget.ctrl.libraryAgents;
    final existing = widget.ctrl.teamAgents.map((a) => (a['id'] as num).toInt()).toSet();
    final filtered = all
        .where(
            (a) => !existing.contains(a.id) && (a.title.toLowerCase().contains(_query.toLowerCase()) || _query.isEmpty))
        .toList();

    return AlertDialog(
      backgroundColor: AppTheme.card,
      insetPadding: const EdgeInsets.all(32),
      title:
          const Text('Add Agents', style: TextStyle(color: AppTheme.textH, fontSize: 16, fontWeight: FontWeight.bold)),
      content: SizedBox(
        width: 400,
        height: 420,
        child: Column(children: [
          TextField(
            style: const TextStyle(color: AppTheme.textH, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Search agents…',
              hintStyle: const TextStyle(color: AppTheme.textM, fontSize: 12),
              filled: true,
              fillColor: AppTheme.surface,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.textM, size: 16),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.border)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.border)),
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: filtered.isEmpty
                ? const Center(
                    child: Text('No agents available', style: TextStyle(color: AppTheme.textM, fontSize: 13)))
                : ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (_, i) {
                      final agent = filtered[i];
                      final isPicked = _picked.contains(agent.id);
                      final charType = agent.characterType;
                      final color = charType.primaryColor;
                      return ListTile(
                        dense: true,
                        leading: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(_charTypeIcon(charType), color: color, size: 16),
                        ),
                        title: Text(agent.title, style: const TextStyle(color: AppTheme.textH, fontSize: 13)),
                        subtitle: Text(charType.displayName,
                            style: TextStyle(color: color.withValues(alpha: 0.8), fontSize: 10)),
                        trailing: isPicked
                            ? Icon(Icons.check_circle_rounded, color: color, size: 18)
                            : const Icon(Icons.add_circle_outline_rounded, color: AppTheme.textM, size: 18),
                        onTap: () => setState(() {
                          if (isPicked) {
                            _picked.remove(agent.id);
                          } else {
                            _picked.add(agent.id);
                          }
                        }),
                      );
                    },
                  ),
          ),
        ]),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: AppTheme.textM)),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AppTheme.primary,
            foregroundColor: AppTheme.textH,
          ),
          onPressed: _picked.isEmpty
              ? null
              : () {
                  final toAdd = widget.ctrl.libraryAgents
                      .where((a) => _picked.contains(a.id))
                      .map((a) => {
                            'id': a.id,
                            'title': a.title,
                            'character_type': a.characterType.name,
                          })
                      .toList();
                  widget.ctrl.addAgentsToTeam(toAdd);
                  Navigator.pop(context);
                },
          child: Text('Add ${_picked.isEmpty ? '' : '(${_picked.length}) '}Agents'),
        ),
      ],
    );
  }
}

// ── Private DM marker row ─────────────────────────────────────────────────────

class _PrivateMarkerRow extends StatelessWidget {
  final String agentName;
  const _PrivateMarkerRow({required this.agentName});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_outline_rounded, size: 11, color: AppTheme.textM),
            const SizedBox(width: 6),
            Text(
              'Private → $agentName',
              style: const TextStyle(color: AppTheme.textM, fontSize: 11, fontStyle: FontStyle.italic),
            ),
          ],
        ),
      );
}

// ── Chat bubbles ──────────────────────────────────────────────────────────────

class _UserBubble extends StatelessWidget {
  final String text;
  final DateTime timestamp;
  const _UserBubble({required this.text, required this.timestamp});

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.md, left: 60),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppTheme.primary,
            borderRadius: BorderRadius.circular(AppSpacing.md),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              SelectableText(text, style: const TextStyle(color: AppTheme.textH, fontSize: 14, height: 1.4)),
              const SizedBox(height: 4),
              Text(
                _fmt(timestamp),
                style: TextStyle(color: AppTheme.textH.withValues(alpha: 0.5), fontSize: 10),
              ),
            ],
          ),
        ),
      );
}

// ── Agent response card ───────────────────────────────────────────────────────

class _AgentResponseCard extends StatefulWidget {
  final GuildChatMessage message;
  const _AgentResponseCard({required this.message});

  @override
  State<_AgentResponseCard> createState() => _AgentResponseCardState();
}

class _AgentResponseCardState extends State<_AgentResponseCard> with SingleTickerProviderStateMixin {
  late final AnimationController _anim;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 350))..forward();
    _opacity = CurvedAnimation(parent: _anim, curve: Curves.easeIn);
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final charType = characterTypeFromString(widget.message.characterType ?? '');
    final color = charType.primaryColor;
    final isCross = widget.message.isCrossAgent;

    return FadeTransition(
      opacity: _opacity,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        decoration: BoxDecoration(
          color: isCross ? AppTheme.card.withValues(alpha: 0.7) : AppTheme.card,
          borderRadius: BorderRadius.circular(10),
          border: isCross
              ? Border.all(color: AppTheme.gold.withValues(alpha: 0.25))
              : Border(left: BorderSide(color: color, width: 3)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md + 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(children: [
                if (isCross)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Icon(Icons.swap_horiz_rounded, size: 12, color: AppTheme.gold.withValues(alpha: 0.7)),
                  ),
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: isCross ? AppTheme.gold.withValues(alpha: 0.12) : color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(_charTypeIcon(charType), color: isCross ? AppTheme.gold : color, size: 13),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.message.agentTitle ?? 'Agent',
                        style: TextStyle(
                            color: isCross ? AppTheme.gold : color, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      if (widget.message.role != null)
                        Text(
                          isCross ? '↔ Team Discussion' : widget.message.role!,
                          style: const TextStyle(color: AppTheme.textM, fontSize: 10),
                        ),
                    ],
                  ),
                ),
              ]),
              const SizedBox(height: AppSpacing.sm),
              SelectableText(
                widget.message.text,
                style: const TextStyle(color: AppTheme.textB, fontSize: 13, height: 1.6),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                _fmt(widget.message.timestamp),
                style: const TextStyle(color: AppTheme.textM, fontSize: 10),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// -- v3.8 Action Bridge UI --------------------------------------------------

/// Shows the structured GuildSuggestion (Goal/Plan/Owners/Risks/Success
/// criteria + per-agent confidence) in a draggable bottom sheet so the
/// user can study the rationale without losing the chat tab.
void _showSuggestPanelSheet(BuildContext context, GuildMasterController ctrl) {
  final suggestion = ctrl.suggestion.value;
  if (suggestion == null) {
    AppSnackBar.info(context, 'No suggestion to view yet � run a problem first.');
    return;
  }
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppTheme.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) {
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.65,
        maxChildSize: 0.92,
        minChildSize: 0.4,
        builder: (_, scrollCtrl) => SingleChildScrollView(
          controller: scrollCtrl,
          padding: const EdgeInsets.all(16),
          child: SuggestPanel(suggestion: suggestion),
        ),
      );
    },
  );
}

/// Pair of action-bridge buttons: Save as Mission (outlined) +
/// Open in Legend (filled). Both delegate to the controller, surface
/// the resulting message via SnackBar, and route the user when the
/// Legend bridge succeeds.
class _BridgeActions extends StatelessWidget {
  final GuildMasterController ctrl;
  const _BridgeActions({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final hasSession = ctrl.currentSessionId.value != null;
      final hasSuggestion = ctrl.suggestion.value != null;
      final disabled = ctrl.isBridgeLoading.value || !hasSession || !hasSuggestion;

      String? disabledReason;
      if (!hasSuggestion) {
        disabledReason = 'Run a suggestion first.';
      } else if (!hasSession) {
        disabledReason = 'Connect wallet to enable bridges.';
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: disabled ? null : () => _onSaveAsMission(context),
                  icon: const Icon(Icons.bookmark_add_outlined, size: 14),
                  label: const Text('Save as Mission', style: TextStyle(fontSize: 11)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    minimumSize: const Size(0, 32),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: disabled ? null : () => _onOpenInLegend(context),
                  icon: ctrl.isBridgeLoading.value
                      ? const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.account_tree_outlined, size: 14),
                  label: const Text('Open in Legend', style: TextStyle(fontSize: 11)),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    minimumSize: const Size(0, 32),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ),
            ],
          ),
          if (disabledReason != null) ...[
            const SizedBox(height: 4),
            Text(
              disabledReason,
              style: const TextStyle(color: AppTheme.textM, fontSize: 10),
            ),
          ],
        ],
      );
    });
  }

  Future<void> _onSaveAsMission(BuildContext context) async {
    final id = await ctrl.saveAsMission();
    if (!context.mounted) return;
    final msg = ctrl.lastBridgeMessage.value;
    if (id != null) {
      AppSnackBar.success(context, msg ?? 'Mission saved.');
    } else {
      AppSnackBar.error(context, msg ?? 'Could not save mission.');
    }
  }

  Future<void> _onOpenInLegend(BuildContext context) async {
    final workflowId = await ctrl.openInLegend();
    if (!context.mounted) return;
    final msg = ctrl.lastBridgeMessage.value;
    if (workflowId == null) {
      AppSnackBar.error(context, msg ?? 'Could not open in Legend.');
      return;
    }
    AppSnackBar.success(context, msg ?? 'Workflow created.');
    // Refresh local Legend cache then route to the new workflow. The
    // refresh is best-effort � even if it fails the route still works
    // because LegendService falls back to a backend GET on demand.
    await LegendService.instance.refresh();
    if (!context.mounted) return;
    context.go('/legend?id=$workflowId');
  }
}

/// Bottom sheet listing every persisted Guild Master session for the
/// wallet. Tap a row to load it, swipe-action delete to drop it.
/// Triggers a refresh on open so the list reflects sessions created
/// from other tabs.
void _showSessionsSheet(BuildContext context, GuildMasterController ctrl) {
  // Fire-and-forget: the sheet listens to ctrl.sessionList reactively,
  // so it'll fill in once the request lands.
  ctrl.loadSessionList();
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppTheme.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) {
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.55,
        maxChildSize: 0.85,
        minChildSize: 0.3,
        builder: (_, scrollCtrl) => Padding(
          padding: const EdgeInsets.all(16),
          child: Obx(() {
            if (ctrl.isSessionListLoading.value && ctrl.sessionList.isEmpty) {
              return const Center(
                child: CircularProgressIndicator(color: AppTheme.gold),
              );
            }
            if (ctrl.sessionList.isEmpty) {
              return const Center(
                child: Text(
                  'No saved sessions yet.\nRun a new suggestion to start one.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.textM, fontSize: 13),
                ),
              );
            }
            return ListView.separated(
              controller: scrollCtrl,
              itemCount: ctrl.sessionList.length,
              separatorBuilder: (_, __) => const Divider(color: AppTheme.border, height: 1),
              itemBuilder: (_, i) {
                final s = ctrl.sessionList[i];
                final id = (s['id'] as num).toInt();
                final title = (s['title'] as String?) ?? 'Untitled';
                final problem = (s['problem'] as String?) ?? '';
                final messageCount = (s['message_count'] as num?)?.toInt() ?? 0;
                final isActive = ctrl.currentSessionId.value == id;
                return ListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  leading: Icon(
                    isActive ? Icons.chat_bubble : Icons.chat_bubble_outline,
                    color: isActive ? AppTheme.gold : AppTheme.textM,
                    size: 18,
                  ),
                  title: Text(
                    title,
                    style: TextStyle(
                      color: AppTheme.textH,
                      fontSize: 13,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    problem.isNotEmpty
                        ? problem
                        : '$messageCount message${messageCount == 1 ? '' : 's'}',
                    style: const TextStyle(color: AppTheme.textM, fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, size: 16, color: AppTheme.textM),
                    splashRadius: 18,
                    tooltip: 'Delete session',
                    onPressed: () async {
                      await ctrl.deleteSession(id);
                    },
                  ),
                  onTap: () async {
                    Navigator.of(ctx).pop();
                    await ctrl.selectSession(id);
                  },
                );
              },
            );
          }),
        ),
      );
    },
  );
}
