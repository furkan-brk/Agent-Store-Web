// lib/features/guild_master/widgets/suggest_panel.dart
//
// v3.8 explainable Guild Master suggest panel.
//
// Pre-v3.8 the suggest result was a single `reasoning` paragraph and a
// flat list of agent cards. Decision-makers couldn't see *why* a type
// was picked, what concrete plan it implied, or how confident the AI
// was about each pick. This panel surfaces the structured shape
// returned by /guild-master/suggest:
//
//   - Goal: one-sentence success definition
//   - Plan: numbered ordered steps
//   - Owners: type → role → responsibility cards
//   - Risks / Success Criteria: bullet lists
//   - Per-agent confidence + reason chips
//
// Pure presentational widget — no controllers, no state. The caller
// passes a parsed Map<String, dynamic> matching the GuildSuggestion
// JSON shape and the panel renders whatever subset is non-empty,
// gracefully degrading when the AI provider returns the legacy
// reasoning-only payload.

import 'package:flutter/material.dart';

import '../../../app/theme.dart';

class SuggestPanel extends StatelessWidget {
  /// Raw suggestion payload from /guild-master/suggest. Keys we look at:
  ///   suggested_name, goal, reasoning, plan, owners, risks,
  ///   success_criteria, confidence_per_type, matching_agents.
  final Map<String, dynamic> suggestion;

  /// Optional callbacks for the action-bridge buttons. When null, the
  /// corresponding button is hidden — useful for read-only history views
  /// where bridging from a stale session would be confusing.
  final VoidCallback? onSaveAsMission;
  final VoidCallback? onOpenInLegend;
  final bool bridgeBusy;

  const SuggestPanel({
    super.key,
    required this.suggestion,
    this.onSaveAsMission,
    this.onOpenInLegend,
    this.bridgeBusy = false,
  });

  @override
  Widget build(BuildContext context) {
    final goal = (suggestion['goal'] as String?)?.trim() ?? '';
    final reasoning = (suggestion['reasoning'] as String?)?.trim() ?? '';
    final teamName = (suggestion['suggested_name'] as String?)?.trim() ?? '';
    final plan = (suggestion['plan'] as List<dynamic>?) ?? const [];
    final owners = (suggestion['owners'] as List<dynamic>?) ?? const [];
    final risks = (suggestion['risks'] as List<dynamic>?) ?? const [];
    final criteria = (suggestion['success_criteria'] as List<dynamic>?) ?? const [];
    final confByType = (suggestion['confidence_per_type'] as Map<String, dynamic>?) ?? const {};
    final agents = (suggestion['matching_agents'] as List<dynamic>?) ?? const [];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _Header(teamName: teamName),
          if (goal.isNotEmpty || reasoning.isNotEmpty) ...[
            const SizedBox(height: 12),
            _GoalSection(goal: goal.isNotEmpty ? goal : reasoning),
          ],
          if (plan.isNotEmpty) ...[
            const SizedBox(height: 12),
            _PlanSection(plan: plan),
          ],
          if (owners.isNotEmpty) ...[
            const SizedBox(height: 12),
            _OwnersSection(owners: owners),
          ],
          if (risks.isNotEmpty || criteria.isNotEmpty) ...[
            const SizedBox(height: 12),
            _RisksAndCriteria(risks: risks, criteria: criteria),
          ],
          if (confByType.isNotEmpty) ...[
            const SizedBox(height: 12),
            _ConfidenceSection(confByType: confByType),
          ],
          if (agents.isNotEmpty) ...[
            const SizedBox(height: 12),
            _AgentsSection(agents: agents),
          ],
          if (onSaveAsMission != null || onOpenInLegend != null) ...[
            const SizedBox(height: 16),
            _BridgeButtons(
              onSaveAsMission: onSaveAsMission,
              onOpenInLegend: onOpenInLegend,
              busy: bridgeBusy,
            ),
          ],
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String teamName;
  const _Header({required this.teamName});

  @override
  Widget build(BuildContext context) {
    final title = teamName.isNotEmpty ? teamName : 'Suggested team';
    return Row(
      children: [
        const Icon(Icons.workspace_premium_outlined, color: AppTheme.gold, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: AppTheme.textH,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SectionHeader({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          children: [
            Icon(icon, size: 13, color: AppTheme.gold),
            const SizedBox(width: 6),
            Text(
              label.toUpperCase(),
              style: const TextStyle(
                color: AppTheme.textM,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
              ),
            ),
          ],
        ),
      );
}

class _GoalSection extends StatelessWidget {
  final String goal;
  const _GoalSection({required this.goal});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SectionHeader(icon: Icons.flag_outlined, label: 'Goal'),
          Text(
            goal,
            style: const TextStyle(color: AppTheme.textB, fontSize: 13, height: 1.5),
          ),
        ],
      );
}

class _PlanSection extends StatelessWidget {
  final List<dynamic> plan;
  const _PlanSection({required this.plan});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionHeader(icon: Icons.checklist_rounded, label: 'Plan'),
        for (var i = 0; i < plan.length; i++) _planRow(plan[i] as Map<String, dynamic>, i),
      ],
    );
  }

