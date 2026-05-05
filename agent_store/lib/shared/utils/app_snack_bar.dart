import 'package:flutter/material.dart';
import '../../app/theme.dart';

class AppSnackBar {
  AppSnackBar._();

  static void show(
    BuildContext context, {
    required String message,
    IconData? icon,
    Color? iconColor,
    Duration duration = const Duration(seconds: 2),
    SnackBarAction? action,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        if (icon != null) ...[
          Icon(icon, color: iconColor ?? AppTheme.textH, size: 18),
          const SizedBox(width: 10),
        ],
        Expanded(child: Text(message)),
      ]),
      duration: duration,
      action: action,
    ));
  }

  static void success(BuildContext context, String message, {SnackBarAction? action}) =>
      show(context, message: message, icon: Icons.check_circle_rounded,
          iconColor: AppTheme.success, action: action);

  static void error(BuildContext context, String message) =>
      show(context, message: message, icon: Icons.error_outline_rounded,
          iconColor: AppTheme.primary);

  static void info(BuildContext context, String message, {SnackBarAction? action}) =>
      show(context, message: message, icon: Icons.info_outline_rounded,
          iconColor: AppTheme.gold, action: action);
}
