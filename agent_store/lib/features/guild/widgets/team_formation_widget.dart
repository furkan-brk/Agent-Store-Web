// lib/features/guild/widgets/team_formation_widget.dart

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../../../features/character/character_types.dart';
import '../../../shared/models/guild_model.dart';
import '../../../shared/widgets/pixel_character_widget.dart';

/// Renders 2-4 guild members in their formation layout with animated connection lines.
class TeamFormationWidget extends StatefulWidget {
  final List<GuildMemberModel> members;
  final bool showRoles;

  const TeamFormationWidget({
    super.key,
    required this.members,
    this.showRoles = true,
  });

  @override
  State<TeamFormationWidget> createState() => _TeamFormationWidgetState();
}

class _TeamFormationWidgetState extends State<TeamFormationWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 2));
    _anim = Tween<double>(begin: 0, end: 1).animate(_ctrl);
    _ctrl.repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.members.length.clamp(0, 4);

    if (n == 0) {
      // Empty state
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.group_add_outlined,
              size: 40,
              color: AppTheme.textM.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 12),
            const Text(
              'No team members yet',
              style: TextStyle(color: AppTheme.textB, fontSize: 13),
            ),
            const SizedBox(height: 4),
            const Text(
              'Add agents to form your team',
              style: TextStyle(color: AppTheme.textM, fontSize: 11),
            ),
          ],
        ),
      );
    }

    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => CustomPaint(
        painter: _ConnectionPainter(
          memberCount: n,
          animValue: _anim.value,
          lineColor: _lineColor(),
        ),
        child: _buildFormation(n),
      ),
    );
  }

  Color _lineColor() {
    if (widget.members.isEmpty) return AppTheme.border;
    final type = widget.members.first.agent?.characterType;
    return type?.accentColor ?? AppTheme.primary;
  }

  Widget _buildFormation(int n) {
    const cardSize = 80.0;
    const gap = 32.0;

    switch (n) {
      case 2:
        return SizedBox(
          height: cardSize + 40,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _MemberCard(member: widget.members[0], size: cardSize, showRole: widget.showRoles),
              const SizedBox(width: gap * 2),
              _MemberCard(member: widget.members[1], size: cardSize, showRole: widget.showRoles),
            ],
          ),
        );

      case 3:
        return SizedBox(
          height: cardSize * 2 + gap + 40,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned(
                top: 0,
                child: _MemberCard(member: widget.members[0], size: cardSize, showRole: widget.showRoles),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                child: _MemberCard(member: widget.members[1], size: cardSize, showRole: widget.showRoles),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: _MemberCard(member: widget.members[2], size: cardSize, showRole: widget.showRoles),
              ),
            ],
          ),
        );

      case 4:
        return SizedBox(
          height: cardSize * 2 + gap + 40,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _MemberCard(member: widget.members[0], size: cardSize, showRole: widget.showRoles),
                  const SizedBox(width: gap),
                  _MemberCard(member: widget.members[1], size: cardSize, showRole: widget.showRoles),
                ],
              ),
              const SizedBox(height: gap),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _MemberCard(member: widget.members[2], size: cardSize, showRole: widget.showRoles),
                  const SizedBox(width: gap),
                  _MemberCard(member: widget.members[3], size: cardSize, showRole: widget.showRoles),
                ],
              ),
            ],
          ),
        );

      default: // 1 member
        return _MemberCard(member: widget.members[0], size: cardSize, showRole: widget.showRoles);
    }
  }
}

class _MemberCard extends StatefulWidget {
  final GuildMemberModel member;
  final double size;
  final bool showRole;

  const _MemberCard({required this.member, required this.size, required this.showRole});

  @override
  State<_MemberCard> createState() => _MemberCardState();
}

class _MemberCardState extends State<_MemberCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final agent = widget.member.agent;
    if (agent == null) return const SizedBox.shrink();

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        transform: _hovered
            ? Matrix4.translationValues(0.0, -2.0, 0.0)
            : Matrix4.identity(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PixelCharacterWidget(
              characterType: agent.characterType,
              rarity: agent.rarity,
              subclass: agent.subclass,
              size: widget.size,
              agentId: agent.id,
              generatedImage: agent.generatedImage,
              teamLink: true,
            ),
            if (widget.showRole) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.card,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _roleIcon(widget.member.role),
                      size: 10,
                      color: AppTheme.textB,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      widget.member.role,
                      style: const TextStyle(
                        color: AppTheme.textB,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Use Material icons instead of emoji for consistent cross-platform rendering
  IconData _roleIcon(String role) => switch (role) {
    'Brain'     => Icons.psychology,
    'Shield'    => Icons.shield,
    'Scout'     => Icons.bolt,
    'Innovator' => Icons.lightbulb_outline,
    'Striker'   => Icons.gps_fixed,
    _           => Icons.person,
  };
}

/// Draws animated pulse connection lines between member positions.
class _ConnectionPainter extends CustomPainter {
  final int memberCount;
  final double animValue;
  final Color lineColor;

  const _ConnectionPainter({
    required this.memberCount,
    required this.animValue,
    required this.lineColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (memberCount < 2) return;

    final pulse = (0.3 + math.sin(animValue * 2 * math.pi) * 0.3).clamp(0.1, 0.8);
    final paint = Paint()
      ..color = lineColor.withValues(alpha: pulse)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final cx = size.width / 2;
    final cy = size.height / 2;
    const cardSize = 80.0;
    const gap = 32.0;

    switch (memberCount) {
      case 2:
        canvas.drawLine(
          Offset(cx - gap - cardSize / 2, cy - 20),
          Offset(cx + gap + cardSize / 2, cy - 20),
          paint,
        );
      case 3:
        final top = Offset(cx, cardSize / 2);
        final bl  = Offset(cx - cardSize - gap / 2, size.height - cardSize / 2);
        final br  = Offset(cx + cardSize + gap / 2, size.height - cardSize / 2);
        canvas.drawLine(top, bl, paint);
        canvas.drawLine(top, br, paint);
        canvas.drawLine(bl, br, paint);
      case 4:
        final tl  = Offset(cx - cardSize / 2 - gap / 2, cardSize / 2);
        final tr  = Offset(cx + cardSize / 2 + gap / 2, cardSize / 2);
        final bll = Offset(cx - cardSize / 2 - gap / 2, size.height - cardSize / 2);
        final br  = Offset(cx + cardSize / 2 + gap / 2, size.height - cardSize / 2);
        canvas.drawLine(tl, tr, paint);
        canvas.drawLine(bll, br, paint);
        canvas.drawLine(tl, bll, paint);
        canvas.drawLine(tr, br, paint);
    }
  }

  @override
  bool shouldRepaint(_ConnectionPainter old) =>
      old.animValue != animValue || old.memberCount != memberCount;
}
