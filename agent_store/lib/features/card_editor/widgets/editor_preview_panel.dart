import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/theme.dart';
import '../../store/widgets/agent_card.dart';
import '../controllers/card_editor_controller.dart';

enum PreviewSize { small, medium, large }

extension on PreviewSize {
  double get width => switch (this) {
        PreviewSize.small => 240,
        PreviewSize.medium => 300,
        PreviewSize.large => 360,
      };
  String get label => switch (this) {
        PreviewSize.small => 'S',
        PreviewSize.medium => 'M',
        PreviewSize.large => 'L',
      };
}

/// Right-hand preview panel. Renders the live [AgentCard] inside a
/// [RepaintBoundary] (whose key is exposed via [boundaryKey] so the
/// export service can capture it as PNG).
class EditorPreviewPanel extends StatefulWidget {
  const EditorPreviewPanel({
    super.key,
    required this.controller,
    required this.boundaryKey,
  });

  final CardEditorController controller;
  final GlobalKey boundaryKey;

  @override
  State<EditorPreviewPanel> createState() => _EditorPreviewPanelState();
}

class _EditorPreviewPanelState extends State<EditorPreviewPanel> {
  PreviewSize _size = PreviewSize.medium;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.bg,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _SizeToggle(
            current: _size,
            onChanged: (s) => setState(() => _size = s),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                child: Obx(() {
                  return RepaintBoundary(
                    key: widget.boundaryKey,
                    child: Container(
                      // The card has a transparent rounded corner — paint
                      // a matching background so PNG exports don't get
                      // weird edge anti-aliasing on light viewers.
                      color: AppTheme.bg,
                      padding: const EdgeInsets.all(8),
                      child: SizedBox(
                        width: _size.width,
                        child: AgentCard(
                          agent: widget.controller.draft.value,
                          isOwned: true,
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const _LivePreviewHint(),
        ],
      ),
    );
  }
}

class _SizeToggle extends StatelessWidget {
  const _SizeToggle({required this.current, required this.onChanged});
  final PreviewSize current;
  final ValueChanged<PreviewSize> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.card2,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: PreviewSize.values.map((s) {
          final selected = s == current;
          return InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => onChanged(s),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: selected ? AppTheme.primary.withValues(alpha: 0.2) : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                s.label,
                style: TextStyle(
                  color: selected ? AppTheme.textH : AppTheme.textM,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 12,
                ),
              ),
            ),
          );
        }).toList(growable: false),
      ),
    );
  }
}

class _LivePreviewHint extends StatelessWidget {
  const _LivePreviewHint();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.flash_on, size: 12, color: AppTheme.olive.withValues(alpha: 0.7)),
        const SizedBox(width: 4),
        Text(
          'Live preview · changes save automatically',
          style: TextStyle(color: AppTheme.textM.withValues(alpha: 0.8), fontSize: 10),
        ),
      ],
    );
  }
}
