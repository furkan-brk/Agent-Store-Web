import 'package:flutter/material.dart';

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

  String _priceLabel(double v) => v == 0 ? 'Free' : '${v.toStringAsFixed(0)} MON';

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFE8DEC9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFC0B490)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Price Range ──────────────────────────────────────────────────
          Row(
            children: [
              const Icon(Icons.monetization_on_outlined,
                  size: 14, color: Color(0xFF6B5A40)),
              const SizedBox(width: 6),
              const Text(
                'Price Range',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                '${_priceLabel(currentMin)} — ${_priceLabel(currentMax)}',
                style: const TextStyle(
                  color: Color(0xFF81231E),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          RangeSlider(
            values: RangeValues(currentMin, currentMax),
            min: minPrice,
            max: maxPrice,
            divisions: 20,
            activeColor: const Color(0xFF81231E),
            inactiveColor: const Color(0xFFC0B490),
            labels: RangeLabels(
              _priceLabel(currentMin),
              _priceLabel(currentMax),
            ),
            onChanged: onPriceChanged,
          ),
          const SizedBox(height: 12),
          // ── Tags ─────────────────────────────────────────────────────────
          const Row(
            children: [
              Icon(Icons.label_outline, size: 14, color: Color(0xFF6B5A40)),
              SizedBox(width: 6),
              Text(
                'Tags',
                style: TextStyle(
                  color: Colors.white,
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
              return FilterChip(
                label: Text(tag),
                selected: selected,
                onSelected: (_) => onTagToggled(tag),
                backgroundColor: const Color(0xFFB8AA88),
                selectedColor: const Color(0xFF81231E),
                checkmarkColor: Colors.white,
                labelStyle: TextStyle(
                  color: selected ? Colors.white : const Color(0xFF6B5A40),
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                ),
                side: BorderSide(
                  color: selected
                      ? const Color(0xFF81231E)
                      : const Color(0xFFC0B490),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                visualDensity: VisualDensity.compact,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          // ── Reset ─────────────────────────────────────────────────────────
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onReset,
              icon: const Icon(Icons.refresh, size: 13,
                  color: Color(0xFF81231E)),
              label: const Text(
                'Reset Filters',
                style: TextStyle(
                  color: Color(0xFF81231E),
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
        ],
      ),
    );
  }
}
