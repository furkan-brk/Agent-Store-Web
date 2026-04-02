// lib/features/legend/widgets/legend_export_dialog.dart

import 'dart:convert';
import 'dart:js_interop';
import 'package:web/web.dart' as web;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../app/theme.dart';
import '../../../shared/models/agent_model.dart';
import '../../../shared/services/api_service.dart';
import '../models/workflow_models.dart';
import '../services/claude_export_service.dart';

class LegendExportDialog extends StatefulWidget {
  final LegendWorkflow workflow;
  final String workflowJson;
  final WorkflowExecution? lastExecution;

  const LegendExportDialog({
    super.key,
    required this.workflow,
    required this.workflowJson,
    this.lastExecution,
  });

  @override
  State<LegendExportDialog> createState() => _LegendExportDialogState();
}

class _LegendExportDialogState extends State<LegendExportDialog> {
  List<AgentModel> _agents = [];
  bool _loading = true;
  String? _error;
  bool _warningDismissed = false;

  @override
  void initState() {
    super.initState();
    _fetchAgents();
  }

  Future<void> _fetchAgents() async {
    final agentIds = widget.workflow.nodes
        .where((n) => n.type == WorkflowNodeType.agent && n.refId != null)
        .map((n) => int.tryParse(n.refId!) ?? 0)
        .where((id) => id > 0)
        .toList();

    if (agentIds.isEmpty) {
      setState(() => _loading = false);
      return;
    }

    try {
      final agents = await ApiService.instance.batchGetAgents(agentIds);
      setState(() {
        _agents = agents;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to fetch agent data';
        _loading = false;
      });
    }
  }

