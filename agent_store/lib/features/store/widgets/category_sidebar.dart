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
    'all', 'backend', 'frontend', 'data',
    'security', 'creative', 'business', 'research',
  ];

  static const _icons = {
    'all':      Icons.apps_rounded,
    'backend':  Icons.code_rounded,
    'frontend': Icons.brush_rounded,
    'data':     Icons.bar_chart_rounded,
    'security': Icons.shield_rounded,
    'creative': Icons.auto_awesome_rounded,
    'business': Icons.trending_up_rounded,
    'research': Icons.science_rounded,
  };

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
          // Logo/brand area
          Container(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppTheme.border)),
            ),
            child: Row(children: [
              Container(
                width: 28, height: 28,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppTheme.primary.withValues(alpha: 0.5)),
                ),
                child: const Icon(Icons.bolt, color: AppTheme.primary, size: 16),
              ),
              const SizedBox(width: 8),
              const Text(
                'Agent Store',
                style: TextStyle(
                  color: AppTheme.textH,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.3,
                ),
              ),
            ]),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 18, 16, 8),
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
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 16, left: 8, right: 8),
              itemCount: _categories.length,
              itemBuilder: (_, i) {
                final cat = _categories[i];
                final label = cat == 'all'
                    ? 'All Agents'
                    : cat[0].toUpperCase() + cat.substring(1);
                final isSelected = selectedCategory == (cat == 'all' ? '' : cat);
                final icon = _icons[cat] ?? Icons.apps_rounded;
                return _CategoryItem(
                  icon: icon,
                  label: label,
                  isSelected: isSelected,
                  onTap: () => onSelect(cat == 'all' ? '' : cat),
                );
              },
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
      padding: const EdgeInsets.symmetric(vertical: 2),
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
              border: Border(
                left: BorderSide(
                  color: widget.isSelected
                      ? AppTheme.gold
                      : Colors.transparent,
                  width: 2.5,
                ),
              ),
            ),
            child: Row(
              children: [
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
                Text(
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
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
