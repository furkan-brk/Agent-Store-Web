import 'package:flutter/material.dart';
import '../../app/theme.dart';

class PageHeader extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String title;
  final String? subtitle;
  final Widget? trailing;

  const PageHeader({
    super.key,
    required this.icon,
    this.iconColor,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width < 768;
    final color = iconColor ?? AppTheme.primary;

    return Row(children: [
      Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 22),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            title,
            style: TextStyle(
              color: AppTheme.textH,
              fontSize: isMobile ? 20 : 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              style: const TextStyle(color: AppTheme.textM, fontSize: 13),
            ),
          ],
        ]),
      ),
      if (trailing != null) trailing!,
    ]);
  }
}
