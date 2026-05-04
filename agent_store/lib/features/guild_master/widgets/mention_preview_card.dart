// lib/features/guild_master/widgets/mention_preview_card.dart
//
// Pure presentational hover card surfaced next to an @-mention dropdown
// item. Has no JS interop — safe to import from widget tests.

import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/constants/api_constants.dart';
import '../../../features/character/character_types.dart';
import '../../../shared/models/agent_model.dart';

class MentionPreviewCard extends StatelessWidget {
  final AgentModel agent;

  /// Fixed visual width — matches the dropdown's right gutter so overlay
  /// placement code stays simple.
  static const double width = 280;

  const MentionPreviewCard({super.key, required this.agent});

  @override
  Widget build(BuildContext context) {
    final rarityColor = agent.rarity.color;
    return Material(
      color: Colors.transparent,
      child: Container(
        width: width,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.card2,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: rarityColor.withValues(alpha: 0.6),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: rarityColor.withValues(alpha: 0.2),
              blurRadius: 16,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top row — avatar + title + character chip
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _Avatar(agent: agent),
              const SizedBox(width: 10),
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
                    const SizedBox(height: 4),
                    Row(children: [
                      _Chip(
                        label: agent.characterType.displayName,
                        color: agent.characterType.accentColor,
                      ),
                      const SizedBox(width: 6),
                      _Chip(
                        label: agent.rarity.displayName,
                        color: rarityColor,
                      ),
                    ]),
                  ],
                ),
              ),
            ]),
            if (agent.description.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                agent.description,
                style: const TextStyle(
                  color: AppTheme.textM,
                  fontSize: 11,
                  height: 1.5,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            // Footer — save / use counts
            const SizedBox(height: 10),
            Row(children: [
              const Icon(Icons.bookmarks_outlined,
                  size: 11, color: AppTheme.textM),
              const SizedBox(width: 3),
              Text('${agent.saveCount}',
                  style:
                      const TextStyle(color: AppTheme.textM, fontSize: 10)),
              const SizedBox(width: 10),
              const Icon(Icons.play_circle_outline,
                  size: 11, color: AppTheme.textM),
              const SizedBox(width: 3),
              Text('${agent.useCount}',
                  style:
                      const TextStyle(color: AppTheme.textM, fontSize: 10)),
            ]),
          ],
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final AgentModel agent;
  const _Avatar({required this.agent});

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: agent.characterType.secondaryColor.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: agent.characterType.primaryColor.withValues(alpha: 0.4),
        ),
      ),
      child: Center(
        child: Icon(
          Icons.person_outline_rounded,
          color: agent.characterType.accentColor.withValues(alpha: 0.6),
          size: 20,
        ),
      ),
    );

    final url = agent.imageUrl;
    if (url == null || url.isEmpty) return fallback;
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Image.network(
        '${ApiConstants.baseUrl}$url',
        width: 40,
        height: 40,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.none,
        errorBuilder: (_, __, ___) => fallback,
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  const _Chip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