  Widget _planRow(Map<String, dynamic> step, int index) {
    final stepNum = (step['step'] as num?)?.toInt() ?? index + 1;
    final title = (step['title'] as String?)?.trim() ?? '';
    final desc = (step['description'] as String?)?.trim() ?? '';
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            margin: const EdgeInsets.only(top: 2),
            decoration: BoxDecoration(
              color: AppTheme.gold.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: AppTheme.gold.withValues(alpha: 0.5)),
            ),
            child: Center(
              child: Text(
                '$stepNum',
                style: const TextStyle(
                  color: AppTheme.gold,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppTheme.textH,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (desc.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    desc,
                    style: const TextStyle(color: AppTheme.textM, fontSize: 12, height: 1.4),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OwnersSection extends StatelessWidget {
  final List<dynamic> owners;
  const _OwnersSection({required this.owners});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionHeader(icon: Icons.groups_2_outlined, label: 'Owners'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final o in owners) _ownerCard(o as Map<String, dynamic>),
          ],
        ),
      ],
    );
  }

  Widget _ownerCard(Map<String, dynamic> o) {
    final type = (o['type'] as String?)?.trim() ?? '';
    final role = (o['role'] as String?)?.trim() ?? '';
    final resp = (o['responsibility'] as String?)?.trim() ?? '';
    return Container(
      width: 220,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.card2,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.gold.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  type,
                  style: const TextStyle(
                    color: AppTheme.gold,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  role,
                  style: const TextStyle(
                    color: AppTheme.textH,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (resp.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              resp,
              style: const TextStyle(color: AppTheme.textB, fontSize: 11, height: 1.4),
            ),
          ],
        ],
      ),
    );
  }
}

class _RisksAndCriteria extends StatelessWidget {
  final List<dynamic> risks;
  final List<dynamic> criteria;
  const _RisksAndCriteria({required this.risks, required this.criteria});

