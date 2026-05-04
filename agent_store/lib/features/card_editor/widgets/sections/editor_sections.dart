import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../app/theme.dart';
import '../../../character/character_types.dart';
import '../../../../shared/utils/category_icon.dart';
import '../../controllers/card_editor_controller.dart';
import '../fields/editor_fields.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Section shell (accordion)
// ─────────────────────────────────────────────────────────────────────────────

/// Accordion-style collapsible section used by every form group.
class EditorSection extends StatefulWidget {
  const EditorSection({
    super.key,
    required this.title,
    required this.icon,
    required this.child,
    this.subtitle,
    this.initiallyExpanded = true,
  });

  final String title;
  final IconData icon;
  final Widget child;
  final String? subtitle;
  final bool initiallyExpanded;

  @override
  State<EditorSection> createState() => _EditorSectionState();
}

class _EditorSectionState extends State<EditorSection> {
  late bool _expanded = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Icon(widget.icon, color: AppTheme.gold, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: const TextStyle(
                            color: AppTheme.textH,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        if (widget.subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            widget.subtitle!,
                            style: const TextStyle(color: AppTheme.textM, fontSize: 11),
                          ),
                        ],
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    duration: const Duration(milliseconds: 180),
                    turns: _expanded ? 0.5 : 0.0,
                    child: const Icon(Icons.expand_more, color: AppTheme.textM, size: 20),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 180),
            crossFadeState: _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            firstChild: const SizedBox(width: double.infinity, height: 0),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
              child: widget.child,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 1. Identity — title, description, category
// ─────────────────────────────────────────────────────────────────────────────

class IdentitySection extends StatelessWidget {
  const IdentitySection({super.key, required this.controller});
  final CardEditorController controller;

  @override
  Widget build(BuildContext context) {
    return EditorSection(
      title: 'Identity',
      subtitle: 'Title, description, and category',
      icon: Icons.badge_outlined,
      child: Obx(() {
        final a = controller.draft.value;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            EditTextField(
              label: 'TITLE',
              value: a.title,
              maxLength: 80,
              minLength: 3,
              hint: 'Short, memorable name',
              onChanged: (v) => controller.updateField((d) => d.copyWith(title: v)),
            ),
            const SizedBox(height: 12),
            EditLongText(
              label: 'DESCRIPTION',
              value: a.description,
              maxLength: 500,
              hint: 'What does this agent do? (visible on the card)',
              onChanged: (v) => controller.updateField((d) => d.copyWith(description: v)),
            ),
            const SizedBox(height: 12),
            _CategoryPicker(controller: controller),
            const SizedBox(height: 12),
            EditTextField(
              label: 'SERVICE LINE (one-liner)',
              value: a.serviceDescription ?? '',
              maxLength: 200,
              hint: 'Optional — the analysis pipeline usually fills this',
              onChanged: (v) => controller.updateField(
                (d) => d.copyWith(serviceDescription: v.isEmpty ? null : v),
              ),
            ),
          ],
        );
      }),
    );
  }
}

class _CategoryPicker extends StatelessWidget {
  const _CategoryPicker({required this.controller});
  final CardEditorController controller;

  // Aligned with the backend category list (keep in sync with seed data).
  static const _categories = <String>[
    'Code', 'Writing', 'Analysis', 'Design', 'Marketing', 'Research',
    'Productivity', 'Education', 'Security', 'Data', 'Creative', 'Business',
  ];

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final current = controller.draft.value.category;
      final allOptions = {current, ..._categories}.where((c) => c.isNotEmpty).toList()
        ..sort();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'CATEGORY',
            style: TextStyle(color: AppTheme.textB, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.6),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: allOptions.map((cat) {
              final selected = cat == current;
              return FilterChip(
                avatar: Icon(categoryIcon(cat), size: 14, color: selected ? AppTheme.textH : AppTheme.textM),
                label: Text(cat, style: const TextStyle(fontSize: 12)),
                selected: selected,
                onSelected: (_) => controller.updateField((d) => d.copyWith(category: cat)),
                selectedColor: AppTheme.primary.withValues(alpha: 0.25),
                backgroundColor: AppTheme.card2,
                checkmarkColor: AppTheme.textH,
                side: BorderSide(color: selected ? AppTheme.primary : AppTheme.border),
              );
            }).toList(growable: false),
          ),
        ],
      );
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 2. Prompt — system prompt + score readout + Re-detect
// ─────────────────────────────────────────────────────────────────────────────

class PromptSection extends StatelessWidget {
  const PromptSection({super.key, required this.controller});
  final CardEditorController controller;

  @override
  Widget build(BuildContext context) {
    return EditorSection(
      title: 'Prompt',
      subtitle: 'The system prompt that powers this agent',
      icon: Icons.terminal,
      child: Obx(() {
        final a = controller.draft.value;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            EditLongText(
              label: 'SYSTEM PROMPT',
              value: a.prompt,
              minLines: 6,
              maxLines: 18,
              maxLength: 8000,
              onChanged: (v) => controller.updateField((d) => d.copyWith(prompt: v)),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _ScorePill(score: a.promptScore),
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: a.prompt.length < 20 ? null : controller.reDetectFromPrompt,
                  icon: const Icon(Icons.auto_fix_high, size: 14),
                  label: const Text('Re-detect type'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.gold,
                    side: const BorderSide(color: AppTheme.border2),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ],
        );
      }),
    );
  }
}

