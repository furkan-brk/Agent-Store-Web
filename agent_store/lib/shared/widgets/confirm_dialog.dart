import 'package:flutter/material.dart';
import '../../app/theme.dart';

class ConfirmDialog {
  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = 'Confirm',
    String cancelLabel = 'Cancel',
    bool isDestructive = false,
    IconData? icon,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppTheme.border),
        ),
        icon: icon != null
            ? Icon(icon, color: isDestructive ? AppTheme.primary : AppTheme.gold, size: 28)
            : null,
        title: Text(
          title,
          style: const TextStyle(color: AppTheme.textH, fontWeight: FontWeight.bold),
        ),
        content: Text(
          message,
          style: const TextStyle(color: AppTheme.textB),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(cancelLabel, style: const TextStyle(color: AppTheme.textM)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: isDestructive ? AppTheme.primary : AppTheme.gold,
              foregroundColor: isDestructive ? AppTheme.textH : const Color(0xFF1E1A14),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}
