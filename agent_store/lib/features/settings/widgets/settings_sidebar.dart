// lib/features/settings/widgets/settings_sidebar.dart
//
// 4-section nav strip used by all Settings sub-screens. Renders as a
// vertical sidebar on wide layouts and a horizontal scrollable tab
// strip on narrow viewports (mirrors the AppShell's 768px split via
// responsive_layout helpers).

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../../shared/widgets/responsive_layout.dart';

class _SettingsSection {
  final String path;
  final IconData icon;
  final String Function(AppLocalizations l) labelOf;

  const _SettingsSection({
    required this.path,
    required this.icon,
    required this.labelOf,
  });
}

final List<_SettingsSection> _sections = [
  _SettingsSection(
    path: '/settings',
    icon: Icons.person_outline,
    labelOf: (l) => l.profileSection,
  ),
  _SettingsSection(
    path: '/settings/notifications',
    icon: Icons.notifications_outlined,
    labelOf: (l) => l.notificationsSection,
  ),
  _SettingsSection(
    path: '/settings/appearance',
    icon: Icons.palette_outlined,
    labelOf: (l) => l.appearanceSection,
  ),
  _SettingsSection(
    path: '/settings/developer',
    icon: Icons.code_rounded,
    labelOf: (l) => l.developerSection,
  ),
];

class SettingsSidebar extends StatelessWidget {
  /// FE-P1-14: when non-null, used in place of `GoRouterState.of(context)`.
  /// Lets widget tests mount this without a real GoRouter wrapper.
  /// Production callers leave it null.
  final String? currentPath;

  const SettingsSidebar({super.key, this.currentPath});

  bool _isSelected(String currentLoc, String path) {
    if (path == '/settings') {
      // Profile is the index — only highlight when nothing more specific
      // matches.
      return currentLoc == '/settings';
    }
    return currentLoc == path || currentLoc.startsWith('$path/');
  }

  @override
  Widget build(BuildContext context) {
    final loc = currentPath ?? GoRouterState.of(context).uri.toString();
    final l = AppLocalizations.of(context);
    final narrow = isNarrow(context);

    if (narrow) {
      // Horizontal scroll strip — fits naturally above the section body
      // when stacked vertically by SettingsLayout.
      return Container(
        height: 56,
        decoration: const BoxDecoration(
          color: AppTheme.surface,
          border: Border(
            bottom: BorderSide(color: AppTheme.border),
          ),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: _sections.map((s) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: _NavChip(
                  icon: s.icon,
                  label: s.labelOf(l),
                  selected: _isSelected(loc, s.path),
                  onTap: () => context.go(s.path),
                ),
              );
            }).toList(),
          ),
        ),
      );
    }

    // Wide: vertical rail.
    return Container(
      width: 220,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 12),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(right: BorderSide(color: AppTheme.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: _sections.map((s) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: _NavRow(
              icon: s.icon,
              label: s.labelOf(l),
              selected: _isSelected(loc, s.path),
              onTap: () => context.go(s.path),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _NavRow extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavRow({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_NavRow> createState() => _NavRowState();
}

class _NavRowState extends State<_NavRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    final color = selected
        ? AppTheme.primary
        : (_hovered ? AppTheme.textH : AppTheme.textM);
    final bg = selected
        ? AppTheme.primary.withValues(alpha: 0.12)
        : (_hovered ? AppTheme.card2 : Colors.transparent);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(8),
            border: selected
                ? const Border(
                    left: BorderSide(color: AppTheme.primary, width: 3),
                  )
                : null,
          ),
          child: Row(children: [
            Icon(widget.icon, size: 18, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                widget.label,
                style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _NavChip extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavChip({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_NavChip> createState() => _NavChipState();
}

class _NavChipState extends State<_NavChip> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    final color = selected
        ? AppTheme.primary
        : (_hovered ? AppTheme.textH : AppTheme.textM);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? AppTheme.primary.withValues(alpha: 0.12)
                : (_hovered ? AppTheme.card2 : AppTheme.card),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected
                  ? AppTheme.primary.withValues(alpha: 0.4)
                  : AppTheme.border,
            ),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(widget.icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(
              widget.label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Reusable shell that lays out a Settings sub-screen with the sidebar
/// (or top tab strip on narrow) plus a scrolling body. Sub-screens just
/// render their content; padding + scroll are owned by this shell.
class SettingsLayout extends StatelessWidget {
  final Widget body;

  /// FE-P1-14: forwarded to [SettingsSidebar] so tests can mount this
  /// without a GoRouter wrapper. Null in production.
  final String? currentPath;

  const SettingsLayout({super.key, required this.body, this.currentPath});

  @override
  Widget build(BuildContext context) {
    final narrow = isNarrow(context);
    if (narrow) {
      return Scaffold(
        backgroundColor: AppTheme.bg,
        body: Column(
          children: [
            SettingsSidebar(currentPath: currentPath),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: body,
              ),
            ),
          ],
        ),
      );
    }
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Row(
        children: [
          SettingsSidebar(currentPath: currentPath),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: body,
            ),
          ),
        ],
      ),
    );
  }
}
