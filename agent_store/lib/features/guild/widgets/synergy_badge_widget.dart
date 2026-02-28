import 'package:flutter/material.dart';
import '../../../shared/models/guild_model.dart';

/// Displays a list of active synergy bonuses as colored chips.
class SynergyBadgeList extends StatelessWidget {
  final List<SynergyBonus> synergies;
  const SynergyBadgeList({super.key, required this.synergies});

  @override
  Widget build(BuildContext context) {
    if (synergies.isEmpty) {
      return const Text(
        'No active synergies yet',
        style: TextStyle(color: Color(0xFF6B7280), fontSize: 12),
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: synergies.map((s) => _SynergyChip(synergy: s)).toList(),
    );
  }
}

class _SynergyChip extends StatelessWidget {
  final SynergyBonus synergy;
  const _SynergyChip({required this.synergy});

  Color get _chipColor {
    if (synergy.name.contains('Legendary')) return const Color(0xFFF59E0B);
    if (synergy.name.contains('Force'))     return const Color(0xFFA855F7);
    if (synergy.name.contains('Sorcerer') ||
        synergy.name.contains('Tank') ||
        synergy.name.contains('Think')) { return const Color(0xFF3B82F6); }
    return const Color(0xFF6366F1);
  }

  @override
  Widget build(BuildContext context) {
    final c = _chipColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        border: Border.all(color: c.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
          synergy.name,
          style: TextStyle(color: c, fontSize: 11, fontWeight: FontWeight.bold),
        ),
        Text(
          synergy.bonusText,
          style: TextStyle(color: c.withValues(alpha: 0.75), fontSize: 10),
        ),
      ]),
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
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(children: [
      SizedBox(
        width: 90,
        child: Text(
          stat.toUpperCase(),
          style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 10, letterSpacing: 0.8),
        ),
      ),
      const Icon(Icons.add, size: 12, color: Color(0xFF22C55E)),
      Text(
        '$value',
        style: const TextStyle(color: Color(0xFF22C55E), fontSize: 11, fontWeight: FontWeight.bold),
      ),
    ]),
  );
}
