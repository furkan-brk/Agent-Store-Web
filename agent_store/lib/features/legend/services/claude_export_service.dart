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

  // ── OpenClaw SKILL.md ─────────────────────────────────────────────────────

  /// Generates a SKILL.md string for a single agent.
  /// Mirrors Go BuildSkillMd exactly — round-trip compatible.
  static String generateOpenclawSkill(AgentModel agent) {
    final slug = _slugify(agent.title);

    // Single-line description, max 200 chars, escape YAML double-quotes
    var desc = agent.description.replaceAll('\n', ' ').trim();
    if (desc.length > 200) desc = '${desc.substring(0, 197)}...';
    desc = desc.replaceAll('"', '\\"');

    // when_to_use: prefer serviceDescription, fall back to one-liner
    final raw = (agent.serviceDescription ?? '').trim();
    final whenToUse = raw.isNotEmpty
        ? raw
        : 'Use for ${agent.category.toLowerCase()} tasks'
            ' (${agent.characterType.name}, ${agent.rarity.name}).';

    // Indent each line with 2 spaces for YAML block scalar body
    final indented =
        whenToUse.split('\n').map((l) => '  $l').join('\n');

    // Tags as YAML inline list
    final tagList = agent.tags.isEmpty
        ? '[]'
        : '[${agent.tags.map((t) => '"$t"').join(', ')}]';

    final buf = StringBuffer();
    buf.write('---\n');
    buf.write('name: $slug\n');
    buf.write('description: "$desc"\n');
    buf.write('version: 1.0.0\n');
    buf.write('when_to_use: |\n');
    buf.write('$indented\n');
    buf.write('model: opus\n');
    buf.write('metadata:\n');
    buf.write('  openclaw:\n');
    buf.write('    requires:\n');
    buf.write('      env: []\n');
    buf.write('      bins: []\n');
    buf.write('agent_store:\n');
    buf.write('  id: ${agent.id}\n');
    buf.write('  url: https://agentstore.xyz/agent/${agent.id}\n');
    buf.write('  character_type: ${agent.characterType.name}\n');
    buf.write('  subclass: ${agent.subclass.name}\n');
    buf.write('  rarity: ${agent.rarity.name}\n');
    buf.write('  category: ${agent.category}\n');
    buf.write('  tags: $tagList\n');
    buf.write('---\n');
    buf.write('\n');
    buf.write('# ${agent.title}\n');
    buf.write('\n');
    buf.write(agent.prompt);
    if (!agent.prompt.endsWith('\n')) buf.write('\n');

    return buf.toString();
  }

  /// Returns true when content looks like an OpenClaw SKILL.md.
  static bool isOpenclawSkill(String content) =>
      content.trimLeft().startsWith('---') &&
      content.contains('metadata:') &&
      content.contains('  openclaw:');

  /// Parses an OpenClaw SKILL.md string into a WorkflowNode + prompt.
  /// Detects the `agent_store:` sub-block for enriched metadata.
  static ({WorkflowNode node, String prompt})? parseOpenclawSkill(
      String content) {
    try {
      final parts = content.split('---');
      if (parts.length < 3) return null;

      final frontmatter = parts[1].trim();
      // Body: rejoin to preserve any --- inside the prompt
      final body = parts.sublist(2).join('---').trim();

      // Line-scanner: collect top-level and agent_store sub-fields
      final meta = <String, String>{};
      final agentStoreMeta = <String, String>{};
      String? currentBlock;

      for (final line in frontmatter.split('\n')) {
        if (line.startsWith('  ') && !line.startsWith('   ')) {
          // 2-space indented line — sub-field of current top-level block
          if (currentBlock == 'agent_store') {
            final ci = line.indexOf(':');
            if (ci > 0) {
              final k = line.substring(0, ci).trim();
              final v =
                  line.substring(ci + 1).trim().replaceAll('"', '');
              agentStoreMeta[k] = v;
            }
          }
          // Else skip (when_to_use body, metadata/openclaw nesting, etc.)
        } else if (!line.startsWith(' ') && line.contains(':')) {
          // Top-level key
          final ci = line.indexOf(':');
          final k = line.substring(0, ci).trim();
          final v = line.substring(ci + 1).trim().replaceAll('"', '');
          currentBlock = k;
          // Only store scalar top-level values (not block headings)
          if (k != 'agent_store' && k != 'metadata' &&
              k != 'when_to_use') {
            meta[k] = v;
          }
        }
      }

      final name = meta['name'] ?? 'imported-agent';
      final model = meta['model'] ?? 'sonnet';

      // Strip leading `# Title\n` from body if present
      var prompt = body;
      if (prompt.startsWith('# ')) {
        final nl = prompt.indexOf('\n');
        prompt = nl >= 0 ? prompt.substring(nl + 1).trim() : '';
      }

      final node = WorkflowNode(
        id: 'agent_${DateTime.now().millisecondsSinceEpoch}',
        type: WorkflowNodeType.agent,
        label: name,
        x: 300,
        y: 200,
        metadata: {
          'engine': 'claude',
          'model': model,
          'prompt': prompt,
          if (agentStoreMeta['character_type'] != null)
            'character_type': agentStoreMeta['character_type']!,
          if (agentStoreMeta['category'] != null)
            'category': agentStoreMeta['category']!,
        },
      );

      return (node: node, prompt: prompt);
    } catch (_) {
      return null;
    }
  }

  /// Generates a JSON package representing an OpenClaw workspace bundle.
  /// Structure: ~/.openclaw/workspace/skills/<slug>/SKILL.md per agent,
  /// plus team.json referencing all skill slugs.
  /// Returns combined JSON string (no zip — mirrors CLI package pattern).
  static String generateOpenclawWorkspace(
      LegendWorkflow wf, List<AgentModel> agents) {
    final workflowSlug = _slugify(wf.name);
    final agentNodes = getOrderedAgentNodes(wf.nodes, wf.edges);
    final agentMap = {for (final a in agents) a.id.toString(): a};

    final files = <String, String>{};
    final skillSlugs = <String>[];

    for (final node in agentNodes) {
      final agent = agentMap[node.refId];
      if (agent == null || agent.prompt.isEmpty) continue;
      final skillSlug = _slugify(agent.title);
      skillSlugs.add(skillSlug);
      files['~/.openclaw/workspace/skills/$skillSlug/SKILL.md'] =
          generateOpenclawSkill(agent);
    }

    final teamJson =
        const JsonEncoder.withIndent('  ').convert(<String, dynamic>{
      'name': workflowSlug,
      'description': '${wf.name} — Agent Store Legend Workflow',
      'skills': skillSlugs,
    });
    files['~/.openclaw/workspace/team.json'] = teamJson;

    return const JsonEncoder.withIndent('  ').convert(<String, dynamic>{
      'name': wf.name,
      'slug': workflowSlug,
      'format': 'openclaw-workspace',
      'files': files,
    });
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
