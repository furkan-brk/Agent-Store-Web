// lib/features/store/widgets/agent_card_v2.dart

import 'dart:convert';

import 'package:agent_store/features/character/character_types.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/animations.dart';
import '../../../app/theme.dart';
import '../../../core/constants/api_constants.dart';
import '../../../shared/models/agent_model.dart';
import '../data/background_data.dart';

/// Agent card v2.0 -- background scene + transparent character portrait layout.
///
/// Layout:
/// +--------------------------------------+
/// |  BACKGROUND IMAGE (top, ~160px)      |
/// |  +---------+  +-------------------+  |
/// |  | CHAR    |  | Score: 92  *      |  |
/// |  | PORTRAIT|  | Backend Arch...   |  |
/// |  | (left)  |  | [category chip]   |  |
/// |  +---------+  +-------------------+  |
/// +--------------------------------------+
/// |  [rarity badge]                      |
/// |  Title                               |
/// |  Description...                      |
/// |  saves  uses              Free/Price |
/// +--------------------------------------+
class AgentCardV2 extends StatefulWidget {
  final AgentModel agent;
  final bool isOwned;

  const AgentCardV2({super.key, required this.agent, this.isOwned = false});

  @override
  State<AgentCardV2> createState() => _AgentCardV2State();
}

class _AgentCardV2State extends State<AgentCardV2> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
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
        duration: AppAnimations.hoverDuration,
        curve: Curves.easeOut,
        child: GestureDetector(
          onTap: () => context.go('/agent/${agent.id}'),
          child: AnimatedContainer(
            duration: AppAnimations.hoverDuration,
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
            child: Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _BackgroundBanner(
                      agent: agent,
                      hovered: _hovered,
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Type + Subclass heading with category icon and rarity badge
                          Row(
                            children: [
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
                            ],
                          ),
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
                              height: 1.4,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
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
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                // MINE badge
                if (widget.isOwned)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.primary,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'MINE',
                        style: TextStyle(
                          color: AppTheme.textH,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
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

// -- Background banner with character portrait overlay -------------------------

class _BackgroundBanner extends StatelessWidget {
  final AgentModel agent;
  final bool hovered;

  const _BackgroundBanner({required this.agent, required this.hovered});

  @override
  Widget build(BuildContext context) {
    final bg = matchBackground(agent.category, agent.characterType.name);
    final hasAsset = generatedBackgrounds.contains(bg.id);

    // Gradient fallback used when the matched background has no PNG asset
    final gradientFallback = Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            agent.characterType.secondaryColor.withValues(alpha: 0.4),
            agent.characterType.primaryColor.withValues(alpha: 0.15),
          ],
        ),
      ),
    );

    return SizedBox(
      height: 160,
      width: double.infinity,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
        child: Stack(
          children: [
            // Background image (or gradient fallback)
            Positioned.fill(
              child: AnimatedOpacity(
                duration: AppAnimations.hoverDuration,
                opacity: hovered ? 1.0 : 0.85,
                child: hasAsset
                    ? Image.asset(
                        bg.assetPath,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: 160,
                        errorBuilder: (_, __, ___) => gradientFallback,
                      )
                    : gradientFallback,
              ),
            ),

            // Subtle bottom fade into card background
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 40,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      AppTheme.card.withValues(alpha: 0.9),
                    ],
                  ),
                ),
              ),
            ),

            // Character portrait (left side, overlapping bottom edge)
            Positioned(
              left: 12,
              bottom: 4,
              child: _CharacterPortrait(agent: agent),
            ),

            // Right-side info panel (score, service desc, category)
            Positioned(
              right: 10,
              bottom: 10,
              child: _InfoOverlay(agent: agent),
            ),
          ],
        ),
      ),
    );
  }
}

// -- Character portrait with transparent bg ------------------------------------

class _CharacterPortrait extends StatelessWidget {
  final AgentModel agent;

  const _CharacterPortrait({required this.agent});

