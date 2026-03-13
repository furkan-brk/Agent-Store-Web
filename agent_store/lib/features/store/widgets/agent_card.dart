import 'package:agent_store/features/character/character_types.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme.dart';
import '../../../shared/models/agent_model.dart';
import '../../../shared/widgets/pixel_character_widget.dart';

class AgentCard extends StatefulWidget {
  final AgentModel agent;
  final bool isOwned;
  const AgentCard({super.key, required this.agent, this.isOwned = false});

  @override
  State<AgentCard> createState() => _AgentCardState();
}

class _AgentCardState extends State<AgentCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final agent = widget.agent;
    final rc = agent.rarity.color;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedScale(
        scale: _hovered ? 1.02 : 1.0,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        child: InkWell(
          onTap: () => context.go('/agent/${agent.id}'),
          borderRadius: BorderRadius.circular(14),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            decoration: BoxDecoration(
              color: AppTheme.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _hovered
                    ? rc.withValues(alpha: 0.6)
                    : rc.withValues(alpha: 0.25),
                width: 1.2,
              ),
              boxShadow: _hovered
                  ? [
                      BoxShadow(
                        color: rc.withValues(alpha: 0.25),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
            ),
            child: Stack(children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _CharacterBanner(agent: agent, hovered: _hovered),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    // Type · Subclass heading
                    Row(children: [
                      Expanded(
                        child: Text(
                          '${agent.characterType.displayName} · ${agent.subclass.displayName}',
                          style: TextStyle(
                            color: agent.characterType.accentColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // Rarity dot with glow
                      Container(
                        width: 8, height: 8,
                        decoration: BoxDecoration(
                          color: rc,
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: rc.withValues(alpha: 0.8), blurRadius: 6, spreadRadius: 1)],
                        ),
                      ),
                    ]),
                    const SizedBox(height: 5),
                    Text(
                      agent.title,
                      style: const TextStyle(
                        color: AppTheme.textH,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      agent.description,
                      style: const TextStyle(color: AppTheme.textM, fontSize: 11, height: 1.4),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    if (agent.stats.isNotEmpty)
                      _MiniStatBars(stats: agent.stats, color: agent.characterType.primaryColor),
                    const SizedBox(height: 8),
                    Row(children: [
                      const Icon(Icons.bookmarks_outlined, size: 11, color: AppTheme.textM),
                      const SizedBox(width: 3),
                      Text('${agent.saveCount}', style: const TextStyle(color: AppTheme.textM, fontSize: 10)),
                      const SizedBox(width: 10),
                      const Icon(Icons.play_circle_outline, size: 11, color: AppTheme.textM),
                      const SizedBox(width: 3),
                      Text('${agent.useCount}', style: const TextStyle(color: AppTheme.textM, fontSize: 10)),
                      const Spacer(),
                      if (agent.price > 0)
                        _PriceBadge(price: agent.price)
                      else
                        _FreeBadge(),
                    ]),
                  ]),
                ),
              ]),
              // MINE badge
              if (widget.isOwned)
                Positioned(
                  top: 8, right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.primary,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('MINE',
                        style: TextStyle(color: AppTheme.textH, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                  ),
                ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _PriceBadge extends StatelessWidget {
  final double price;
  const _PriceBadge({required this.price});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF8B6914), AppTheme.gold],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(5),
    ),
    child: Text(
      '${price.toStringAsFixed(2)} MON',
      style: const TextStyle(
        color: Color(0xFF1E1A14),
        fontSize: 10,
        fontWeight: FontWeight.bold,
      ),
    ),
  );
}

class _FreeBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: AppTheme.olive.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(5),
      border: Border.all(color: AppTheme.olive.withValues(alpha: 0.5)),
    ),
    child: const Text(
      'Free',
      style: TextStyle(color: AppTheme.olive, fontSize: 10, fontWeight: FontWeight.w600),
    ),
  );
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
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: e.value / 100,
                  backgroundColor: AppTheme.border,
                  valueColor: AlwaysStoppedAnimation(color.withValues(alpha: 0.85)),
                  minHeight: 3,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                e.key.substring(0, e.key.length >= 3 ? 3 : e.key.length).toUpperCase(),
                style: const TextStyle(color: AppTheme.textM, fontSize: 7, letterSpacing: 0.3),
              ),
            ]),
          ),
        );
      }).toList(),
    );
  }
}

class _CharacterBanner extends StatelessWidget {
  final AgentModel agent;
  final bool hovered;
  const _CharacterBanner({required this.agent, required this.hovered});

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 200),
    height: 155,
    decoration: BoxDecoration(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          agent.characterType.secondaryColor.withValues(alpha: hovered ? 0.55 : 0.35),
          agent.characterType.primaryColor.withValues(alpha: 0.08),
          AppTheme.card,
        ],
        stops: const [0.0, 0.6, 1.0],
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
