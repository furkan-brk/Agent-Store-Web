// lib/features/legend/services/claude_export_service.dart

import 'dart:convert';
import '../../../shared/models/agent_model.dart';
import '../models/workflow_models.dart';
import '../utils/dag_utils.dart';

class ClaudeExportService {
  // ── Slugification ─────────────────────────────────────────────────────

  static String _slugify(String input) {
    final cleaned = input
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s-]'), '')
        .trim()
        .replaceAll(RegExp(r'\s+'), '-');
    final truncated =
        cleaned.length > 50 ? cleaned.substring(0, 50) : cleaned;
    return truncated.replaceAll(RegExp(r'-+$'), '');
  }

  // ── Color Mapping ─────────────────────────────────────────────────────

  static const _colorMap = {
    'wizard': 'purple',
    'strategist': 'red',
    'oracle': 'yellow',
    'guardian': 'blue',
    'artisan': 'cyan',
    'bard': 'green',
    'scholar': 'brown',
    'merchant': 'orange',
  };

  static String _mapColor(String? characterType) =>
      _colorMap[characterType?.toLowerCase()] ?? 'blue';

  // ── Team Config JSON ──────────────────────────────────────────────────

  static String generateTeamConfig(
      LegendWorkflow wf, List<AgentModel> agents) {
    final agentNodes = getOrderedAgentNodes(wf.nodes, wf.edges);
    final workflowType = detectWorkflowType(wf.nodes, wf.edges);
    final agentMap = {for (final a in agents) a.id.toString(): a};

    final agentsList = <Map<String, dynamic>>[];
    for (final node in agentNodes) {
      final agent = agentMap[node.refId];
      final slug = _slugify(agent?.title ?? node.label);
      agentsList.add({
        'name': slug,
        'role': agent?.category ?? 'general',
        'model': node.metadata?['model'] ?? 'sonnet',
        'color': _mapColor(agent?.characterType.name),
        'system_prompt': agent?.prompt ?? node.metadata?['prompt'] ?? '',
      });
    }

    final config = {
      'team_name': _slugify(wf.name),
      'description': '${wf.name} — Agent Store Legend Export',
      'model': 'claude-sonnet-4-20250514',
      'workflow': workflowType,
      'lead_agent': agentsList.isNotEmpty ? agentsList.first['name'] : '',
      'agents': agentsList,
    };

    return const JsonEncoder.withIndent('  ').convert(config);
  }

  // ── Agent .md ─────────────────────────────────────────────────────────

  static String generateAgentMd(AgentModel agent) {
    final slug = _slugify(agent.title);
    final color = _mapColor(agent.characterType.name);
    final desc = agent.description.replaceAll('"', '\\"');

    return '---\n'
        'name: $slug\n'
        'description: "$desc"\n'
        'model: opus\n'
        'color: $color\n'
        'memory: project\n'
        '---\n'
        '\n'
        '${agent.prompt}\n';
  }

  /// Generate agent .md from node metadata (for virtual/imported agents)
  static String generateAgentMdFromMetadata(WorkflowNode node) {
    final slug = _slugify(node.label);
    final prompt = node.metadata?['prompt'] as String? ?? '';
    final model = node.metadata?['model'] as String? ?? 'sonnet';

    return '---\n'
        'name: $slug\n'
        'description: "${node.label}"\n'
        'model: $model\n'
        'color: blue\n'
        'memory: project\n'
        '---\n'
        '\n'
        '$prompt\n';
  }

  // ── CLAUDE.md ─────────────────────────────────────────────────────────

  static String generateClaudeMd(
      LegendWorkflow wf, List<AgentModel> agents) {
    final agentNodes = getOrderedAgentNodes(wf.nodes, wf.edges);
    final workflowType = detectWorkflowType(wf.nodes, wf.edges);
    final agentMap = {for (final a in agents) a.id.toString(): a};
    final now = DateTime.now().toIso8601String().split('T').first;

    final buf = StringBuffer();
    buf.writeln('# ${wf.name}');
    buf.writeln('> Exported from Agent Store Legend on $now');
    buf.writeln();
    buf.writeln('## Team Structure');
    buf.writeln('| Agent | Role | Order |');
    buf.writeln('|---|---|---|');

    for (var i = 0; i < agentNodes.length; i++) {
      final node = agentNodes[i];
      final agent = agentMap[node.refId];
      buf.writeln(
          '| ${agent?.title ?? node.label} | ${agent?.category ?? 'general'} | ${i + 1} |');
    }

    buf.writeln();
    buf.writeln('## Workflow');
    buf.writeln('$workflowType workflow with ${agentNodes.length} agents.');
    buf.writeln();
    buf.writeln('## Agent Prompts');

    for (final node in agentNodes) {
      final agent = agentMap[node.refId];
      final title = agent?.title ?? node.label;
      final prompt = agent?.prompt ??
          node.metadata?['prompt'] ??
          '[Prompt not available]';
      buf.writeln();
      buf.writeln('### $title');
      buf.writeln(prompt);
    }

    return buf.toString();
  }

  // ── Cursor Rules ──────────────────────────────────────────────────────

  static String generateCursorRules(
      LegendWorkflow wf, List<AgentModel> agents) {
    final agentNodes = getOrderedAgentNodes(wf.nodes, wf.edges);
    final agentMap = {for (final a in agents) a.id.toString(): a};

    final buf = StringBuffer();
    buf.writeln('# ${wf.name} — Agent Rules');
    buf.writeln();

    for (var i = 0; i < agentNodes.length; i++) {
      final node = agentNodes[i];
      final agent = agentMap[node.refId];
      final title = agent?.title ?? node.label;
      final prompt =
          agent?.prompt ?? node.metadata?['prompt'] ?? '';
      if (i > 0) buf.writeln('\n---\n');
      buf.writeln('## ${i + 1}. $title');
      buf.writeln(prompt);
    }

    return buf.toString();
  }

  // ── Execution Context ─────────────────────────────────────────────────

  static String generateClaudeContext(
      WorkflowExecution execution, List<AgentModel> agents) {
    final agentMap = {for (final a in agents) a.id.toString(): a};
    final totalMs = execution.finishedAt != null
        ? execution.finishedAt!.difference(execution.startedAt).inMilliseconds
        : 0;

    final buf = StringBuffer();
    buf.writeln(
        '# Workflow Execution Context: ${execution.workflowName}');
    buf.writeln(
        '> Executed: ${execution.startedAt.toIso8601String().split('T').first} | Nodes: ${execution.nodeResults.length} | Duration: ${totalMs}ms');
    buf.writeln();
    buf.writeln('## Execution Chain');

    for (var i = 0; i < execution.nodeResults.length; i++) {
      final result = execution.nodeResults[i];
      if (result.nodeType == 'start' || result.nodeType == 'end') continue;

      final agent = result.agentId != null
          ? agentMap[result.agentId.toString()]
          : null;
      final charType = agent?.characterType.name ?? result.nodeType;

      buf.writeln();
      buf.writeln('### Step ${i + 1}: ${result.nodeLabel} ($charType)');
      if (agent?.prompt != null) {
        final prompt = agent!.prompt;
        final summary =
            prompt.length > 200 ? '${prompt.substring(0, 200)}...' : prompt;
        buf.writeln('**System Prompt:** $summary');
      }
      buf.writeln('**Input:** ${result.input}');
      buf.writeln('**Output:**');
      buf.writeln(result.output);
    }

    buf.writeln();
    buf.writeln('## Final Output');
    buf.writeln(execution.finalOutput);
    buf.writeln();
    buf.writeln('## Summary');
    buf.writeln('- Total nodes executed: ${execution.completedNodes}');
    buf.writeln('- Credits used: ${execution.creditsUsed}');
    buf.writeln('- Execution time: ${totalMs}ms');

    return buf.toString();
  }

  // ── Parsers ───────────────────────────────────────────────────────────

  /// Parse Claude team config.json -> LegendWorkflow
  static LegendWorkflow? parseTeamConfig(String jsonContent) {
    try {
      final data = jsonDecode(jsonContent) as Map<String, dynamic>;
      final agentsData = data['agents'] as List<dynamic>? ?? [];
      final workflowType = data['workflow'] as String? ?? 'sequential';
      final teamName = data['team_name'] as String? ?? 'Imported Workflow';

      final nodes = <WorkflowNode>[];
      final edges = <WorkflowEdge>[];

      // START node
      const startId = 'start_0';
      nodes.add(WorkflowNode(
        id: startId,
        type: WorkflowNodeType.start,
        label: 'START',
        x: 50,
        y: 200,
      ));

      // Agent nodes
      String? prevId = startId;
      for (var i = 0; i < agentsData.length; i++) {
        final agentData = agentsData[i] as Map<String, dynamic>;
        final nodeId = 'agent_${i + 1}';
        nodes.add(WorkflowNode(
          id: nodeId,
          type: WorkflowNodeType.agent,
          label: agentData['name'] as String? ?? 'Agent ${i + 1}',
          x: 50.0 + (i + 1) * 250.0,
          y: 200,
          metadata: {
            'engine': 'claude',
            'model': agentData['model'] as String? ?? 'sonnet',
            'prompt': agentData['system_prompt'] as String? ?? '',
          },
        ));

        if (workflowType == 'parallel') {
          edges.add(WorkflowEdge(
              id: 'e_start_$nodeId', fromId: startId, toId: nodeId));
        } else if (prevId != null) {
          edges.add(WorkflowEdge(
              id: 'e_${prevId}_$nodeId', fromId: prevId, toId: nodeId));
        }
        prevId = nodeId;
      }

      // END node
      const endId = 'end_0';
      nodes.add(WorkflowNode(
        id: endId,
        type: WorkflowNodeType.end,
        label: 'END',
        x: 50.0 + (agentsData.length + 1) * 250.0,
        y: 200,
      ));

      if (workflowType == 'parallel') {
        for (var i = 0; i < agentsData.length; i++) {
          edges.add(WorkflowEdge(
              id: 'e_agent_${i + 1}_end',
              fromId: 'agent_${i + 1}',
              toId: endId));
        }
      } else if (prevId != null) {
        edges.add(WorkflowEdge(
            id: 'e_${prevId}_end', fromId: prevId, toId: endId));
      }

      return LegendWorkflow(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: teamName,
        nodes: nodes,
        edges: edges,
        updatedAt: DateTime.now(),
      );
    } catch (e) {
      return null;
    }
  }

  /// Parse Claude agent .md -> WorkflowNode + prompt
  static ({WorkflowNode node, String prompt})? parseAgentMd(String content) {
    try {
      final parts = content.split('---');
      if (parts.length < 3) return null;

      final frontmatter = parts[1].trim();
      final body = parts.sublist(2).join('---').trim();

      // Parse YAML-like frontmatter
      final meta = <String, String>{};
      for (final line in frontmatter.split('\n')) {
        final colonIdx = line.indexOf(':');
        if (colonIdx > 0) {
          final key = line.substring(0, colonIdx).trim();
          final value =
              line.substring(colonIdx + 1).trim().replaceAll('"', '');
          meta[key] = value;
        }
      }

      final name = meta['name'] ?? 'imported-agent';
      final model = meta['model'] ?? 'sonnet';
      final color = meta['color'] ?? 'blue';

      final node = WorkflowNode(
        id: 'agent_${DateTime.now().millisecondsSinceEpoch}',
        type: WorkflowNodeType.agent,
        label: name,
        x: 300,
        y: 200,
        metadata: {
          'engine': 'claude',
          'model': model,
          'prompt': body,
          'color': color,
        },
      );

      return (node: node, prompt: body);
    } catch (e) {
      return null;
    }
  }

  /// Parse execution context markdown -> LegendWorkflow
  static LegendWorkflow? parseClaudeContext(String markdown) {
    try {
      final stepRegex = RegExp(r'### Step \d+: (.+?) \((.+?)\)');
      final matches = stepRegex.allMatches(markdown);
      if (matches.isEmpty) return null;

      final nodes = <WorkflowNode>[];
      final edges = <WorkflowEdge>[];

      const startId = 'start_0';
      nodes.add(WorkflowNode(
        id: startId,
        type: WorkflowNodeType.start,
        label: 'START',
        x: 50,
        y: 200,
      ));

      String prevId = startId;
      var i = 0;
      for (final match in matches) {
        final agentName = match.group(1) ?? 'Agent';
        final nodeId = 'agent_${i + 1}';
        nodes.add(WorkflowNode(
          id: nodeId,
          type: WorkflowNodeType.agent,
          label: agentName,
          x: 50.0 + (i + 1) * 250.0,
          y: 200,
        ));
        edges.add(WorkflowEdge(
            id: 'e_${prevId}_$nodeId', fromId: prevId, toId: nodeId));
        prevId = nodeId;
        i++;
      }

      const endId = 'end_0';
      nodes.add(WorkflowNode(
        id: endId,
        type: WorkflowNodeType.end,
        label: 'END',
        x: 50.0 + (i + 1) * 250.0,
        y: 200,
      ));
      edges.add(WorkflowEdge(
          id: 'e_${prevId}_end', fromId: prevId, toId: endId));

      final nameMatch =
          RegExp(r'# Workflow Execution Context: (.+)').firstMatch(markdown);
      final name = nameMatch?.group(1) ?? 'Imported Context';

      return LegendWorkflow(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        nodes: nodes,
        edges: edges,
        updatedAt: DateTime.now(),
      );
    } catch (e) {
      return null;
    }
  }
}
