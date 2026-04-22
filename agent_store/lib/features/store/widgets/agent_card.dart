import 'dart:convert';

import 'package:agent_store/features/character/character_types.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/animations.dart';
import '../../../app/theme.dart';
import '../../../core/constants/api_constants.dart';
import '../../../shared/models/agent_model.dart';
import '../../../shared/utils/category_icon.dart';
import '../../../shared/widgets/pixel_character_widget.dart';
import '../data/background_data.dart';

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
              borderRadius: BorderRadius.circular(AppSizing.cardRadius),
              border: Border.all(
                color: _focused
                    ? AppTheme.gold.withValues(alpha: 0.6)
                    : _hovered
                        ? rc.withValues(alpha: 0.6)
                        : rc.withValues(alpha: 0.25),
                width: _focused ? 1.5 : 1.2,
              ),
              boxShadow: _focused
                  ? [BoxShadow(color: AppTheme.gold.withValues(alpha: 0.15), blurRadius: 12)]
                  : _hovered
                      ? [
                          BoxShadow(color: rc.withValues(alpha: 0.25), blurRadius: 20, spreadRadius: 2),
                          BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 12, offset: const Offset(0, 4)),
                        ]
                      : [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 2))],
            ),
            child: Stack(children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _CharacterBanner(agent: agent, hovered: _hovered),
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Icon(
                        categoryIcon(agent.category),
                        size: 11,
                        color: agent.characterType.accentColor.withValues(alpha: 0.7),
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
                      style: const TextStyle(color: AppTheme.textM, fontSize: 11, height: 1.4),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    if (agent.stats.isNotEmpty && agent.cardVersion != '2.0') ...[
                      _MiniStatBars(stats: agent.stats, color: agent.characterType.primaryColor),
                      const SizedBox(height: 8),
                    ],
                    Row(children: [
                      const Icon(Icons.bookmarks_outlined, size: 11, color: AppTheme.textM),
                      const SizedBox(width: 3),
                      Text('${agent.saveCount}',
                          style: const TextStyle(color: AppTheme.textM, fontSize: 10)),
                      const SizedBox(width: 10),
                      const Icon(Icons.play_circle_outline, size: 11, color: AppTheme.textM),
                      const SizedBox(width: 3),
                      Text('${agent.useCount}',
                          style: const TextStyle(color: AppTheme.textM, fontSize: 10)),
                      const Spacer(),
                      if (agent.price > 0)
                        _PriceBadge(price: agent.price)
                      else
                        const _FreeBadge(),
                    ]),
                  ]),
                ),
              ]),
              if (widget.isOwned)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
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

// ---------------------------------------------------------------------------
// Banner: responsive height via LayoutBuilder, V1 = gradient, V2 = bg image
// ---------------------------------------------------------------------------

class _CharacterBanner extends StatelessWidget {
  final AgentModel agent;
  final bool hovered;
  const _CharacterBanner({required this.agent, required this.hovered});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bannerH = (constraints.maxWidth * 0.52).clamp(130.0, 180.0);
        if (agent.cardVersion == '2.0') {
          return _BackgroundBanner(agent: agent, hovered: hovered, height: bannerH);
        }
        return AnimatedContainer(
          duration: AppAnimations.hoverDuration,
          height: bannerH,
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
                imageUrl: agent.imageUrl,
              ),
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// V2 banner: background scene + portrait overlay
// ---------------------------------------------------------------------------

class _BackgroundBanner extends StatelessWidget {
  final AgentModel agent;
  final bool hovered;
  final double height;
  const _BackgroundBanner({required this.agent, required this.hovered, required this.height});

  @override
  Widget build(BuildContext context) {
    final bg = matchBackground(agent.category, agent.characterType.name);
    final hasAsset = generatedBackgrounds.contains(bg.id);

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
      height: height,
      width: double.infinity,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
        child: Stack(children: [
          Positioned.fill(
            child: AnimatedOpacity(
              duration: AppAnimations.hoverDuration,
              opacity: hovered ? 1.0 : 0.85,
              child: hasAsset
                  ? Image.asset(
                      bg.assetPath,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      errorBuilder: (_, __, ___) => gradientFallback,
                    )
                  : gradientFallback,
            ),
          ),
          Positioned(
            left: 0, right: 0, bottom: 0, height: 40,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, AppTheme.card.withValues(alpha: 0.9)],
                ),
              ),
            ),
          ),
          Positioned(
            left: 12,
            bottom: 4,
            child: _CharacterPortrait(agent: agent, height: height * 0.75),
          ),
          Positioned(
            right: 10,
            bottom: 10,
            child: _InfoOverlay(agent: agent),
          ),
        ]),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Character portrait (V2)