class _ScorePill extends StatelessWidget {
  const _ScorePill({required this.score});
  final int score;

  @override
  Widget build(BuildContext context) {
    final color = score >= 75
        ? AppTheme.olive
        : score >= 40
            ? AppTheme.gold
            : AppTheme.textM;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.insights, size: 12, color: color),
          const SizedBox(width: 4),
          Text('Quality $score/100', style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 3. Taxonomy — type/rarity (read-only badges) + subclass + tags
// ─────────────────────────────────────────────────────────────────────────────

class TaxonomySection extends StatelessWidget {
  const TaxonomySection({super.key, required this.controller});
  final CardEditorController controller;

  @override
  Widget build(BuildContext context) {
    return EditorSection(
      title: 'Taxonomy',
      subtitle: 'Type, subclass, rarity, and tags',
      icon: Icons.category_outlined,
      child: Obx(() {
        final a = controller.draft.value;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: _ReadonlyBadge(
                    label: 'TYPE',
                    value: a.characterType.displayName,
                    color: a.characterType.primaryColor,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ReadonlyBadge(
                    label: 'RARITY',
                    value: a.rarity.name.toUpperCase(),
                    color: a.rarity.color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Text(
                'Type and rarity are computed from the prompt — edit it then press Re-detect.',
                style: TextStyle(color: AppTheme.textM, fontSize: 10, fontStyle: FontStyle.italic),
              ),
            ),
            const SizedBox(height: 8),
            EditSubclassPicker(
              type: a.characterType,
              value: a.subclass,
              onChanged: (s) => controller.updateField((d) => d.copyWith(subclass: s)),
            ),
            const SizedBox(height: 12),
            EditTagChips(
              label: 'TAGS',
              values: a.tags,
              maxItems: 10,
              maxItemLength: 30,
              onChanged: (v) => controller.updateField((d) => d.copyWith(tags: v)),
            ),
            const SizedBox(height: 12),
            EditTagChips(
              label: 'TRAITS',
              values: a.traits,
              maxItems: 12,
              maxItemLength: 40,
              hint: 'e.g. patient, analytical, witty',
              onChanged: (v) => controller.updateField((d) => d.copyWith(traits: v)),
            ),
          ],
        );
      }),
    );
  }
}

class _ReadonlyBadge extends StatelessWidget {
  const _ReadonlyBadge({required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: AppTheme.textM, fontSize: 9, fontWeight: FontWeight.w600, letterSpacing: 0.6)),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w700),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 4. Stats — read-only readout. Computed by the analysis pipeline; not editable.
// ─────────────────────────────────────────────────────────────────────────────

class StatsSection extends StatelessWidget {
  const StatsSection({super.key, required this.controller});
  final CardEditorController controller;

  @override
  Widget build(BuildContext context) {
    return EditorSection(
      title: 'Stats',
      subtitle: 'Computed from prompt analysis — read-only',
      icon: Icons.bar_chart,
      initiallyExpanded: false,
      child: Obx(() {
        final a = controller.draft.value;
        if (a.stats.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'No stats yet. They appear after the analysis pipeline runs at creation or on regenerate.',
              style: TextStyle(color: AppTheme.textM, fontSize: 12, fontStyle: FontStyle.italic),
            ),
          );
        }
        final keys = a.stats.keys.toList()..sort();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _ReadonlyHint(
              text: 'Stats reflect the agent\'s analysed strengths. Edit the prompt and Regenerate Art to recompute them.',
            ),
            const SizedBox(height: 12),
            ...keys.map((key) => _ReadonlyStatRow(
                  statKey: key,
                  value: a.stats[key] ?? 0,
                )),
          ],
        );
      }),
    );
  }
}

class _ReadonlyHint extends StatelessWidget {
  const _ReadonlyHint({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.card2,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lock_outline, size: 13, color: AppTheme.textM),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: const TextStyle(color: AppTheme.textM, fontSize: 11, height: 1.4)),
          ),
        ],
      ),
    );
  }
}

class _ReadonlyStatRow extends StatelessWidget {
  const _ReadonlyStatRow({required this.statKey, required this.value});
  final String statKey;
  final int value;

