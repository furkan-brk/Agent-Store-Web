import 'package:agent_store/features/character/character_types.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/models/agent_model.dart';
import '../../../shared/widgets/pixel_character_widget.dart';

class AgentCard extends StatelessWidget {
  final AgentModel agent;
  final bool isOwned;
  const AgentCard({super.key, required this.agent, this.isOwned = false});

  @override
  Widget build(BuildContext context) {
    final rc = agent.rarity.color;
    return InkWell(
      onTap: () => context.go('/agent/${agent.id}'),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF13131F),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: rc.withValues(alpha: 0.3)),
          boxShadow: [BoxShadow(color: rc.withValues(alpha: 0.06), blurRadius: 10)],
        ),
        child: Stack(children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _CharacterBanner(agent: agent),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Type · Subclass heading
              Row(children: [
                Text(
                  '${agent.characterType.displayName} · ${agent.subclass.displayName}',
                  style: TextStyle(
                    color: agent.characterType.accentColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                const Spacer(),
                Container(
                  width: 7, height: 7,
                  decoration: BoxDecoration(color: rc, shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: rc.withValues(alpha: 0.6), blurRadius: 4)]),
                ),
              ]),
              const SizedBox(height: 4),
              Text(agent.title,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Text(agent.description,
                style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 11),
                maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 8),
              // Mini stat bars
              if (agent.stats.isNotEmpty) _MiniStatBars(stats: agent.stats, color: agent.characterType.primaryColor),
              const SizedBox(height: 8),
              Row(children: [
                const Icon(Icons.bookmarks_outlined, size: 11, color: Color(0xFF6B7280)),
                const SizedBox(width: 3),
                Text('${agent.saveCount}', style: const TextStyle(color: Color(0xFF6B7280), fontSize: 10)),
                const SizedBox(width: 10),
                const Icon(Icons.play_circle_outline, size: 11, color: Color(0xFF6B7280)),
                const SizedBox(width: 3),
                Text('${agent.useCount}', style: const TextStyle(color: Color(0xFF6B7280), fontSize: 10)),
                const Spacer(),
                if (agent.price > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.6)),
                    ),
                    child: Text(
                      '${agent.price.toStringAsFixed(2)} MON',
                      style: const TextStyle(
                        color: Color(0xFFF59E0B),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
                    ),
                    child: const Text(
                      'Free',
                      style: TextStyle(
                        color: Color(0xFF10B981),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(color: const Color(0xFF1F2937), borderRadius: BorderRadius.circular(4)),
                  child: Text(agent.category, style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 9)),
                ),
              ]),
            ]),
          ),
        ]),
          if (isOwned)
            Positioned(
              top: 8, right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('MINE', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
              ),
            ),
        ]),
      ),
    );
  }
}

class _MiniStatBars extends StatelessWidget {
  final Map<String, int> stats;
  final Color color;
  const _MiniStatBars({required this.stats, required this.color});

  @override
  Widget build(BuildContext context) {
    final entries = stats.entries.take(5).toList();
    return Row(
      children: entries.map((e) {
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1),
            child: Column(children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(1),
                child: LinearProgressIndicator(
                  value: e.value / 100,
                  backgroundColor: const Color(0xFF1F2937),
                  valueColor: AlwaysStoppedAnimation(color.withValues(alpha: 0.8)),
                  minHeight: 3,
                ),
              ),
              const SizedBox(height: 2),
              Text(e.key.substring(0, 3).toUpperCase(),
                style: const TextStyle(color: Color(0xFF4B5563), fontSize: 7, letterSpacing: 0.3)),
            ]),
          ),
        );
      }).toList(),
    );
  }
}

class _CharacterBanner extends StatelessWidget {
  final AgentModel agent;
  const _CharacterBanner({required this.agent});

  @override
  Widget build(BuildContext context) => Container(
    height: 155,
    decoration: BoxDecoration(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      gradient: LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [agent.characterType.secondaryColor.withValues(alpha: 0.4), const Color(0xFF0A0A14)],
      ),
    ),
    child: Center(
      child: RepaintBoundary(
        child: PixelCharacterWidget(
          characterType: agent.characterType,
          rarity: agent.rarity,
          subclass: agent.subclass,
          size: 88,
          agentId: agent.id,
          generatedImage: agent.generatedImage,
        ),
      ),
    ),
  );
}
