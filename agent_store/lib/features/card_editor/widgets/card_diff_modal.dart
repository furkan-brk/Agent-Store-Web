// lib/features/card_editor/widgets/card_diff_modal.dart
//
// v3.11.3 — T9b — Side-by-side original vs draft AgentCard preview with
// a field-level change list at the bottom. Opens from the toolbar's
// "Preview changes" button (only enabled when the controller is dirty).

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../shared/models/agent_model.dart';
import '../../store/widgets/agent_card.dart';

class CardDiffModal extends StatelessWidget {
  final AgentModel original;
  final AgentModel draft;

  const CardDiffModal({
    super.key,
    required this.original,
    required this.draft,
  });

  static Future<void> show(
    BuildContext context, {
    required AgentModel original,
    required AgentModel draft,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => CardDiffModal(original: original, draft: draft),
    );
  }

  /// Pure helper so unit tests can reach it without instantiating the modal.
  /// Each entry is a single human-readable diff line: "title: 'old' → 'new'".
  static List<String> diffFields(AgentModel a, AgentModel b) {
    final out = <String>[];
    if (a.title != b.title) out.add("title: '${a.title}' → '${b.title}'");
    if (a.description != b.description) {
      out.add('description changed (${a.description.length}c → ${b.description.length}c)');
    }
    if (a.prompt != b.prompt) {
      out.add('prompt changed (${a.prompt.length}c → ${b.prompt.length}c)');
    }
    if (a.category != b.category) out.add("category: '${a.category}' → '${b.category}'");
    if (a.subclass != b.subclass) {
      out.add('subclass: ${a.subclass.name} → ${b.subclass.name}');
    }
    if (a.cardVersion != b.cardVersion) {
      out.add("cardVersion: '${a.cardVersion}' → '${b.cardVersion}'");
    }
    if (a.price != b.price) out.add('price: ${a.price} → ${b.price}');
    if (a.serviceDescription != b.serviceDescription) {
      out.add('service description changed');
    }
    if (a.profileMood != b.profileMood) {
      out.add("mood: '${a.profileMood}' → '${b.profileMood}'");
    }
    if (a.profileRolePurpose != b.profileRolePurpose) {
      out.add('role purpose changed');
    }
    if (!listEquals(a.tags, b.tags)) {
      out.add('tags: ${a.tags.length} → ${b.tags.length}');
    }
    if (!listEquals(a.traits, b.traits)) {
      out.add('traits: ${a.traits.length} → ${b.traits.length}');
    }
    a.stats.forEach((k, v) {
      final nv = b.stats[k];
      if (nv != null && nv != v) out.add('stats.$k: $v → $nv');
    });
    b.stats.forEach((k, v) {
      if (!a.stats.containsKey(k)) out.add('stats.$k: + $v');
    });
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final changes = diffFields(original, draft);
    return Dialog(
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppTheme.border),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 980, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.compare_outlined, color: AppTheme.gold, size: 20),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Preview changes',
                          style: TextStyle(
                            color: AppTheme.textH,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Compare the original card with your draft.',
                          style: TextStyle(color: AppTheme.textM, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded,
                        color: AppTheme.textM, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: 'Close',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      LayoutBuilder(
                        builder: (ctx, c) {
                          final narrow = c.maxWidth < 700;
                          if (narrow) {
                            return Column(children: [
                              _CardFacet(
                                  title: 'Original', agent: original, dim: true),
                              const SizedBox(height: 16),
                              _CardFacet(title: 'Draft', agent: draft),
                            ]);
                          }
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: _CardFacet(
                                    title: 'Original',
                                    agent: original,
                                    dim: true),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _CardFacet(title: 'Draft', agent: draft),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 18),
                      _ChangeList(changes: changes),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CardFacet extends StatelessWidget {
  final String title;
  final AgentModel agent;
  final bool dim;
  const _CardFacet({required this.title, required this.agent, this.dim = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: const TextStyle(
            color: AppTheme.textM,
            fontSize: 10,
            letterSpacing: 1.4,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: SizedBox(
            width: 280,
            child: RepaintBoundary(
              child: Opacity(
                opacity: dim ? 0.85 : 1,
                child: AgentCard(agent: agent, isOwned: true),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ChangeList extends StatelessWidget {
  final List<String> changes;
  const _ChangeList({required this.changes});

  @override
  Widget build(BuildContext context) {
    if (changes.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          'No editable fields differ.',
          style: TextStyle(color: AppTheme.textM.withValues(alpha: 0.85)),
        ),
      );
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.bg.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.gold.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.edit_note, color: AppTheme.gold, size: 16),
            const SizedBox(width: 6),
            Text(
              'Changed fields (${changes.length})',
              style: const TextStyle(
                color: AppTheme.textH,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ]),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: changes
                .map((c) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.card2,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: Text(
                        c,
                        style: const TextStyle(
                          color: AppTheme.textB,
                          fontSize: 11.5,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}
