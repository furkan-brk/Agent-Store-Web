import 'package:flutter/widgets.dart';

import '../../app/theme.dart';

/// Renders a different widget per breakpoint using the existing
/// [AppBreakpoints] thresholds (mobile <600, tablet <1024, desktop ≥1024).
///
/// If [tablet] is omitted, the tablet range falls back to [desktop] —
/// matches the convention used in the existing screens (Legend, Store)
/// where intermediate widths share the desktop layout.
class ResponsiveLayout extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  final Widget desktop;

  const ResponsiveLayout({
    super.key,
    required this.mobile,
    required this.desktop,
    this.tablet,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (_, c) {
      final w = c.maxWidth;
      if (AppBreakpoints.isMobile(w)) return mobile;
      if (AppBreakpoints.isTablet(w)) return tablet ?? desktop;
      return desktop;
    });
  }
}

/// Convenience helper for screens that only need to know "am I narrow?".
/// Returns true for widths below 768px (mid-mobile / tablet portrait), the
/// breakpoint AppShell already uses for its drawer/bottom-nav swap.
bool isNarrow(BuildContext context) =>
    MediaQuery.of(context).size.width < 768;
