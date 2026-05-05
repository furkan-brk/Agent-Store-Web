import 'package:flutter/animation.dart';

/// Centralised animation tokens. Prefer these over ad-hoc Duration literals
/// so we keep timing consistent across hover, page transition, sidebar nav,
/// and chip pulse interactions.
class AppAnimations {
  /// Card / button hover state changes. Short and snappy (also used for
  /// sidebar nav-item highlight transitions).
  static const hoverDuration = Duration(milliseconds: 180);

  /// AnimatedSwitcher between routes — slightly longer than hover so the
  /// page-level fade reads as a distinct transition.
  static const transitionDuration = Duration(milliseconds: 250);

  /// Sidebar nav-item background transition. Mirrors hoverDuration but
  /// named for clarity at call-site.
  static const navItemDuration = Duration(milliseconds: 180);

  /// AnimatedSwitcher between top-level routes inside AppShell.
  static const routeTransition = Duration(milliseconds: 250);

  /// Chip pulse / activation feedback (e.g. filter chip toggle).
  static const chipPulse = Duration(milliseconds: 180);

  static const hoverCurve = Curves.easeInOut;
  static const transitionCurve = Curves.easeOutCubic;
}
