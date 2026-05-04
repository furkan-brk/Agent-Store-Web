// lib/features/create_agent/widgets/prompt_templates_dialog.dart
//
// Modal dialog that lets the user pick a starter prompt template. Pattern
// mirrors `legend_templates_dialog.dart` (v3.3) — MouseRegion + 150ms
// AnimatedContainer with the AppTheme.gold 0.08 alpha hover treatment.

import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../data/prompt_templates.dart';

class PromptTemplatesDialog extends StatefulWidget {
  /// Called with the selected template after the dialog dismisses.
  /// The caller is responsible for filling the form fields.
  final ValueChanged<PromptTemplate> onTemplateSelected;

  const PromptTemplatesDialog({super.key, required this.onTemplateSelected});

  @override
  State<PromptTemplatesDialog> createState() => _PromptTemplatesDialogState();
}

class _PromptTemplatesDialogState extends State<PromptTemplatesDialog> {
  String _category = 'All';

  List<String> get _categories {
    final cats = <String>{'All'};
    for (final t in promptTemplates) {
      cats.add(t.category);
    }
    return cats.toList();
  }

  List<PromptTemplate> get _filtered {
    if (_category == 'All') return promptTemplates;
    return promptTemplates.where((t) => t.category == _category).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppTheme.border),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 560),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  const Icon(Icons.auto_awesome_mosaic_rounded,
                      color: AppTheme.gold, size: 20),
                  const SizedBox(width: 10),
                  const Text(
                    'Prompt Templates',
                    style: TextStyle(
                      color: AppTheme.textH,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close,
                        color: AppTheme.textM, size: 18),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                        minWidth: 28, minHeight: 28),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Pick a starter prompt — you can edit it after it\'s injected.',
                style: TextStyle(color: AppTheme.textM, fontSize: 12),
              ),
              const SizedBox(height: 14),

              // Category filter chips
              SizedBox(
                height: 30,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _categories.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final cat = _categories[i];
                    final selected = _category == cat;
                    return _CategoryChip(
                      label: cat,
                      selected: selected,
                      onTap: () => setState(() => _category = cat),
                    );
                  },
                ),
              ),
              const SizedBox(height: 14),

              // Grid
              Expanded(
                child: GridView.builder(
                  itemCount: _filtered.length,
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 2.2,
                  ),
                  itemBuilder: (_, i) => _TemplateCard(
                    template: _filtered[i],
                    onTap: () {
                      Navigator.pop(context);
                      widget.onTemplateSelected(_filtered[i]);
                    },
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

// ── Category chip ────────────────────────────────────────────────────────────

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: selected
                ? AppTheme.gold.withValues(alpha: 0.15)
                : AppTheme.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? AppTheme.gold : AppTheme.border,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? AppTheme.gold : AppTheme.textM,
              fontSize: 12,
              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Template card ────────────────────────────────────────────────────────────

class _TemplateCard extends StatefulWidget {
  final PromptTemplate template;
  final VoidCallback onTap;

  const _TemplateCard({required this.template, required this.onTap});

  @override
  State<_TemplateCard> createState() => _TemplateCardState();
}

class _TemplateCardState extends State<_TemplateCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.template;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: _hovered
                ? AppTheme.gold.withValues(alpha: 0.08)
                : AppTheme.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _hovered
                  ? AppTheme.gold.withValues(alpha: 0.5)
                  : AppTheme.border,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(t.icon, size: 22, color: AppTheme.gold),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      t.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.textH,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      t.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.textM,
                        fontSize: 10.5,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: t.tagSuggestions
                          .take(3)
                          .map((tag) => Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color:
                                      AppTheme.card2.withValues(alpha: 0.6),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  tag,
                                  style: const TextStyle(
                                    color: AppTheme.textM,
                                    fontSize: 9,
                                  ),
                                ),
                              ))
                          .toList(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
