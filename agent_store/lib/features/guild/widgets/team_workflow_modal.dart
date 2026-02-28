import 'package:flutter/material.dart';
import '../../../shared/models/guild_model.dart';
import '../../../features/character/character_types.dart';

// Workflow step definition per character type
// Order = logical project pipeline sequence
const _kSteps = <CharacterType, _WorkflowStep>{
  CharacterType.scholar:    _WorkflowStep('Research',   '📚', 'Gathers info, trends & requirements'),
  CharacterType.strategist: _WorkflowStep('Plan',       '📋', 'Roadmaps, priorities & architecture'),
  CharacterType.oracle:     _WorkflowStep('Analyze',    '📊', 'Data insights, metrics & feedback'),
  CharacterType.artisan:    _WorkflowStep('Design',     '🎨', 'UI/UX, visuals & prototypes'),
  CharacterType.wizard:     _WorkflowStep('Build',      '⚙️', 'Code, APIs & integrations'),
  CharacterType.guardian:   _WorkflowStep('Secure',     '🛡️', 'Security, infra & deployment'),
  CharacterType.bard:       _WorkflowStep('Document',   '📝', 'Content, docs & communication'),
  CharacterType.merchant:   _WorkflowStep('Grow',       '📈', 'Marketing, outreach & business'),
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
  final String emoji;
  final String description;
  const _WorkflowStep(this.label, this.emoji, this.description);
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
            color: const Color(0xFF0F0F1E),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF1E1E35), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6366F1).withValues(alpha: 0.12),
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
                Row(children: [
                  const Text('🔄', style: TextStyle(fontSize: 20)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text(
                        'Team Workflow',
                        style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${guild.name} · ${guild.memberCount} agent${guild.memberCount == 1 ? '' : 's'}',
                        style: const TextStyle(color: Color(0xFF6B7280), fontSize: 11),
                      ),
                    ]),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Color(0xFF6B7280), size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ]),

                const SizedBox(height: 20),

                // ── Member Roles ─────────────────────────────────────────
                const _SectionTitle(title: 'Member Roles'),
                const SizedBox(height: 10),
                if (guild.members.isEmpty)
                  const Text('No members yet.',
                    style: TextStyle(color: Color(0xFF6B7280), fontSize: 12))
                else
                  ...guild.members
                      .where((m) => m.agent != null)
                      .map((m) => _MemberRoleCard(member: m)),

                const SizedBox(height: 20),

                // ── Workflow Pipeline ─────────────────────────────────────
                const _SectionTitle(title: 'Active Pipeline'),
                const SizedBox(height: 10),
                if (activePipeline.isEmpty)
                  const Text('Add agents to generate a pipeline.',
                    style: TextStyle(color: Color(0xFF6B7280), fontSize: 12))
                else
                  _PipelineFlow(types: activePipeline),

                const SizedBox(height: 20),

                // ── Coverage ─────────────────────────────────────────────
                const _SectionTitle(title: 'Coverage'),
                const SizedBox(height: 10),
                _CoverageBar(covered: covered, missing: missing),

                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
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

// ── Section Title ─────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) => Text(
    title.toUpperCase(),
    style: const TextStyle(
      color: Color(0xFF9CA3AF),
      fontSize: 10,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.2,
    ),
  );
}

// ── Member Role Card ──────────────────────────────────────────────────────────

class _MemberRoleCard extends StatelessWidget {
  final GuildMemberModel member;
  const _MemberRoleCard({required this.member});

  @override
  Widget build(BuildContext context) {
    final agent = member.agent!;
    final type = agent.characterType;
    final step = _kSteps[type]!;
    final color = type.primaryColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF13131F),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(step.emoji, style: const TextStyle(fontSize: 18)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            agent.title,
            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            '${type.displayName} → ${step.label}: ${step.description}',
            style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 10),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ])),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: color.withValues(alpha: 0.4)),
          ),
          child: Text(
            step.label,
            style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
          ),
        ),
      ]),
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

          return Row(mainAxisSize: MainAxisSize.min, children: [
            Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: color.withValues(alpha: 0.5), width: 1.5),
                ),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(step.emoji, style: const TextStyle(fontSize: 18)),
                ]),
              ),
              const SizedBox(height: 4),
              SizedBox(
                width: 60,
                child: Text(
                  step.label,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ]),
            if (!isLast) ...[
              const SizedBox(width: 4),
              const Icon(Icons.arrow_forward_ios, size: 10, color: Color(0xFF4B5563)),
              const SizedBox(width: 4),
            ],
          ]);
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

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Progress bar
      Row(children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 6,
              backgroundColor: const Color(0xFF1E1E35),
              color: pct >= 0.75
                  ? const Color(0xFF10B981)
                  : pct >= 0.5
                      ? const Color(0xFFF59E0B)
                      : const Color(0xFF6366F1),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          '${covered.length}/${_kPipelineOrder.length} phases',
          style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 11),
        ),
      ]),
      if (missing.isNotEmpty) ...[
        const SizedBox(height: 10),
        Text(
          'Gaps: ${missing.map((t) => _kSteps[t]!.label).join(', ')}',
          style: const TextStyle(color: Color(0xFF6B7280), fontSize: 11),
        ),
        const SizedBox(height: 4),
        Text(
          'Add ${missing.map((t) => t.displayName).join(' / ')} agents to complete the pipeline.',
          style: const TextStyle(color: Color(0xFF4B5563), fontSize: 10),
        ),
      ] else if (covered.isNotEmpty) ...[
        const SizedBox(height: 6),
        const Text(
          '✅ Full pipeline covered — your team handles every phase!',
          style: TextStyle(color: Color(0xFF10B981), fontSize: 11),
        ),
      ],
    ]);
  }
}
