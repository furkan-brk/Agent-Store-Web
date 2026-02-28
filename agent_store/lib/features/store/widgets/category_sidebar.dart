import 'package:flutter/material.dart';

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
    'all':      Icons.apps,
    'backend':  Icons.code,
    'frontend': Icons.brush,
    'data':     Icons.bar_chart,
    'security': Icons.shield,
    'creative': Icons.auto_awesome,
    'business': Icons.trending_up,
    'research': Icons.science,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 180,
      color: const Color(0xFF0F0F1E),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 24, 16, 12),
            child: Text(
              'CATEGORIES',
              style: TextStyle(
                color: Color(0xFF6B7280),
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 16),
              itemCount: _categories.length,
              itemBuilder: (_, i) {
                final cat = _categories[i];
                final label = cat == 'all'
                    ? 'All'
                    : cat[0].toUpperCase() + cat.substring(1);
                final isSelected = selectedCategory == (cat == 'all' ? '' : cat);
                final icon = _icons[cat] ?? Icons.apps;
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

class _CategoryItem extends StatelessWidget {
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

  static const _highlight = Color(0xFF6366F1);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            color: isSelected
                ? _highlight.withValues(alpha: 0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected
                  ? _highlight.withValues(alpha: 0.4)
                  : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: isSelected ? _highlight : const Color(0xFF6B7280),
                size: 18,
              ),
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? _highlight : const Color(0xFF9CA3AF),
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
