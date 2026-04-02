// lib/features/legend/data/legend_templates.dart

import '../models/workflow_models.dart';

class WorkflowTemplate {
  final String id;
  final String name;
  final String description;
  final String icon;
  final int nodeCount;
  final LegendWorkflow Function() build;

  const WorkflowTemplate({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.nodeCount,
    required this.build,
  });
}

/// Pre-built workflow templates. Nodes use placeholder IDs with the tpl_ prefix.
/// When loaded, the caller should assign a real workflow ID.
class LegendTemplates {
  static List<WorkflowTemplate> all() => [
        WorkflowTemplate(
          id: 'blank',
          name: 'Blank Canvas',
          description: 'Start from scratch with just a START and END node.',
          icon: '⬜',
          nodeCount: 2,
          build: _blank,
        ),
        WorkflowTemplate(
          id: 'pipeline',
          name: 'Multi-Agent Pipeline',
          description:
              'A sequential chain of three agents passing context between each other.',
          icon: '📦',
          nodeCount: 5,
          build: _pipeline,
        ),
        WorkflowTemplate(
          id: 'research',
          name: 'Research + Summarize',
          description:
              'One agent researches a topic, another condenses it into a clear summary.',
          icon: '🔍',
          nodeCount: 4,
          build: _research,
        ),
        WorkflowTemplate(
          id: 'codereview',
          name: 'Code Review Chain',
          description:
              'Three-stage code review: logic check, security audit, documentation.',
          icon: '🛠️',
          nodeCount: 5,
          build: _codeReview,
        ),
        WorkflowTemplate(
          id: 'mission',
          name: 'Mission-Led Workflow',
          description:
              'A mission defines the task, then an agent executes it.',
          icon: '🎯',
          nodeCount: 3,
          build: _missionLed,
        ),
        WorkflowTemplate(
          id: 'guild',
          name: 'Guild Collaboration',
          description:
              'An agent prepares context, then a full guild handles parallel execution.',
          icon: '⚔️',
          nodeCount: 4,
          build: _guildCollab,
        ),
      ];

  // ── Template builders ───────────────────────────────────────────────────────

  static LegendWorkflow _blank() {
    const baseX = 160.0;
    const baseY = 200.0;
    const gap = 280.0;
    return LegendWorkflow(
      id: 'tpl_blank',
      name: 'Blank Canvas',
      nodes: [
        WorkflowNode(
          id: 'tpl_blank_start',
          type: WorkflowNodeType.start,
          label: 'START',
          x: baseX,
          y: baseY,
        ),
        WorkflowNode(
          id: 'tpl_blank_end',
          type: WorkflowNodeType.end,
          label: 'END',
          x: baseX + gap,
          y: baseY,
        ),
      ],
      edges: [
        WorkflowEdge(
          id: 'tpl_blank_start_end',
          fromId: 'tpl_blank_start',
          toId: 'tpl_blank_end',
        ),
      ],
      updatedAt: DateTime.now(),
    );
  }

  static LegendWorkflow _pipeline() {
    const baseX = 100.0;
    const baseY = 180.0;
    const gap = 260.0;
    return LegendWorkflow(
      id: 'tpl_pipeline',
      name: 'Multi-Agent Pipeline',
      nodes: [
        WorkflowNode(id: 'tpl_pp_start', type: WorkflowNodeType.start, label: 'START', x: baseX, y: baseY),
        WorkflowNode(id: 'tpl_pp_a1', type: WorkflowNodeType.agent, label: 'Agent 1', x: baseX + gap, y: baseY),
        WorkflowNode(id: 'tpl_pp_a2', type: WorkflowNodeType.agent, label: 'Agent 2', x: baseX + gap * 2, y: baseY),
        WorkflowNode(id: 'tpl_pp_a3', type: WorkflowNodeType.agent, label: 'Agent 3', x: baseX + gap * 3, y: baseY),
        WorkflowNode(id: 'tpl_pp_end', type: WorkflowNodeType.end, label: 'END', x: baseX + gap * 4, y: baseY),
      ],
      edges: [
        WorkflowEdge(id: 'tpl_pp_s_a1', fromId: 'tpl_pp_start', toId: 'tpl_pp_a1'),
        WorkflowEdge(id: 'tpl_pp_a1_a2', fromId: 'tpl_pp_a1', toId: 'tpl_pp_a2'),
        WorkflowEdge(id: 'tpl_pp_a2_a3', fromId: 'tpl_pp_a2', toId: 'tpl_pp_a3'),
        WorkflowEdge(id: 'tpl_pp_a3_e', fromId: 'tpl_pp_a3', toId: 'tpl_pp_end'),
      ],
      updatedAt: DateTime.now(),
    );
  }

