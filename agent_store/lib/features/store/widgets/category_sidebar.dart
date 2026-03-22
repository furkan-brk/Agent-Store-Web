// lib/features/store/widgets/category_sidebar.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../app/theme.dart';
import '../../../controllers/store_controller.dart';

/// Persistent left sidebar (200px) for desktop store layout.
/// Shows categories from [StoreController] with selected-state accent bar.
class StoreCategorySidebar extends StatelessWidget {
  const StoreCategorySidebar({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<StoreController>();

    return Container(
      width: 200,
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(
          right: BorderSide(color: AppTheme.border, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          // Section header
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'CATEGORIES',
              style: TextStyle(
                color: AppTheme.textM,
                fontSize: 10,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 4),
          // Category list
          Expanded(
            child: Obx(() {
              final categories = ctrl.categories;
              // Compute total count for "All" item
              int totalCount = 0;
              for (final cat in categories) {
                totalCount += (cat['count'] as int? ?? 0);
              }

              return ListView(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                children: [
                  // "All" category always first
                  _CategoryItem(
                    icon: Icons.apps_rounded,
                    label: 'All Agents',
                    count: totalCount,
                    isSelected: ctrl.category.value.isEmpty,
                    onTap: () => ctrl.setCategory(''),
                  ),
                  // Dynamic categories from backend
                  ...categories.map((cat) {
                    final key = cat['key'] as String? ?? '';
                    final label = cat['label'] as String? ?? key;
                    final count = cat['count'] as int? ?? 0;
                    return _CategoryItem(
                      icon: _categoryIcon(key),
                      label: label,
                      count: count,
                      isSelected: ctrl.category.value == key,
                      onTap: () => ctrl.setCategory(key),
                    );
                  }),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  static IconData _categoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'backend':
        return Icons.code_rounded;
      case 'frontend':
        return Icons.palette_rounded;
      case 'data':
        return Icons.bar_chart_rounded;
      case 'security':
        return Icons.shield_rounded;
      case 'creative':
        return Icons.auto_awesome_rounded;
      case 'business':
      case 'marketing':
        return Icons.business_center_rounded;
      case 'research':
        return Icons.science_rounded;
      case 'planning':
        return Icons.map_rounded;
      default:
        return Icons.auto_awesome_rounded;
    }
  }
}

/// Single row in the category sidebar with icon, label, count badge,
/// and a left accent bar when selected.
class _CategoryItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final int count;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryItem({
    required this.icon,
    required this.label,
    required this.count,
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
    final isActive = widget.isSelected;

    // Colors based on state
    final Color textColor;
    final Color iconColor;
    final Color bgColor;

    if (isActive) {
      textColor = AppTheme.primary;
      iconColor = AppTheme.primary;
      bgColor = AppTheme.primary.withValues(alpha: 0.12);
    } else if (_hovered) {
      textColor = AppTheme.textH;
      iconColor = AppTheme.textB;
      bgColor = AppTheme.card2.withValues(alpha: 0.5);
    } else {
      textColor = AppTheme.textM;
      iconColor = AppTheme.textM;
      bgColor = Colors.transparent;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(8),
              // Left accent bar for selected item
              border: isActive
                  ? const Border(
                      left: BorderSide(color: AppTheme.primary, width: 3),
                    )
                  : null,
            ),
            child: Row(
              children: [
                Icon(widget.icon, size: 16, color: iconColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.label,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 12,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Count badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isActive
                        ? AppTheme.primary.withValues(alpha: 0.2)
                        : AppTheme.border.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${widget.count}',
                    style: TextStyle(
                      color: isActive ? AppTheme.gold : AppTheme.textM,
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                    ),
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
