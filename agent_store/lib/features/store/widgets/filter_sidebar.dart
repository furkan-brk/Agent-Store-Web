// lib/features/store/widgets/filter_sidebar.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../app/theme.dart';
import '../../../controllers/store_controller.dart';

/// Persistent right sidebar (180px) for desktop store layout — Sort By only.
class StoreFilterSidebar extends StatelessWidget {
  const StoreFilterSidebar({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<StoreController>();

    return Container(
      width: 180,
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(
          left: BorderSide(color: AppTheme.border, width: 1),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: _SidebarSortDropdown(ctrl: ctrl),
      ),
    );
  }
}

class _SidebarSortDropdown extends StatelessWidget {
  final StoreController ctrl;
  const _SidebarSortDropdown({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Row(
          children: [
            Icon(Icons.sort_rounded, size: 14, color: AppTheme.gold),
            SizedBox(width: 6),
            Text(
              'Sort By',
              style: TextStyle(
                color: AppTheme.textH,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Obx(() => Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.border),
          ),
          child: DropdownButton<String>(
            value: ctrl.sort.value,
            dropdownColor: AppTheme.card2,
            underline: const SizedBox(),
            isExpanded: true,
            icon: const Icon(Icons.expand_more_rounded, color: AppTheme.textM, size: 18),
            style: const TextStyle(color: AppTheme.textH, fontSize: 12),
            items: const [
              DropdownMenuItem(value: 'newest',     child: _SortItem(icon: Icons.schedule_rounded,       label: 'Newest')),
              DropdownMenuItem(value: 'popular',    child: _SortItem(icon: Icons.trending_up_rounded,    label: 'Popular')),
              DropdownMenuItem(value: 'saves',      child: _SortItem(icon: Icons.bookmark_rounded,       label: 'Most Saved')),
              DropdownMenuItem(value: 'price_asc',  child: _SortItem(icon: Icons.arrow_upward_rounded,   label: 'Price Low')),
              DropdownMenuItem(value: 'price_desc', child: _SortItem(icon: Icons.arrow_downward_rounded, label: 'Price High')),
              DropdownMenuItem(value: 'oldest',     child: _SortItem(icon: Icons.history_rounded,        label: 'Oldest')),
            ],
            onChanged: (v) {
              if (v != null) {
                ctrl.sort.value = v;
                ctrl.load();
              }
            },
          ),
        )),
      ],
    );
  }
}

class _SortItem extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SortItem({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 14, color: AppTheme.textM),
      const SizedBox(width: 6),
      Text(label),
    ],
  );
}