  void _downloadFile(String content, String filename,
      {String mimeType = 'text/plain'}) {
    final blob = web.Blob(
      [content.toJS].toJS,
      web.BlobPropertyBag(type: mimeType),
    );
    final url = web.URL.createObjectURL(blob);
    final anchor = web.document.createElement('a') as web.HTMLAnchorElement;
    anchor.href = url;
    anchor.download = filename;
    anchor.click();
    web.URL.revokeObjectURL(url);
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppTheme.success,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  bool get _hasPromptAccess => _agents.any((a) => a.prompt.isNotEmpty);

  void _downloadCliPackage(String slug) {
    // Generate all files as a combined JSON package
    final teamConfig =
        ClaudeExportService.generateTeamConfig(widget.workflow, _agents);
    final claudeMd =
        ClaudeExportService.generateClaudeMd(widget.workflow, _agents);

    final agentFiles = <String, String>{};
    for (final agent in _agents) {
      if (agent.prompt.isEmpty) continue;
      final agentSlug =
          agent.title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
      agentFiles['$agentSlug.md'] =
          ClaudeExportService.generateAgentMd(agent);
    }
    for (final node in widget.workflow.nodes) {
      if (node.type == WorkflowNodeType.agent &&
          node.refId == null &&
          node.metadata?['prompt'] != null) {
        final nSlug =
            node.label.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
        agentFiles['$nSlug.md'] =
            ClaudeExportService.generateAgentMdFromMetadata(node);
      }
    }

    final readme = '# ${widget.workflow.name} — Claude Code Team\n\n'
        'This workflow was exported from Agent Store Legend.\n\n'
        '## Setup\n'
        '1. Copy the `.claude/` directory and `CLAUDE.md` into your project root\n'
        '2. Open Claude Code CLI: `claude`\n'
        '3. Select the team: `/team $slug`\n'
        '4. Assign tasks and let agents work\n\n'
        '## Files\n'
        '- `.claude/teams/$slug/config.json` — Team configuration\n'
        '- `.claude/agents/*.md` — Individual agent definitions\n'
        '- `CLAUDE.md` — Full team documentation\n';

    // Build a combined JSON that represents the directory structure
    final package = {
      'name': widget.workflow.name,
      'slug': slug,
      'files': {
        '.claude/teams/$slug/config.json': teamConfig,
        ...agentFiles.map((k, v) => MapEntry('.claude/agents/$k', v)),
        'CLAUDE.md': claudeMd,
        'README.md': readme,
      },
    };

    final packageJson =
        const JsonEncoder.withIndent('  ').convert(package);
    _downloadFile(packageJson, '$slug-claude-code-package.json',
        mimeType: 'application/json');

    // Also download individual files for immediate use
    _downloadFile(teamConfig, '$slug-config.json',
        mimeType: 'application/json');
    _downloadFile(claudeMd, '$slug-CLAUDE.md');
    _downloadFile(readme, '$slug-README.md');

    _showSnack('Claude Code package downloaded');
  }

  @override
  Widget build(BuildContext context) {
    final slug = widget.workflow.name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    final screenHeight = MediaQuery.of(context).size.height;
    final maxHeight = (screenHeight * 0.8).clamp(0.0, 500.0);

    return AlertDialog(
      backgroundColor: AppTheme.card,
      title: const Row(
        children: [
          Icon(Icons.upload_file, color: AppTheme.gold, size: 20),
          SizedBox(width: 8),
          Text('Export Workflow',
              style: TextStyle(color: AppTheme.textH, fontSize: 16)),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxHeight),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // -- Error banner --
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppTheme.error.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline,
                                    color: AppTheme.error, size: 14),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(_error!,
                                      style: const TextStyle(
                                          color: AppTheme.error,
                                          fontSize: 11)),
                                ),
                              ],
                            ),
                          ),
                        ),

                      // -- Compact warning banner (dismissible) --
                      if (!_hasPromptAccess &&
                          _error == null &&
                          !_warningDismissed)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppTheme.gold.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.warning_amber_rounded,
                                    color: AppTheme.gold, size: 14),
                                const SizedBox(width: 8),
                                const Expanded(
                                  child: Text(
                                    'Some prompts are not accessible. Those will show placeholder text.',
                                    style: TextStyle(
                                        color: AppTheme.gold, fontSize: 11),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                InkWell(
                                  borderRadius: BorderRadius.circular(10),
                                  onTap: () => setState(
                                      () => _warningDismissed = true),
                                  child: const Padding(
                                    padding: EdgeInsets.all(2),
                                    child: Icon(Icons.close,
                                        color: AppTheme.gold, size: 12),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                      // ===== DOWNLOAD FILES SECTION =====
                      const _SectionHeader(
                        icon: Icons.download_rounded,
                        label: 'Download Files',
                      ),
                      const SizedBox(height: 4),
                      _ExportRow(
                        icon: Icons.smart_toy,
                        color: const Color(0xFF8B5CF6),
                        label: 'Claude Team Config',
                        subtitle: 'config.json',
                        actionIcon: Icons.download_rounded,
                        onTap: () {
                          final content =
                              ClaudeExportService.generateTeamConfig(
                                  widget.workflow, _agents);
                          _downloadFile(content, '$slug-team-config.json',
                              mimeType: 'application/json');
                          _showSnack('Team config downloaded');
                        },
                      ),
                      _ExportRow(
                        icon: Icons.person,
                        color: const Color(0xFF06B6D4),
                        label: 'Claude Agents',
                        subtitle: '*.md files',
                        actionIcon: Icons.download_rounded,
                        onTap: () {
                          for (final agent in _agents) {
                            if (agent.prompt.isEmpty) continue;
                            final md =
                                ClaudeExportService.generateAgentMd(agent);
                            final agentSlug = agent.title
                                .toLowerCase()
                                .replaceAll(RegExp(r'[^a-z0-9]+'), '-');
                            _downloadFile(md, '$agentSlug.md');
                          }
                          // Also export virtual agents from metadata
                          for (final node in widget.workflow.nodes) {
                            if (node.type == WorkflowNodeType.agent &&
                                node.refId == null &&
                                node.metadata?['prompt'] != null) {
                              final md = ClaudeExportService
                                  .generateAgentMdFromMetadata(node);
                              final nSlug = node.label
                                  .toLowerCase()
                                  .replaceAll(RegExp(r'[^a-z0-9]+'), '-');
                              _downloadFile(md, '$nSlug.md');
                            }
                          }
                          _showSnack('Agent files downloaded');
                        },
                      ),
                      _ExportRow(
                        icon: Icons.description,
                        color: const Color(0xFFF59E0B),
                        label: 'CLAUDE.md',
                        subtitle: 'CLAUDE.md',
                        actionIcon: Icons.download_rounded,
                        onTap: () {
                          final content =
                              ClaudeExportService.generateClaudeMd(
                                  widget.workflow, _agents);
                          _downloadFile(content, 'CLAUDE.md');
                          _showSnack('CLAUDE.md downloaded');
                        },
                      ),
                      _ExportRow(
                        icon: Icons.rule,
                        color: const Color(0xFF10B981),
                        label: 'Cursor Rules',
                        subtitle: '.cursorrules',
                        actionIcon: Icons.download_rounded,
                        onTap: () {
                          final content =
                              ClaudeExportService.generateCursorRules(
                                  widget.workflow, _agents);
                          _downloadFile(content, '.cursorrules');
                          _showSnack('.cursorrules downloaded');
                        },
                      ),
                      _ExportRow(
                        icon: Icons.data_object,
                        color: const Color(0xFF3B82F6),
                        label: 'Workflow JSON',
                        subtitle: 'workflow.json',
                        actionIcon: Icons.download_rounded,
                        onTap: () {
                          _downloadFile(
                              widget.workflowJson, '$slug-workflow.json',
                              mimeType: 'application/json');
                          _showSnack('Workflow JSON downloaded');
                        },
                      ),
                      if (widget.lastExecution != null)
                        _ExportRow(
                          icon: Icons.psychology,
                          color: const Color(0xFFEC4899),
                          label: 'Export Context',
                          subtitle: 'context.md',
                          actionIcon: Icons.download_rounded,
                          onTap: () {
                            final content =
                                ClaudeExportService.generateClaudeContext(
                                    widget.lastExecution!, _agents);
                            _downloadFile(content, '$slug-context.md');
                            _showSnack('Execution context downloaded');
                          },
                        ),

                      // ===== DIVIDER =====
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Divider(color: AppTheme.border, height: 1),
                      ),

                      // ===== COPY TO CLIPBOARD SECTION =====
                      const _SectionHeader(
                        icon: Icons.content_copy,
                        label: 'Copy to Clipboard',
                      ),
                      const SizedBox(height: 4),
                      _ExportRow(
                        icon: Icons.copy_all,
                        color: const Color(0xFF6366F1),
                        label: 'Copy All Prompts',
                        subtitle: 'All agent system prompts',
                        actionIcon: Icons.content_copy,
                        onTap: () {
                          final content =
                              ClaudeExportService.generateCursorRules(
                                  widget.workflow, _agents);
                          Clipboard.setData(ClipboardData(text: content));
                          _showSnack('All prompts copied to clipboard');
                        },
                      ),
                      if (widget.lastExecution != null)
                        _ExportRow(
                          icon: Icons.content_copy,
                          color: const Color(0xFFEC4899),
                          label: 'Copy Context',
                          subtitle: 'Execution context',
                          actionIcon: Icons.content_copy,
                          onTap: () {
                            final content =
                                ClaudeExportService.generateClaudeContext(
                                    widget.lastExecution!, _agents);
                            Clipboard.setData(
                                ClipboardData(text: content));
                            _showSnack('Context copied to clipboard');
                          },
                        ),

                      // ===== DIVIDER =====
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Divider(color: AppTheme.border, height: 1),
                      ),

                      // ===== CLAUDE CODE CLI CARD =====
                      InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => _downloadCliPackage(slug),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFF8B5CF6)
                                    .withValues(alpha: 0.1),
                                const Color(0xFFEC4899)
                                    .withValues(alpha: 0.1),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: const Color(0xFF8B5CF6)
                                    .withValues(alpha: 0.3)),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.terminal,
                                  size: 20, color: Color(0xFF8B5CF6)),
                              SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text('Run with Claude Code',
                                        style: TextStyle(
                                            color: Color(0xFF8B5CF6),
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600)),
                                    Text(
                                        'Download full CLI team package (config + agents + README)',
                                        style: TextStyle(
                                            color: AppTheme.textM,
                                            fontSize: 10)),
                                  ],
                                ),
                              ),
                              Icon(Icons.download,
                                  size: 18, color: Color(0xFF8B5CF6)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child:
              const Text('Close', style: TextStyle(color: AppTheme.textM)),
        ),
      ],
    );
  }
}

