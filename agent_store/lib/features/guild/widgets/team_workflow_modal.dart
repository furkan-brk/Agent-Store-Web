// lib/features/guild/widgets/team_workflow_modal.dart

import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../../../shared/models/guild_model.dart';
import '../../../features/character/character_types.dart';

// Workflow step definition per character type
// Order = logical project pipeline sequence
const _kSteps = <CharacterType, _WorkflowStep>{
  CharacterType.scholar:    _WorkflowStep('Research',  Icons.menu_book,    'Gathers info, trends & requirements'),
  CharacterType.strategist: _WorkflowStep('Plan',      Icons.flag,         'Roadmaps, priorities & architecture'),
  CharacterType.oracle:     _WorkflowStep('Analyze',   Icons.bar_chart,    'Data insights, metrics & feedback'),
  CharacterType.artisan:    _WorkflowStep('Design',    Icons.brush,        'UI/UX, visuals & prototypes'),
  CharacterType.wizard:     _WorkflowStep('Build',     Icons.code,         'Code, APIs & integrations'),
  CharacterType.guardian:   _WorkflowStep('Secure',    Icons.shield,       'Security, infra & deployment'),
  CharacterType.bard:       _WorkflowStep('Document',  Icons.edit_note,    'Content, docs & communication'),
  CharacterType.merchant:   _WorkflowStep('Grow',      Icons.trending_up,  'Marketing, outreach & business'),
};

// Ordered pipeline (logical flow of a software project)
const _kPipelineOrder = [
  CharacterType.scholar,
  CharacterType.strategist,
  CharacterType.oracle,
  CharacterType.artisan,
  CharacterType.wizard,
  CharacterType.guardian,
  CharacterType.bard,
  CharacterType.merchant,
];

class _WorkflowStep {
  final String label;
  final IconData icon;
  final String description;
  const _WorkflowStep(this.label, this.icon, this.description);
}

// ── Main Modal ────────────────────────────────────────────────────────────────

class TeamWorkflowModal extends StatelessWidget {
  final GuildModel guild;
  const TeamWorkflowModal({super.key, required this.guild});

  Set<CharacterType> get _coveredTypes =>
      guild.members
          .map((m) => m.agent?.characterType)
          .whereType<CharacterType>()
          .toSet();

  @override
  Widget build(BuildContext context) {
    final covered = _coveredTypes;
    final activePipeline = _kPipelineOrder.where((t) => covered.contains(t)).toList();
    final missing = _kPipelineOrder.where((t) => !covered.contains(t)).toList();

    return Dialog(
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.border, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primary.withValues(alpha: 0.12),
                blurRadius: 30,
                spreadRadius: 2,
              ),
            ],
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Header ───────────────────────────────────────────────
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.sync, color: AppTheme.primary, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Team Workflow',
                            style: TextStyle(
                              color: AppTheme.textH,
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${guild.name}  ·  ${guild.memberCount} agent${guild.memberCount == 1 ? '' : 's'}',
                            style: const TextStyle(color: AppTheme.textM, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    _HoverIconButton(
                      icon: Icons.close,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // ── Member Roles ─────────────────────────────────────────
                const _SectionTitle(title: 'Member Roles', icon: Icons.people_outline),
                const SizedBox(height: 10),
                if (guild.members.isEmpty)
                  const _EmptyHint(
                    icon: Icons.person_add_outlined,
                    text: 'No members yet. Add agents to your guild.',
                  )
                else
                  ...guild.members
                      .where((m) => m.agent != null)
                      .map((m) => _MemberRoleCard(member: m)),

                const SizedBox(height: 24),

                // ── Workflow Pipeline ─────────────────────────────────────
                const _SectionTitle(title: 'Active Pipeline', icon: Icons.timeline),
                const SizedBox(height: 10),
                if (activePipeline.isEmpty)
                  const _EmptyHint(
                    icon: Icons.add_circle_outline,
                    text: 'Add agents to generate a pipeline.',
                  )
                else
                  _PipelineFlow(types: activePipeline),

                const SizedBox(height: 24),

                // ── Coverage ─────────────────────────────────────────────
                const _SectionTitle(title: 'Coverage', icon: Icons.pie_chart_outline),
                const SizedBox(height: 10),
                _CoverageBar(covered: covered, missing: missing),

                const SizedBox(height: 28),

                // ── Close button ─────────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: AppTheme.textH,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Hover Icon Button ─────────────────────────────────────────────────────────

class _HoverIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onPressed;
  const _HoverIconButton({required this.icon, required this.onPressed});

  @override
  State<_HoverIconButton> createState() => _HoverIconButtonState();
}

class _HoverIconButtonState extends State<_HoverIconButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: _hovered ? AppTheme.card2 : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            widget.icon,
            color: _hovered ? AppTheme.textH : AppTheme.textM,
            size: 20,
          ),
        ),
      ),
    );
  }
}

