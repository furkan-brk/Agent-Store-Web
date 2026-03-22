import 'package:flutter/material.dart';
import '../../app/theme.dart';

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData? actionIcon;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
    this.actionIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.border),
          ),
          child: Icon(icon, color: AppTheme.textM, size: 40),
        ),
        const SizedBox(height: 20),
        Text(
          title,
          style: const TextStyle(
            color: AppTheme.textH,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: const TextStyle(color: AppTheme.textM, fontSize: 14),
          textAlign: TextAlign.center,
        ),
        if (actionLabel != null && onAction != null) ...[
          const SizedBox(height: 24),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: AppTheme.textH,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: onAction,
            icon: Icon(actionIcon ?? Icons.add_rounded, size: 18),
            label: Text(actionLabel!),
          ),
        ],
      ]),
    );
  }
}