// ---------------------------------------------------------------------------

class _CharacterPortrait extends StatelessWidget {
  final AgentModel agent;
  final double height;
  const _CharacterPortrait({required this.agent, required this.height});

  double get _width => height * (100 / 120);

  @override
  Widget build(BuildContext context) {
    final hasUrl = agent.imageUrl != null && agent.imageUrl!.isNotEmpty;
    final hasBase64 = agent.generatedImage != null && agent.generatedImage!.isNotEmpty;

    if (!hasUrl && !hasBase64) return _placeholder();

    return Container(
      width: _width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 10, offset: const Offset(0, 3)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: hasUrl
            ? Image.network(
                '${ApiConstants.baseUrl}${agent.imageUrl}',
                fit: BoxFit.contain,
                width: _width,
                height: height,
                loadingBuilder: (_, child, progress) => progress == null ? child : _placeholder(),
                errorBuilder: (_, __, ___) {
                  if (hasBase64) return _base64Image();
                  return _placeholder();
                },
              )
            : _base64Image(),
      ),
    );
  }

  Widget _base64Image() {
    try {
      final bytes = base64Decode(agent.generatedImage!);
      return Image.memory(bytes, fit: BoxFit.contain, width: _width, height: height,
          errorBuilder: (_, __, ___) => _placeholder());
    } catch (_) {
      return _placeholder();
    }
  }

  Widget _placeholder() => Container(
        width: _width,
        height: height,
        decoration: BoxDecoration(
          color: agent.characterType.secondaryColor.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: agent.characterType.primaryColor.withValues(alpha: 0.4)),
        ),
        child: Center(
          child: Icon(Icons.person_outline_rounded,
              color: agent.characterType.accentColor.withValues(alpha: 0.5), size: 36),
        ),
      );
}

// ---------------------------------------------------------------------------
// Info overlay (V2 right-side panel)
// ---------------------------------------------------------------------------

class _InfoOverlay extends StatelessWidget {
  final AgentModel agent;
  const _InfoOverlay({required this.agent});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 80, maxWidth: 140),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          _PromptScoreBadge(score: agent.promptScore),
          if (agent.serviceDescription != null && agent.serviceDescription!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              agent.serviceDescription!,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 10, height: 1.3),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
            ),
          ],
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: agent.characterType.primaryColor.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: agent.characterType.accentColor.withValues(alpha: 0.4)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(categoryIcon(agent.category), size: 9, color: agent.characterType.accentColor),
              const SizedBox(width: 3),
              Text(
                agent.category.isNotEmpty
                    ? agent.category[0].toUpperCase() + agent.category.substring(1)
                    : 'General',
                style: TextStyle(
                    color: agent.characterType.accentColor,
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Prompt score badge
// ---------------------------------------------------------------------------

class _PromptScoreBadge extends StatelessWidget {
  final int score;
  const _PromptScoreBadge({required this.score});

  Color get _color {
    if (score >= 91) return const Color(0xFFD4A843);
    if (score >= 81) return const Color(0xFF4A90D9);
    if (score >= 61) return const Color(0xFF5EA85A);
    if (score >= 41) return Colors.white;
    return const Color(0xFF8B8070);
  }

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.star_rounded, color: _color, size: 14),
          const SizedBox(width: 4),
          Text('$score',
              style: TextStyle(color: _color, fontSize: 12, fontWeight: FontWeight.bold)),
        ]),
      );
}

// ---------------------------------------------------------------------------
// Rarity badge
// ---------------------------------------------------------------------------

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
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: rc,
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: rc.withValues(alpha: 0.7), blurRadius: 4, spreadRadius: 0.5)],
          ),
        ),
        const SizedBox(width: 4),
        Text(rarity.displayName,
            style: TextStyle(color: rc, fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 0.3)),
      ]),
    );
  }
}

// ---------------------------------------------------------------------------
// Price / Free badges
// ---------------------------------------------------------------------------

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
          style: const TextStyle(color: Color(0xFF1E1A14), fontSize: 10, fontWeight: FontWeight.bold),
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
        child: const Text('Free',
            style: TextStyle(color: AppTheme.olive, fontSize: 10, fontWeight: FontWeight.w600)),
      );
}

// ---------------------------------------------------------------------------
// Mini stat bars (V1 only)
// ---------------------------------------------------------------------------

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
