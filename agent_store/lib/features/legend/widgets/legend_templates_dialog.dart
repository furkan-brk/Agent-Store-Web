// lib/features/legend/widgets/legend_templates_dialog.dart

import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../data/legend_templates.dart';
import '../models/workflow_models.dart';

class LegendTemplatesDialog extends StatelessWidget {
  final Function(LegendWorkflow) onTemplateSelected;

  const LegendTemplatesDialog({
    super.key,
    required this.onTemplateSelected,
  });

  @override
  Widget build(BuildContext context) {
    final templates = LegendTemplates.all();
    return Dialog(
      backgroundColor: AppTheme.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppTheme.border),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 520),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  const Icon(Icons.auto_awesome_mosaic,
                      color: AppTheme.gold, size: 20),
                  const SizedBox(width: 10),
                  const Text(
                    'Workflow Templates',
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
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Pick a template to start with, then customize it on the canvas.',
                style: TextStyle(color: AppTheme.textM, fontSize: 12),
              ),
              const SizedBox(height: 16),
              // Grid
              Expanded(
                child: GridView.builder(
                  itemCount: templates.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 2.4,
                  ),
                  itemBuilder: (_, i) =>
                      _TemplateCard(
                        template: templates[i],
                        onTap: () {
                          Navigator.pop(context);
                          onTemplateSelected(templates[i].build());
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

class _TemplateCard extends StatefulWidget {
  final WorkflowTemplate template;
  final VoidCallback onTap;

  const _TemplateCard({required this.template, required this.onTap});

  @override
  State<_TemplateCard> createState() => _TemplateCardState();
}

class _TemplateCardState extends State<_TemplateCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
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
              color: _hovered ? AppTheme.gold.withValues(alpha: 0.5) : AppTheme.border,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.template.icon, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      widget.template.name,
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
                      widget.template.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: AppTheme.textM, fontSize: 10.5, height: 1.4),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${widget.template.nodeCount} nodes',
                      style: TextStyle(
                          color: AppTheme.gold.withValues(alpha: 0.8),
                          fontSize: 10,
                          fontWeight: FontWeight.w500),
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
