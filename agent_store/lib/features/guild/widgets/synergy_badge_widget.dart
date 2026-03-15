// lib/features/guild/widgets/synergy_badge_widget.dart

import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../../../shared/models/guild_model.dart';

/// Displays a list of active synergy bonuses as colored chips.
class SynergyBadgeList extends StatelessWidget {
  final List<SynergyBonus> synergies;
  const SynergyBadgeList({super.key, required this.synergies});

  @override
  Widget build(BuildContext context) {
    if (synergies.isEmpty) {
      return Row(
        children: [
          Icon(
            Icons.link_off,
            size: 14,
            color: AppTheme.textM.withValues(alpha: 0.6),
          ),
          const SizedBox(width: 6),
          const Text(
            'No active synergies yet',
            style: TextStyle(color: AppTheme.textM, fontSize: 12),
          ),
        ],
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: synergies.map((s) => _SynergyChip(synergy: s)).toList(),
    );
  }
}

class _SynergyChip extends StatefulWidget {
  final SynergyBonus synergy;
  const _SynergyChip({required this.synergy});

  @override
  State<_SynergyChip> createState() => _SynergyChipState();
}

class _SynergyChipState extends State<_SynergyChip> {
  bool _hovered = false;

  /// Color-code by synergy tier: legendary = gold, force = olive, others = primary
  Color get _chipColor {
    if (widget.synergy.name.contains('Legendary')) return AppTheme.gold;
    if (widget.synergy.name.contains('Force'))     return AppTheme.olive;
    if (widget.synergy.name.contains('Sorcerer') ||
        widget.synergy.name.contains('Tank') ||
        widget.synergy.name.contains('Think')) {
      return const Color(0xFF5F8A6A); // teal-green — distinct from olive
    }
    return AppTheme.primary;
  }

  IconData get _chipIcon {
    if (widget.synergy.name.contains('Legendary')) return Icons.auto_awesome;
    if (widget.synergy.name.contains('Force'))     return Icons.bolt;
    if (widget.synergy.name.contains('Sorcerer'))  return Icons.local_fire_department;
    if (widget.synergy.name.contains('Tank'))       return Icons.shield;
    if (widget.synergy.name.contains('Think'))      return Icons.psychology;
    return Icons.link;
  }

  @override
  Widget build(BuildContext context) {
    final c = _chipColor;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Tooltip(
        message: '${widget.synergy.name}: ${widget.synergy.bonusText}',
        preferBelow: false,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: c.withValues(alpha: _hovered ? 0.20 : 0.12),
            border: Border.all(color: c.withValues(alpha: _hovered ? 0.7 : 0.4)),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_chipIcon, size: 12, color: c),
              const SizedBox(width: 5),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.synergy.name,
                    style: TextStyle(
                      color: c,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    widget.synergy.bonusText,
                    style: TextStyle(
                      color: c.withValues(alpha: 0.8),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Combined stat row showing total bonus across all synergies.
class CombinedBonusBar extends StatelessWidget {
  final Map<String, int> bonuses;
  const CombinedBonusBar({super.key, required this.bonuses});

  @override
  Widget build(BuildContext context) {
    if (bonuses.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: bonuses.entries.map((e) => _BonusRow(stat: e.key, value: e.value)).toList(),
    );
  }
}

class _BonusRow extends StatelessWidget {
  final String stat;
  final int value;
  const _BonusRow({required this.stat, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(_statIcon(stat), size: 12, color: AppTheme.textM),
          const SizedBox(width: 6),
          SizedBox(
            width: 80,
            child: Text(
              stat.toUpperCase(),
              style: const TextStyle(
                color: AppTheme.textB,
                fontSize: 10,
                letterSpacing: 0.8,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: AppTheme.olive.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.add, size: 10, color: AppTheme.olive),
                const SizedBox(width: 2),
                Text(
                  '$value',
                  style: const TextStyle(
                    color: AppTheme.olive,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _statIcon(String key) => switch (key) {
    'intelligence' => Icons.psychology,
    'defense'      => Icons.shield,
    'speed'        => Icons.speed,
    'creativity'   => Icons.palette,
    'power'        => Icons.flash_on,
    _              => Icons.star,
  };
}
