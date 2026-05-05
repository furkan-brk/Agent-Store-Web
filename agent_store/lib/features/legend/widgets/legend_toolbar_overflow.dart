// lib/features/legend/widgets/legend_toolbar_overflow.dart
//
// v3.12 (PR 2 / FIX 5) — Toolbar overflow menu used by LegendScreen on
// viewports below 1100px. Pre-fix, the legend toolbar wrapped its 12-button
// secondary cluster in a `SingleChildScrollView(reverse: true)` so on
// iPad-landscape (1024px) the user saw rightmost buttons (Clear / ?) and
// had to scroll LEFT to find the primary Execute CTA.
//
// The screen now collapses these 12 buttons into this overflow menu and
// keeps Execute pinned to the trailing edge OUTSIDE any scroll view.
//
// Pattern reference: missions_screen.dart desktop-icon-row /
// mobile-PopupMenu split.

import 'package:flutter/material.dart';

import '../../../app/theme.dart';

/// Data holder for an item that may render either as an inline toolbar
/// button (wide viewport) or as a row in the overflow PopupMenu
/// (narrow viewport).
class LegendToolbarOverflowItem {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool disabled;

  const LegendToolbarOverflowItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.disabled = false,
  });
}

/// Trigger button + dropdown menu rendering each item as a row.
class LegendToolbarOverflowMenu extends StatelessWidget {
  final List<LegendToolbarOverflowItem> items;

  const LegendToolbarOverflowMenu({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Tooltip(
        message: 'More tools',
        child: PopupMenuButton<int>(
          tooltip: '',
          color: AppTheme.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: AppTheme.border),
          ),
          // Keep the trigger compact and styled like a _ToolbarButton.
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.card,
              borderRadius: BorderRadius.circular(6),
              border:
                  Border.all(color: AppTheme.textB.withValues(alpha: 0.25)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.more_horiz, size: 14, color: AppTheme.textB),
                SizedBox(width: 5),
                Text('Tools',
                    style: TextStyle(
                        color: AppTheme.textB,
                        fontSize: 12,
                        fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          onSelected: (i) {
            final item = items[i];
            if (!item.disabled) item.onTap();
          },
          itemBuilder: (_) => [
            for (var i = 0; i < items.length; i++)
              PopupMenuItem<int>(
                value: i,
                enabled: !items[i].disabled,
                child: Row(
                  children: [
                    Icon(items[i].icon,
                        size: 16,
                        color: items[i].disabled
                            ? AppTheme.textM.withValues(alpha: 0.5)
                            : AppTheme.textH),
                    const SizedBox(width: 10),
                    Text(items[i].label,
                        style: TextStyle(
                            color: items[i].disabled
                                ? AppTheme.textM.withValues(alpha: 0.5)
                                : AppTheme.textH,
                            fontSize: 13)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Shared breakpoint constant — the toolbar collapses to overflow at or
/// below this width. Exposed so tests can pin both the contract and the
/// trigger value in one place.
const double kLegendToolbarCollapseWidth = 1100;

/// Returns true when the toolbar should collapse its secondary cluster.
/// `isMobile` short-circuits to true regardless of width.
bool legendToolbarShouldCollapse(double screenWidth, {bool isMobile = false}) {
  return isMobile || screenWidth < kLegendToolbarCollapseWidth;
}