// ── Empty Hint ────────────────────────────────────────────────────────────────

class _EmptyHint extends StatelessWidget {
  final IconData icon;
  final String text;
  const _EmptyHint({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.card.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppTheme.textM),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(color: AppTheme.textM, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

// ── Section Title ─────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String title;
  final IconData icon;
  const _SectionTitle({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 12, color: AppTheme.textM),
      const SizedBox(width: 6),
      Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: AppTheme.textM,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    ],
  );
}

// ── Member Role Card ──────────────────────────────────────────────────────────

class _MemberRoleCard extends StatefulWidget {
  final GuildMemberModel member;
  const _MemberRoleCard({required this.member});

  @override
  State<_MemberRoleCard> createState() => _MemberRoleCardState();
}

class _MemberRoleCardState extends State<_MemberRoleCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final agent = widget.member.agent!;
    final type = agent.characterType;
    final step = _kSteps[type]!;
    final color = type.primaryColor;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: _hovered ? AppTheme.card2 : AppTheme.card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: _hovered ? color.withValues(alpha: 0.4) : AppTheme.border,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(step.icon, color: color, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    agent.title,
                    style: const TextStyle(
                      color: AppTheme.textH,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${type.displayName}  ·  ${step.description}',
                    style: const TextStyle(color: AppTheme.textM, fontSize: 10),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: color.withValues(alpha: 0.3)),
              ),
              child: Text(
                step.label,
                style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Pipeline Flow ─────────────────────────────────────────────────────────────

class _PipelineFlow extends StatelessWidget {
  final List<CharacterType> types;
  const _PipelineFlow({required this.types});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: types.asMap().entries.map((e) {
          final type = e.value;
          final isLast = e.key == types.length - 1;
          final step = _kSteps[type]!;
          final color = type.primaryColor;

          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      border: Border.all(color: color.withValues(alpha: 0.5), width: 1.5),
                    ),
                    child: Icon(step.icon, color: color, size: 22),
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    width: 60,
                    child: Text(
                      step.label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: color,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              if (!isLast) ...[
                const SizedBox(width: 6),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 10,
                  color: AppTheme.textM.withValues(alpha: 0.6),
                ),
                const SizedBox(width: 6),
              ],
            ],
          );
        }).toList(),
      ),
    );
  }
}

// ── Coverage Bar ──────────────────────────────────────────────────────────────

class _CoverageBar extends StatelessWidget {
  final Set<CharacterType> covered;
  final List<CharacterType> missing;
  const _CoverageBar({required this.covered, required this.missing});

  @override
  Widget build(BuildContext context) {
    final pct = covered.isEmpty
        ? 0.0
        : covered.length / _kPipelineOrder.length;

    final barColor = pct >= 0.75
        ? AppTheme.olive
        : pct >= 0.5
            ? AppTheme.gold
            : AppTheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Progress bar
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: pct,
                  minHeight: 6,
                  backgroundColor: AppTheme.border,
                  color: barColor,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '${covered.length}/${_kPipelineOrder.length} phases',
              style: const TextStyle(color: AppTheme.textB, fontSize: 11),
            ),
          ],
        ),
        if (missing.isNotEmpty) ...[
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.warning_amber_rounded, size: 13, color: AppTheme.gold),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Gaps: ${missing.map((t) => _kSteps[t]!.label).join(', ')}',
                  style: const TextStyle(color: AppTheme.textB, fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 19),
            child: Text(
              'Add ${missing.map((t) => t.displayName).join(' / ')} agents to complete the pipeline.',
              style: const TextStyle(color: AppTheme.textM, fontSize: 10),
            ),
          ),
        ] else if (covered.isNotEmpty) ...[
          const SizedBox(height: 8),
          const Row(
            children: [
              Icon(Icons.check_circle, size: 14, color: AppTheme.olive),
              SizedBox(width: 6),
              Text(
                'Full pipeline covered -- your team handles every phase!',
                style: TextStyle(color: AppTheme.olive, fontSize: 11, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
