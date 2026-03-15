// lib/features/store/widgets/category_sidebar.dart

import 'package:flutter/material.dart';
import '../../../app/theme.dart';

class CategorySidebar extends StatelessWidget {
  final String selectedCategory;
  final ValueChanged<String> onSelect;

  const CategorySidebar({
    super.key,
    required this.selectedCategory,
    required this.onSelect,
  });

  static const _categories = [
    ('all', 'All Agents', Icons.apps_rounded),
    ('backend', 'Backend', Icons.code_rounded),
    ('planning', 'Planning', Icons.map_rounded),
    ('frontend', 'Frontend', Icons.palette_rounded),
    ('data', 'Data', Icons.bar_chart_rounded),
    ('security', 'Security', Icons.shield_rounded),
    ('creative', 'Creative', Icons.auto_awesome_rounded),
    ('research', 'Research', Icons.science_rounded),
    ('business', 'Business', Icons.business_center_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 180,
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(right: BorderSide(color: AppTheme.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 24, 16, 4),
            child: Text(
              'CATEGORIES',
              style: TextStyle(
                color: AppTheme.textM,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Divider(color: AppTheme.border, height: 16),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 16, left: 8, right: 8),
              itemCount: _categories.length,
              itemBuilder: (_, i) {
                final (key, label, icon) = _categories[i];
                final isSelected =
                    selectedCategory == (key == 'all' ? '' : key);
                return _CategoryItem(
                  icon: icon,
                  label: label,
                  isSelected: isSelected,
                  onTap: () => onSelect(key == 'all' ? '' : key),
                );
              },
            ),
          ),
          // Agent count footer
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppTheme.border)),
            ),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: AppTheme.olive,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.olive.withValues(alpha: 0.5),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Store Online',
                  style: TextStyle(
                    color: AppTheme.textM,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_CategoryItem> createState() => _CategoryItemState();
}

class _CategoryItemState extends State<_CategoryItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.isSelected || _hovered;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            decoration: BoxDecoration(
              color: widget.isSelected
                  ? AppTheme.primary.withValues(alpha: 0.15)
                  : _hovered
                      ? AppTheme.card2.withValues(alpha: 0.8)
                      : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                // Left indicator bar for selected state
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 3,
                  height: 18,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: widget.isSelected
                        ? AppTheme.gold
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Icon(
                  widget.icon,
                  color: widget.isSelected
                      ? AppTheme.gold
                      : active
                          ? AppTheme.textB
                          : AppTheme.textM,
                  size: 16,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.label,
                    style: TextStyle(
                      color: widget.isSelected
                          ? AppTheme.textH
                          : active
                              ? AppTheme.textB
                              : AppTheme.textM,
                      fontSize: 12,
                      fontWeight: widget.isSelected
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Subtle arrow for selected
                if (widget.isSelected)
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppTheme.gold,
                    size: 14,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
