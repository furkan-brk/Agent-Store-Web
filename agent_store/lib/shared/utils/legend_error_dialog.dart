import 'package:flutter/material.dart';
import '../../app/theme.dart';

/// Shows an error dialog with a Retry action.
/// Returns `true` if the user pressed Retry, `false` if they dismissed.
Future<bool> showLegendRetryDialog(
  BuildContext context, {
  required String title,
  required String message,
  String retryLabel = 'Retry',
  String cancelLabel = 'Cancel',
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => AlertDialog(
      backgroundColor: AppTheme.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppTheme.border),
      ),
      icon: const Icon(Icons.error_outline_rounded, color: AppTheme.primary, size: 28),
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
            backgroundColor: AppTheme.gold,
            foregroundColor: const Color(0xFF1E1A14),
          ),
          onPressed: () => Navigator.pop(context, true),
          child: Text(retryLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}
