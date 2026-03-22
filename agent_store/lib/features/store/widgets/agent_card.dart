// lib/features/store/widgets/agent_card.dart

import 'package:agent_store/features/character/character_types.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme.dart';
import '../../../shared/models/agent_model.dart';
import '../../../shared/widgets/pixel_character_widget.dart';
import 'agent_card_v2.dart';

class AgentCard extends StatefulWidget {
  final AgentModel agent;
  final bool isOwned;
  const AgentCard({super.key, required this.agent, this.isOwned = false});

  @override
  State<AgentCard> createState() => _AgentCardState();
}

class _AgentCardState extends State<AgentCard> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    // Delegate to v2 card layout for agents with card_version "2.0"
    if (widget.agent.cardVersion == '2.0') {
      return AgentCardV2(agent: widget.agent, isOwned: widget.isOwned);
    }

    final agent = widget.agent;
    final rc = agent.rarity.color;
    return FocusableActionDetector(
      mouseCursor: SystemMouseCursors.click,
      onShowFocusHighlight: (v) => setState(() => _focused = v),
      onShowHoverHighlight: (v) => setState(() => _hovered = v),
      actions: <Type, Action<Intent>>{
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            context.go('/agent/${agent.id}');
            return null;
          },
        ),
      },
      child: AnimatedScale(
        scale: _hovered ? 1.02 : 1.0,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        child: GestureDetector(
          onTap: () => context.go('/agent/${agent.id}'),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            decoration: BoxDecoration(
              color: AppTheme.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _focused
                    ? AppTheme.gold.withValues(alpha: 0.6)
                    : _hovered
                        ? rc.withValues(alpha: 0.6)
                        : rc.withValues(alpha: 0.25),
                width: _focused ? 1.5 : 1.2,
              ),
              boxShadow: _focused
                  ? [
                      BoxShadow(
                        color: AppTheme.gold.withValues(alpha: 0.15),
                        blurRadius: 12,
                      ),
                    ]
                  : _hovered
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
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Type + Subclass heading with category icon
                        Row(children: [
                          Icon(
                            _categoryIcon(agent.category),
                            size: 11,
                            color: agent.characterType.accentColor
                                .withValues(alpha: 0.7),
                          ),
                          const SizedBox(width: 4),
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
                          // Rarity badge with label
                          _RarityBadge(rarity: agent.rarity),
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
                          style: const TextStyle(
                              color: AppTheme.textM,
                              fontSize: 11,
                              height: 1.4),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        if (agent.stats.isNotEmpty)
                          _MiniStatBars(
                              stats: agent.stats,
                              color: agent.characterType.primaryColor),
                        if (agent.stats.isNotEmpty) const SizedBox(height: 8),
                        Row(children: [
                          const Icon(Icons.bookmarks_outlined,
                              size: 11, color: AppTheme.textM),
                          const SizedBox(width: 3),
                          Text('${agent.saveCount}',
                              style: const TextStyle(
                                  color: AppTheme.textM, fontSize: 10)),
                          const SizedBox(width: 10),
                          const Icon(Icons.play_circle_outline,
                              size: 11, color: AppTheme.textM),
                          const SizedBox(width: 3),
                          Text('${agent.useCount}',
                              style: const TextStyle(
                                  color: AppTheme.textM, fontSize: 10)),
                          const Spacer(),
                          if (agent.price > 0)
                            _PriceBadge(price: agent.price)
                          else
                            const _FreeBadge(),
                        ]),
                      ]),
                ),
              ]),
              // MINE badge
              if (widget.isOwned)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.primary,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('MINE',
                        style: TextStyle(
                            color: AppTheme.textH,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5)),
                  ),
                ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Returns the appropriate icon for a category string
IconData _categoryIcon(String category) {
  switch (category.toLowerCase()) {
    case 'backend':
      return Icons.code_rounded;
    case 'frontend':
      return Icons.palette_rounded;
    case 'data':
      return Icons.bar_chart_rounded;
    case 'security':
      return Icons.shield_rounded;
    case 'creative':
      return Icons.auto_awesome_rounded;
    case 'business':
    case 'marketing':
      return Icons.business_center_rounded;
    case 'research':
      return Icons.science_rounded;
    case 'planning':
      return Icons.map_rounded;
    default:
      return Icons.auto_awesome_rounded;
  }
}

/// Visually distinct rarity badge with color-coded label
class _RarityBadge extends StatelessWidget {
  final CharacterRarity rarity;
  const _RarityBadge({required this.rarity});

  @override
  Widget build(BuildContext context) {
    final rc = rarity.color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: rc.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: rc.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: rc,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                    color: rc.withValues(alpha: 0.7),
                    blurRadius: 4,
                    spreadRadius: 0.5),
              ],
            ),
          ),
          const SizedBox(width: 4),
          Text(
            rarity.displayName,
            style: TextStyle(
              color: rc,
              fontSize: 8,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.3,
            ),
          ),
        ],
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
  const _FreeBadge();
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
          style: TextStyle(
              color: AppTheme.olive,
              fontSize: 10,
              fontWeight: FontWeight.w600),
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
                  valueColor:
                      AlwaysStoppedAnimation(color.withValues(alpha: 0.85)),
                  minHeight: 3,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                e.key
                    .substring(0, e.key.length >= 3 ? 3 : e.key.length)
                    .toUpperCase(),
                style: const TextStyle(
                    color: AppTheme.textM, fontSize: 7, letterSpacing: 0.3),
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
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(14)),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              agent.characterType.secondaryColor
                  .withValues(alpha: hovered ? 0.55 : 0.35),
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
              imageUrl: agent.imageUrl,
            ),
          ),
        ),
      );
}
