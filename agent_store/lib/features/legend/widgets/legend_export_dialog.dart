// lib/features/legend/widgets/legend_export_dialog.dart

import 'dart:convert';
import 'dart:html' as html;
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
    final blob = html.Blob([content], mimeType);
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..setAttribute('download', filename)
      ..click();
    html.Url.revokeObjectUrl(url);
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
    final teamConfig = ClaudeExportService.generateTeamConfig(widget.workflow, _agents);
    final claudeMd = ClaudeExportService.generateClaudeMd(widget.workflow, _agents);

    final agentFiles = <String, String>{};
    for (final agent in _agents) {
      if (agent.prompt.isEmpty) continue;
      final agentSlug = agent.title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
      agentFiles['$agentSlug.md'] = ClaudeExportService.generateAgentMd(agent);
    }
    for (final node in widget.workflow.nodes) {
      if (node.type == WorkflowNodeType.agent && node.refId == null && node.metadata?['prompt'] != null) {
        final nSlug = node.label.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
        agentFiles['$nSlug.md'] = ClaudeExportService.generateAgentMdFromMetadata(node);
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

    final packageJson = const JsonEncoder.withIndent('  ').convert(package);
    _downloadFile(packageJson, '$slug-claude-code-package.json', mimeType: 'application/json');

    // Also download individual files for immediate use
    _downloadFile(teamConfig, '$slug-config.json', mimeType: 'application/json');
    _downloadFile(claudeMd, '$slug-CLAUDE.md');
    _downloadFile(readme, '$slug-README.md');

    _showSnack('Claude Code package downloaded');
  }

  @override
  Widget build(BuildContext context) {
    final slug = widget.workflow.name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-');

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
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_error != null)
                    Container(
                      padding: const EdgeInsets.all(8),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: AppTheme.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: AppTheme.error.withValues(alpha: 0.3)),
                      ),
                      child: Text(_error!,
                          style: const TextStyle(
                              color: AppTheme.error, fontSize: 11)),
                    ),
                  if (!_hasPromptAccess && _error == null)
                    Container(
                      padding: const EdgeInsets.all(8),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: AppTheme.gold.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: AppTheme.gold.withValues(alpha: 0.3)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.warning_amber,
                              color: AppTheme.gold, size: 16),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Some agent prompts are not accessible (not owned by you). Those will show placeholder text.',
                              style: TextStyle(
                                  color: AppTheme.gold, fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                    ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _ExportButton(
                        icon: Icons.smart_toy,
                        label: 'Claude Team Config',
                        color: const Color(0xFF8B5CF6),
                        onTap: () {
                          final content =
                              ClaudeExportService.generateTeamConfig(
                                  widget.workflow, _agents);
                          _downloadFile(content, '$slug-team-config.json',
                              mimeType: 'application/json');
                          _showSnack('Team config downloaded');
                        },
                      ),
                      _ExportButton(
                        icon: Icons.person,
                        label: 'Claude Agents (.md)',
                        color: const Color(0xFF06B6D4),
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
                      _ExportButton(
                        icon: Icons.description,
                        label: 'CLAUDE.md',
                        color: const Color(0xFFF59E0B),
                        onTap: () {
                          final content =
                              ClaudeExportService.generateClaudeMd(
                                  widget.workflow, _agents);
                          _downloadFile(content, 'CLAUDE.md');
                          _showSnack('CLAUDE.md downloaded');
                        },
                      ),
                      _ExportButton(
                        icon: Icons.rule,
                        label: 'Cursor Rules',
                        color: const Color(0xFF10B981),
                        onTap: () {
                          final content =
                              ClaudeExportService.generateCursorRules(
                                  widget.workflow, _agents);
                          _downloadFile(content, '.cursorrules');
                          _showSnack('.cursorrules downloaded');
                        },
                      ),
                      _ExportButton(
                        icon: Icons.data_object,
                        label: 'Workflow JSON',
                        color: const Color(0xFF3B82F6),
                        onTap: () {
                          _downloadFile(widget.workflowJson,
                              '$slug-workflow.json',
                              mimeType: 'application/json');
                          _showSnack('Workflow JSON downloaded');
                        },
                      ),
                      _ExportButton(
                        icon: Icons.copy_all,
                        label: 'Copy All Prompts',
                        color: const Color(0xFF6366F1),
                        onTap: () {
                          final content =
                              ClaudeExportService.generateCursorRules(
                                  widget.workflow, _agents);
                          Clipboard.setData(ClipboardData(text: content));
                          _showSnack('All prompts copied to clipboard');
                        },
                      ),
                      if (widget.lastExecution != null) ...[
                        _ExportButton(
                          icon: Icons.psychology,
                          label: 'Export Context',
                          color: const Color(0xFFEC4899),
                          onTap: () {
                            final content =
                                ClaudeExportService.generateClaudeContext(
                                    widget.lastExecution!, _agents);
                            _downloadFile(content,
                                '$slug-context.md');
                            _showSnack('Execution context downloaded');
                          },
                        ),
                        _ExportButton(
                          icon: Icons.content_copy,
                          label: 'Copy Context',
                          color: const Color(0xFFEC4899),
                          onTap: () {
                            final content =
                                ClaudeExportService.generateClaudeContext(
                                    widget.lastExecution!, _agents);
                            Clipboard.setData(ClipboardData(text: content));
                            _showSnack('Context copied to clipboard');
                          },
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(color: AppTheme.border, height: 1),
                  const SizedBox(height: 12),
                  // Claude Code CLI Runner Package
                  InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => _downloadCliPackage(slug),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                            const Color(0xFFEC4899).withValues(alpha: 0.1),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: const Color(0xFF8B5CF6).withValues(alpha: 0.3)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.terminal, size: 20, color: Color(0xFF8B5CF6)),
                          SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Run with Claude Code',
                                    style: TextStyle(
                                        color: Color(0xFF8B5CF6),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600)),
                                Text(
                                    'Download full CLI team package (config + agents + README)',
                                    style: TextStyle(
                                        color: AppTheme.textM, fontSize: 10)),
                              ],
                            ),
                          ),
                          Icon(Icons.download, size: 18, color: Color(0xFF8B5CF6)),
                        ],
                      ),
                    ),
                  ),
                ],
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

class _ExportButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ExportButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}
