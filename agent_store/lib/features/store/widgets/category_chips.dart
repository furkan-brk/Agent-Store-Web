// lib/features/store/widgets/category_chips.dart

import 'package:flutter/material.dart';
import '../../../app/theme.dart';

/// Horizontal inline category filter chips.
/// Replaces the old 180px CategorySidebar with a compact Wrap row.
class CategoryChips extends StatelessWidget {
  final List<Map<String, dynamic>> categories;
  final String selectedCategory;
  final ValueChanged<String> onSelect;

  const CategoryChips({
    super.key,
    required this.categories,
    required this.selectedCategory,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    // Compute total count for "All Agents" chip
    int totalCount = 0;
    for (final cat in categories) {
      totalCount += (cat['count'] as int? ?? 0);
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        // "All Agents" always first
        _CategoryChip(
          label: 'All Agents',
          count: totalCount,
          isSelected: selectedCategory.isEmpty,
          onTap: () => onSelect(''),
        ),
        // Dynamic categories from backend
        ...categories.map((cat) {
          final key = cat['key'] as String? ?? '';
          final label = cat['label'] as String? ?? key;
          final count = cat['count'] as int? ?? 0;
          return _CategoryChip(
            label: label,
            count: count,
            isSelected: selectedCategory == key,
            onTap: () => onSelect(key),
          );
        }),
      ],
    );
  }
}

class _CategoryChip extends StatefulWidget {
  final String label;
  final int count;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.count,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_CategoryChip> createState() => _CategoryChipState();
}

class _CategoryChipState extends State<_CategoryChip> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final isActive = widget.isSelected;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isActive
                ? AppTheme.primary.withValues(alpha: 0.18)
                : _hovered
                    ? AppTheme.card2
                    : AppTheme.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isActive
                  ? AppTheme.primary
                  : _hovered
                      ? AppTheme.border2
                      : AppTheme.border,
              width: isActive ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.label,
                style: TextStyle(
                  color: isActive
                      ? AppTheme.textH
                      : _hovered
                          ? AppTheme.textB
                          : AppTheme.textM,
                  fontSize: 12,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isActive
                      ? AppTheme.primary.withValues(alpha: 0.25)
                      : AppTheme.border.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${widget.count}',
                  style: TextStyle(
                    color: isActive ? AppTheme.gold : AppTheme.textM,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
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