  @override
  Widget build(BuildContext context) {
    final risksColumn = _bulletColumn(
      icon: Icons.warning_amber_rounded,
      label: 'Risks',
      bullets: risks,
      bulletColor: AppTheme.error,
    );
    final criteriaColumn = _bulletColumn(
      icon: Icons.task_alt_rounded,
      label: 'Success criteria',
      bullets: criteria,
      bulletColor: AppTheme.olive,
    );
    if (risks.isEmpty) return criteriaColumn;
    if (criteria.isEmpty) return risksColumn;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: risksColumn),
        const SizedBox(width: 12),
        Expanded(child: criteriaColumn),
      ],
    );
  }

  Widget _bulletColumn({
    required IconData icon,
    required String label,
    required List<dynamic> bullets,
    required Color bulletColor,
  }) {
    if (bullets.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(icon: icon, label: label),
        for (final b in bullets)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.only(top: 6, right: 8),
                  decoration: BoxDecoration(
                    color: bulletColor,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                Expanded(
                  child: Text(
                    b.toString(),
                    style: const TextStyle(color: AppTheme.textB, fontSize: 12, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _ConfidenceSection extends StatelessWidget {
  final Map<String, dynamic> confByType;
  const _ConfidenceSection({required this.confByType});

  @override
  Widget build(BuildContext context) {
    final entries = confByType.entries.toList()
      ..sort((a, b) => ((b.value as num?)?.toDouble() ?? 0)
          .compareTo((a.value as num?)?.toDouble() ?? 0));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionHeader(icon: Icons.insights_rounded, label: 'Confidence by type'),
        for (final e in entries) _row(e.key, ((e.value as num?)?.toDouble() ?? 0).clamp(0.0, 1.0)),
      ],
    );
  }

  Widget _row(String type, double conf) {
    final pct = (conf * 100).round();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              type,
              style: const TextStyle(
                color: AppTheme.textB,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: conf,
                minHeight: 6,
                backgroundColor: AppTheme.border,
                valueColor: AlwaysStoppedAnimation<Color>(
                  conf >= 0.8 ? AppTheme.olive : (conf >= 0.5 ? AppTheme.gold : AppTheme.warning),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 36,
            child: Text(
              '$pct%',
              textAlign: TextAlign.right,
              style: const TextStyle(color: AppTheme.textM, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}

class _AgentsSection extends StatelessWidget {
  final List<dynamic> agents;
  const _AgentsSection({required this.agents});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionHeader(icon: Icons.person_search_rounded, label: 'Matching agents'),
        for (final a in agents) _agentRow(a as Map<String, dynamic>),
      ],
    );
  }

  Widget _agentRow(Map<String, dynamic> a) {
    final title = (a['title'] as String?)?.trim() ?? 'Untitled';
    final type = (a['character_type'] as String?)?.trim() ?? '';
    final reason = (a['reason'] as String?)?.trim() ?? '';
    final contribution = (a['contribution'] as String?)?.trim() ?? '';
    final conf = ((a['confidence'] as num?)?.toDouble() ?? 0).clamp(0.0, 1.0);
    final confPct = (conf * 100).round();

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.card2,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: AppTheme.textH,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (conf > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: (conf >= 0.7 ? AppTheme.olive : AppTheme.gold).withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '$confPct%',
                    style: TextStyle(
                      color: conf >= 0.7 ? AppTheme.olive : AppTheme.gold,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              if (type.isNotEmpty) _miniChip(type, AppTheme.gold),
              if (contribution.isNotEmpty) _miniChip(contribution, AppTheme.info),
            ],
          ),
          if (reason.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              reason,
              style: const TextStyle(color: AppTheme.textM, fontSize: 11, height: 1.4),
            ),
          ],
        ],
      ),
    );
  }

  Widget _miniChip(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
      );
}

class _BridgeButtons extends StatelessWidget {
  final VoidCallback? onSaveAsMission;
  final VoidCallback? onOpenInLegend;
  final bool busy;
  const _BridgeButtons({
    required this.onSaveAsMission,
    required this.onOpenInLegend,
    required this.busy,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (onSaveAsMission != null)
          Expanded(
            child: OutlinedButton.icon(
              onPressed: busy ? null : onSaveAsMission,
              icon: const Icon(Icons.bookmark_add_outlined, size: 16),
              label: const Text('Save as Mission'),
            ),
          ),
        if (onSaveAsMission != null && onOpenInLegend != null) const SizedBox(width: 8),
        if (onOpenInLegend != null)
          Expanded(
            child: ElevatedButton.icon(
              onPressed: busy ? null : onOpenInLegend,
              icon: const Icon(Icons.account_tree_outlined, size: 16),
              label: const Text('Open in Legend'),
            ),
          ),
      ],
    );
  }
}