// -- Section header (e.g. "Download Files", "Copy to Clipboard") --
class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;

  const _SectionHeader({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: AppTheme.textM),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.textM,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

// -- Full-width export row with color indicator, icon, label+subtitle, action icon --
class _ExportRow extends StatefulWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String subtitle;
  final IconData actionIcon;
  final VoidCallback onTap;

  const _ExportRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.subtitle,
    required this.actionIcon,
    required this.onTap,
  });

  @override
  State<_ExportRow> createState() => _ExportRowState();
}

class _ExportRowState extends State<_ExportRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: Material(
          color: _hovered
              ? widget.color.withValues(alpha: 0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: widget.onTap,
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  // Left color indicator bar
                  Container(
                    width: 3,
                    height: 28,
                    decoration: BoxDecoration(
                      color: widget.color.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Icon
                  Icon(widget.icon, size: 18, color: widget.color),
                  const SizedBox(width: 10),
                  // Label + subtitle
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.label,
                          style: const TextStyle(
                            color: AppTheme.textH,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          widget.subtitle,
                          style: TextStyle(
                            color: AppTheme.textM.withValues(alpha: 0.8),
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Action icon on the right
                  Icon(
                    widget.actionIcon,
                    size: 16,
                    color: _hovered
                        ? widget.color
                        : AppTheme.textM.withValues(alpha: 0.5),
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