  @override
  Widget build(BuildContext context) {
    final hasUrl = agent.imageUrl != null && agent.imageUrl!.isNotEmpty;
    final hasBase64 = agent.generatedImage != null && agent.generatedImage!.isNotEmpty;

    if (!hasUrl && !hasBase64) {
      return _portraitPlaceholder();
    }

    return Container(
      width: 100,
      height: 120,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: hasUrl
            ? Image.network(
                '${ApiConstants.baseUrl}${agent.imageUrl}',
                fit: BoxFit.contain,
                width: 100,
                height: 120,
                loadingBuilder: (_, child, progress) {
                  if (progress == null) return child;
                  return _portraitPlaceholder();
                },
                errorBuilder: (_, __, ___) {
                  // Fall back to base64 if URL fails
                  if (hasBase64) {
                    try {
                      final bytes = base64Decode(agent.generatedImage!);
                      return Image.memory(
                        bytes,
                        fit: BoxFit.contain,
                        width: 100,
                        height: 120,
                        errorBuilder: (_, __, ___) => _portraitPlaceholder(),
                      );
                    } catch (_) {
                      return _portraitPlaceholder();
                    }
                  }
                  return _portraitPlaceholder();
                },
              )
            : _buildBase64Image(),
      ),
    );
  }

  Widget _buildBase64Image() {
    try {
      final bytes = base64Decode(agent.generatedImage!);
      return Image.memory(
        bytes,
        fit: BoxFit.contain,
        width: 100,
        height: 120,
        errorBuilder: (_, __, ___) => _portraitPlaceholder(),
      );
    } catch (_) {
      return _portraitPlaceholder();
    }
  }

  Widget _portraitPlaceholder() {
    return Container(
      width: 100,
      height: 120,
      decoration: BoxDecoration(
        color: agent.characterType.secondaryColor.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: agent.characterType.primaryColor.withValues(alpha: 0.4),
        ),
      ),
      child: Center(
        child: Icon(
          Icons.person_outline_rounded,
          color: agent.characterType.accentColor.withValues(alpha: 0.5),
          size: 36,
        ),
      ),
    );
  }
}

// -- Right-side overlay: score, service description, category chip ------------

class _InfoOverlay extends StatelessWidget {
  final AgentModel agent;

  const _InfoOverlay({required this.agent});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 140),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Prompt score badge
          _PromptScoreBadge(score: agent.promptScore),
          if (agent.serviceDescription != null &&
              agent.serviceDescription!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              agent.serviceDescription!,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 10,
                height: 1.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
            ),
          ],
          const SizedBox(height: 6),
          // Category chip with icon
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: agent.characterType.primaryColor.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color:
                    agent.characterType.accentColor.withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _categoryIcon(agent.category),
                  size: 9,
                  color: agent.characterType.accentColor,
                ),
                const SizedBox(width: 3),
                Text(
                  agent.category.isNotEmpty
                      ? agent.category[0].toUpperCase() +
                          agent.category.substring(1)
                      : 'General',
                  style: TextStyle(
                    color: agent.characterType.accentColor,
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// -- Prompt score badge -------------------------------------------------------

class _PromptScoreBadge extends StatelessWidget {
  final int score;

  const _PromptScoreBadge({required this.score});

  Color get _scoreColor {
    if (score >= 91) return const Color(0xFFD4A843); // gold
    if (score >= 81) return const Color(0xFF4A90D9); // blue
    if (score >= 61) return const Color(0xFF5EA85A); // green
    if (score >= 41) return Colors.white;
    return const Color(0xFF8B8070); // grey
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star_rounded, color: _scoreColor, size: 14),
          const SizedBox(width: 4),
          Text(
            '$score',
            style: TextStyle(
              color: _scoreColor,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

// -- Rarity badge with color-coded label --------------------------------------

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

// -- Shared sub-widgets (matching v1.0 styling) -------------------------------

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