  static LegendWorkflow _research() {
    const baseX = 120.0;
    const baseY = 180.0;
    const gap = 280.0;
    return LegendWorkflow(
      id: 'tpl_research',
      name: 'Research + Summarize',
      nodes: [
        WorkflowNode(id: 'tpl_rs_start', type: WorkflowNodeType.start, label: 'START', x: baseX, y: baseY),
        WorkflowNode(id: 'tpl_rs_research', type: WorkflowNodeType.agent, label: 'Researcher', x: baseX + gap, y: baseY),
        WorkflowNode(id: 'tpl_rs_summarize', type: WorkflowNodeType.agent, label: 'Summarizer', x: baseX + gap * 2, y: baseY),
        WorkflowNode(id: 'tpl_rs_end', type: WorkflowNodeType.end, label: 'END', x: baseX + gap * 3, y: baseY),
      ],
      edges: [
        WorkflowEdge(id: 'tpl_rs_s_r', fromId: 'tpl_rs_start', toId: 'tpl_rs_research'),
        WorkflowEdge(id: 'tpl_rs_r_s', fromId: 'tpl_rs_research', toId: 'tpl_rs_summarize'),
        WorkflowEdge(id: 'tpl_rs_s_e', fromId: 'tpl_rs_summarize', toId: 'tpl_rs_end'),
      ],
      updatedAt: DateTime.now(),
    );
  }

  static LegendWorkflow _codeReview() {
    const baseX = 80.0;
    const baseY = 180.0;
    const gap = 240.0;
    return LegendWorkflow(
      id: 'tpl_codereview',
      name: 'Code Review Chain',
      nodes: [
        WorkflowNode(id: 'tpl_cr_start', type: WorkflowNodeType.start, label: 'START', x: baseX, y: baseY),
        WorkflowNode(id: 'tpl_cr_logic', type: WorkflowNodeType.agent, label: 'Logic Review', x: baseX + gap, y: baseY),
        WorkflowNode(id: 'tpl_cr_security', type: WorkflowNodeType.agent, label: 'Security Audit', x: baseX + gap * 2, y: baseY),
        WorkflowNode(id: 'tpl_cr_docs', type: WorkflowNodeType.agent, label: 'Doc Writer', x: baseX + gap * 3, y: baseY),
        WorkflowNode(id: 'tpl_cr_end', type: WorkflowNodeType.end, label: 'END', x: baseX + gap * 4, y: baseY),
      ],
      edges: [
        WorkflowEdge(id: 'tpl_cr_s_l', fromId: 'tpl_cr_start', toId: 'tpl_cr_logic'),
        WorkflowEdge(id: 'tpl_cr_l_s', fromId: 'tpl_cr_logic', toId: 'tpl_cr_security'),
        WorkflowEdge(id: 'tpl_cr_s_d', fromId: 'tpl_cr_security', toId: 'tpl_cr_docs'),
        WorkflowEdge(id: 'tpl_cr_d_e', fromId: 'tpl_cr_docs', toId: 'tpl_cr_end'),
      ],
      updatedAt: DateTime.now(),
    );
  }

  static LegendWorkflow _missionLed() {
    const baseX = 140.0;
    const baseY = 180.0;
    const gap = 280.0;
    return LegendWorkflow(
      id: 'tpl_mission',
      name: 'Mission-Led Workflow',
      nodes: [
        WorkflowNode(id: 'tpl_ml_start', type: WorkflowNodeType.start, label: 'START', x: baseX, y: baseY),
        WorkflowNode(id: 'tpl_ml_mission', type: WorkflowNodeType.mission, label: 'Mission', x: baseX + gap, y: baseY),
        WorkflowNode(id: 'tpl_ml_agent', type: WorkflowNodeType.agent, label: 'Agent', x: baseX + gap * 2, y: baseY),
        WorkflowNode(id: 'tpl_ml_end', type: WorkflowNodeType.end, label: 'END', x: baseX + gap * 3, y: baseY),
      ],
      edges: [
        WorkflowEdge(id: 'tpl_ml_s_m', fromId: 'tpl_ml_start', toId: 'tpl_ml_mission'),
        WorkflowEdge(id: 'tpl_ml_m_a', fromId: 'tpl_ml_mission', toId: 'tpl_ml_agent'),
        WorkflowEdge(id: 'tpl_ml_a_e', fromId: 'tpl_ml_agent', toId: 'tpl_ml_end'),
      ],
      updatedAt: DateTime.now(),
    );
  }

  static LegendWorkflow _guildCollab() {
    const baseX = 120.0;
    const baseY = 180.0;
    const gap = 280.0;
    return LegendWorkflow(
      id: 'tpl_guild',
      name: 'Guild Collaboration',
      nodes: [
        WorkflowNode(id: 'tpl_gc_start', type: WorkflowNodeType.start, label: 'START', x: baseX, y: baseY),
        WorkflowNode(id: 'tpl_gc_prep', type: WorkflowNodeType.agent, label: 'Prep Agent', x: baseX + gap, y: baseY),
        WorkflowNode(id: 'tpl_gc_guild', type: WorkflowNodeType.guild, label: 'Guild', x: baseX + gap * 2, y: baseY),
        WorkflowNode(id: 'tpl_gc_end', type: WorkflowNodeType.end, label: 'END', x: baseX + gap * 3, y: baseY),
      ],
      edges: [
        WorkflowEdge(id: 'tpl_gc_s_p', fromId: 'tpl_gc_start', toId: 'tpl_gc_prep'),
        WorkflowEdge(id: 'tpl_gc_p_g', fromId: 'tpl_gc_prep', toId: 'tpl_gc_guild'),
        WorkflowEdge(id: 'tpl_gc_g_e', fromId: 'tpl_gc_guild', toId: 'tpl_gc_end'),
      ],
      updatedAt: DateTime.now(),
    );
  }
}