  @override
  Widget build(BuildContext context) {
    final ratio = (value.clamp(0, 100)) / 100.0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(
              _humanize(statKey),
              style: const TextStyle(color: AppTheme.textB, fontSize: 12, fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: Stack(children: [
                Container(height: 6, color: AppTheme.card2),
                FractionallySizedBox(
                  widthFactor: ratio,
                  child: Container(
                    height: 6,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [
                        AppTheme.gold.withValues(alpha: 0.6),
                        AppTheme.gold,
                      ]),
                    ),
                  ),
                ),
              ]),
            ),
          ),
          SizedBox(
            width: 36,
            child: Text(
              '$value',
              textAlign: TextAlign.right,
              style: const TextStyle(color: AppTheme.gold, fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  static String _humanize(String key) {
    if (key.isEmpty) return key;
    return key
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 5. Narrative — mood and role/purpose blurbs
// ─────────────────────────────────────────────────────────────────────────────

class NarrativeSection extends StatelessWidget {
  const NarrativeSection({super.key, required this.controller});
  final CardEditorController controller;

  @override
  Widget build(BuildContext context) {
    return EditorSection(
      title: 'Narrative',
      subtitle: 'How the character feels and what they do',
      icon: Icons.auto_stories,
      initiallyExpanded: false,
      child: Obx(() {
        final a = controller.draft.value;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            EditLongText(
              label: 'MOOD',
              value: a.profileMood ?? '',
              minLines: 2,
              maxLines: 4,
              maxLength: 200,
              hint: 'e.g. quietly confident, warmly inquisitive',
              onChanged: (v) => controller.updateField(
                (d) => d.copyWith(profileMood: v.isEmpty ? null : v),
              ),
            ),
            const SizedBox(height: 12),
            EditLongText(
              label: 'ROLE / PURPOSE',
              value: a.profileRolePurpose ?? '',
              minLines: 2,
              maxLines: 6,
              maxLength: 400,
              hint: 'What problem does this agent solve, and for whom?',
              onChanged: (v) => controller.updateField(
                (d) => d.copyWith(profileRolePurpose: v.isEmpty ? null : v),
              ),
            ),
          ],
        );
      }),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 6. Visuals — card layout version + price + regenerate art
// ─────────────────────────────────────────────────────────────────────────────

class VisualsSection extends StatelessWidget {
  const VisualsSection({super.key, required this.controller});
  final CardEditorController controller;

  @override
  Widget build(BuildContext context) {
    return EditorSection(
      title: 'Visuals & Pricing',
      subtitle: 'Card layout, list price, and avatar regeneration',
      icon: Icons.palette_outlined,
      initiallyExpanded: false,
      child: Obx(() {
        final a = controller.draft.value;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'CARD LAYOUT',
              style: TextStyle(color: AppTheme.textB, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.6),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: _LayoutOption(
                    label: 'Classic (1.0)',
                    description: 'Gradient banner + pixel portrait',
                    selected: a.cardVersion == '1.0',
                    onTap: () => controller.updateField((d) => d.copyWith(cardVersion: '1.0')),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _LayoutOption(
                    label: 'Scene (2.0)',
                    description: 'Background + portrait overlay',
                    selected: a.cardVersion == '2.0',
                    onTap: () => controller.updateField((d) => d.copyWith(cardVersion: '2.0')),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _PriceField(controller: controller, currentPrice: a.price),
            const SizedBox(height: 16),
            _RegenerateArtButton(controller: controller),
          ],
        );
      }),
    );
  }
}

class _LayoutOption extends StatelessWidget {
  const _LayoutOption({
    required this.label,
    required this.description,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String description;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: selected ? AppTheme.gold.withValues(alpha: 0.12) : AppTheme.card2,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? AppTheme.gold : AppTheme.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: selected ? AppTheme.textH : AppTheme.textB,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 2),
            Text(description, style: const TextStyle(color: AppTheme.textM, fontSize: 10)),
          ],
        ),
      ),
    );
  }
}

class _PriceField extends StatelessWidget {
  const _PriceField({required this.controller, required this.currentPrice});
  final CardEditorController controller;
  final double currentPrice;

  @override
  Widget build(BuildContext context) {
    final asText = currentPrice == 0 ? '' : currentPrice.toStringAsFixed(2);
    return EditTextField(
      label: 'PRICE (MON, 0 = free)',
      value: asText,
      hint: '0.00',
      onChanged: (raw) {
        final parsed = double.tryParse(raw.trim());
        if (parsed == null && raw.trim().isNotEmpty) return; // ignore garbage
        final next = parsed ?? 0.0;
        if (next == controller.draft.value.price) return;
        controller.updateField((d) => d.copyWith(price: next));
      },
    );
  }
}

class _RegenerateArtButton extends StatelessWidget {
  const _RegenerateArtButton({required this.controller});
  final CardEditorController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final loading = controller.isRegeneratingImage.value;
      return Tooltip(
        message: 'Calls /agents/:id/regenerate-image — costs credits and is rate-limited to once per 24h.',
        child: OutlinedButton.icon(
          onPressed: loading
              ? null
              : () async {
                  final messenger = ScaffoldMessenger.of(context);
                  final res = await controller.regenerateImage();
                  if (!context.mounted) return;
                  messenger.showSnackBar(SnackBar(
                    content: Text(res.message ?? (res.ok ? 'Done' : 'Failed')),
                    backgroundColor: res.ok ? AppTheme.olive : AppTheme.error,
                  ));
                },
          icon: loading
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.gold),
                )
              : const Icon(Icons.auto_awesome, size: 16),
          label: Text(loading ? 'Regenerating…' : 'Regenerate art'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.gold,
            side: const BorderSide(color: AppTheme.gold),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          ),
        ),
      );
    });
  }
}
