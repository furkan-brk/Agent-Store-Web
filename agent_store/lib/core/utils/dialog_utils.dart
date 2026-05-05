// lib/core/utils/dialog_utils.dart
//
// v3.12 — Shared dialog sizing helpers.
//
// AlertDialog / SimpleDialog stretch full-width on large desktop monitors
// when their content uses double-bounded constraints. The pattern already
// established in creator_dialogs.dart and developer_screen.dart is to
// clamp the inner SizedBox width to `min(target, screenWidth - 32)` so
// dialogs read comfortably on both phone (~360px) and 4K displays.
//
// This helper centralises that math so future dialogs don't need to import
// `dart:math` ad-hoc and so we can tweak the side margin in one place.

import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Returns the width that a dialog's inner [SizedBox] should clamp to.
///
/// Uses `min(max, screenWidth - 32)` — the 32px margin matches the existing
/// codebase convention (16px gutter on each side).
double dialogMaxWidth(BuildContext context, {double max = 500}) =>
    math.min(max, MediaQuery.of(context).size.width - 32);
