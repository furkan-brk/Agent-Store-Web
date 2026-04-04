// lib/features/store/widgets/filter_panel.dart

import 'package:flutter/material.dart';
import '../../../app/theme.dart';

class FilterPanel extends StatelessWidget {
  final double minPrice;
  final double maxPrice;
  final double currentMin;
  final double currentMax;
  final List<String> selectedTags;
  final ValueChanged<RangeValues> onPriceChanged;
  final ValueChanged<String> onTagToggled;
  final VoidCallback onReset;

  static const List<String> availableTags = [
    'coding',
    'writing',
    'analysis',
    'planning',
    'security',
    'research',
    'marketing',
    'creative',
  ];

  static const _tagIcons = <String, IconData>{
    'coding': Icons.code_rounded,
    'writing': Icons.edit_note_rounded,
    'analysis': Icons.analytics_rounded,
    'planning': Icons.map_rounded,
    'security': Icons.shield_rounded,
    'research': Icons.science_rounded,
    'marketing': Icons.campaign_rounded,
    'creative': Icons.auto_awesome_rounded,
  };

  const FilterPanel({
    super.key,
    required this.minPrice,
    required this.maxPrice,
    required this.currentMin,
    required this.currentMax,
    required this.selectedTags,
    required this.onPriceChanged,
    required this.onTagToggled,
    required this.onReset,
  });

  String _priceLabel(double v) =>
      v == 0 ? 'Free' : '${v.toStringAsFixed(0)} MON';

  bool get _hasActiveFilters =>
      selectedTags.isNotEmpty ||
      currentMin != minPrice ||
      currentMax != maxPrice;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // -- Price Range ------------------------------------------------
          Row(
            children: [
              const Icon(Icons.monetization_on_outlined,
                  size: 14, color: AppTheme.gold),
              const SizedBox(width: 6),
              const Text(
                'Price Range',
                style: TextStyle(
                  color: AppTheme.textH,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Flexible(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                        color: AppTheme.primary.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    '${_priceLabel(currentMin)} — ${_priceLabel(currentMax)}',
                    style: const TextStyle(
                      color: AppTheme.gold,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: AppTheme.primary,
              inactiveTrackColor: AppTheme.border,
              thumbColor: AppTheme.gold,
              overlayColor: AppTheme.gold.withValues(alpha: 0.15),
              rangeThumbShape:
                  const RoundRangeSliderThumbShape(enabledThumbRadius: 7),
              rangeTrackShape: const RoundedRectRangeSliderTrackShape(),
              rangeValueIndicatorShape:
                  const PaddleRangeSliderValueIndicatorShape(),
              valueIndicatorColor: AppTheme.card2,
              valueIndicatorTextStyle: const TextStyle(
                color: AppTheme.textH,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
              showValueIndicator: ShowValueIndicator.onlyForContinuous,
            ),
            child: RangeSlider(
              values: RangeValues(currentMin, currentMax),
              min: minPrice,
              max: maxPrice,
              divisions: 20,
              labels: RangeLabels(
                _priceLabel(currentMin),
                _priceLabel(currentMax),
              ),
              onChanged: onPriceChanged,
            ),
          ),
          const SizedBox(height: 12),
          // -- Tags -------------------------------------------------------
          const Row(
            children: [
              Icon(Icons.label_outline, size: 14, color: AppTheme.gold),
              SizedBox(width: 6),
              Text(
                'Tags',
                style: TextStyle(
                  color: AppTheme.textH,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: availableTags.map((tag) {
              final selected = selectedTags.contains(tag);
              final icon = _tagIcons[tag] ?? Icons.label_outline;
              return _FilterTag(
                tag: tag,
                icon: icon,
                selected: selected,
                onTap: () => onTagToggled(tag),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),
          // -- Reset ------------------------------------------------------
          Align(
            alignment: Alignment.centerRight,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: _hasActiveFilters ? 1.0 : 0.4,
              child: TextButton.icon(
                onPressed: _hasActiveFilters ? onReset : null,
                icon: const Icon(Icons.refresh, size: 13,
                    color: AppTheme.primary),
                label: const Text(
                  'Reset Filters',
                  style: TextStyle(
                    color: AppTheme.primary,
                    fontSize: 12,
                  ),
                ),
                style: TextButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Individual filter tag chip with hover effect
class _FilterTag extends StatefulWidget {
  final String tag;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _FilterTag({
    required this.tag,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_FilterTag> createState() => _FilterTagState();
}

class _FilterTagState extends State<_FilterTag> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: widget.selected
                ? AppTheme.primary.withValues(alpha: 0.2)
                : _hovered
                    ? AppTheme.card2
                    : AppTheme.card2.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: widget.selected
                  ? AppTheme.primary
                  : _hovered
                      ? AppTheme.border2
                      : AppTheme.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.selected)
                const Padding(
                  padding: EdgeInsets.only(right: 4),
                  child: Icon(Icons.check_rounded,
                      size: 12, color: AppTheme.primary),
                ),
              Icon(
                widget.icon,
                size: 12,
                color: widget.selected ? AppTheme.textH : AppTheme.textM,
              ),
              const SizedBox(width: 5),
              Text(
                widget.tag,
                style: TextStyle(
                  color: widget.selected ? AppTheme.textH : AppTheme.textB,
                  fontSize: 11,
                  fontWeight:
                      widget.selected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
