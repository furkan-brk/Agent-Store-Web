import 'package:flutter/material.dart';
import '../services/notification_service.dart';

class NotificationBell extends StatefulWidget {
  const NotificationBell({super.key});
  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> {
  int _unread = 0;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final count = await NotificationService.instance.unreadCount;
    if (mounted) setState(() => _unread = count);
  }

  void _openPanel() async {
    await showDialog(
      context: context,
      builder: (_) => const _NotificationDialog(),
    );
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: IconButton(
            icon: Icon(
              _unread > 0 ? Icons.notifications : Icons.notifications_outlined,
              color: _unread > 0 ? colorScheme.secondary : colorScheme.onSurface.withValues(alpha: 0.5),
              size: 20,
            ),
            onPressed: _openPanel,
            tooltip: 'Notifications',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ),
        if (_unread > 0)
          Positioned(
            right: -4,
            top: -4,
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: colorScheme.primary,
                shape: BoxShape.circle,
                border: Border.all(color: theme.scaffoldBackgroundColor, width: 1.5),
              ),
              child: Center(
                child: Text(
                  _unread > 9 ? '9+' : '$_unread',
                  style: TextStyle(
                    color: colorScheme.onPrimary,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _NotificationDialog extends StatefulWidget {
  const _NotificationDialog();
  @override
  State<_NotificationDialog> createState() => _NotificationDialogState();
}

class _NotificationDialogState extends State<_NotificationDialog> {
  late List<AppNotification> _notifications;

  @override
  void initState() {
    super.initState();
    _initNotifications();
  }

  Future<void> _initNotifications() async {
    await NotificationService.instance.markAllRead();
    final all = await NotificationService.instance.getAll();
    if (mounted) setState(() => _notifications = all);
  }

  IconData _icon(String type) {
    switch (type) {
      case 'purchase':
        return Icons.shopping_cart_outlined;
      case 'save':
        return Icons.bookmark_added_outlined;
      case 'warning':
        return Icons.warning_amber_outlined;
      case 'error':
        return Icons.error_outline;
      case 'success':
        return Icons.check_circle_outline;
      default:
        return Icons.info_outline;
    }
  }

  Color _color(String type, ColorScheme colorScheme) {
    switch (type) {
      case 'purchase':
        return const Color(0xFF5A8A48); // success green
      case 'save':
        return colorScheme.primary;
      case 'warning':
        return colorScheme.secondary; // gold
      case 'error':
        return colorScheme.error;
      case 'success':
        return const Color(0xFF5A8A48);
      default:
        return const Color(0xFF4A6080); // info steel blue
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AlertDialog(
      backgroundColor: theme.dialogTheme.backgroundColor,
      shape: theme.dialogTheme.shape,
      title: Row(
        children: [
          Icon(Icons.notifications_outlined, color: colorScheme.secondary, size: 18),
          const SizedBox(width: 8),
          Text(
            'Notifications',
            style: TextStyle(
              color: colorScheme.onSurface,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          if (_notifications.isNotEmpty)
            TextButton.icon(
              onPressed: () async {
                await NotificationService.instance.clear();
                setState(() => _notifications = []);
              },
              icon: Icon(Icons.delete_sweep_outlined, size: 14, color: colorScheme.onSurface.withValues(alpha: 0.5)),
              label: Text(
                'Clear all',
                style: TextStyle(
                  color: colorScheme.onSurface.withValues(alpha: 0.5),
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
      content: SizedBox(
        width: 380,
        child: _notifications.isEmpty
            ? _EmptyState(colorScheme: colorScheme)
            : ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 400),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _notifications.length,
                  separatorBuilder: (_, __) => Divider(
                    color: colorScheme.outline.withValues(alpha: 0.5),
                    height: 1,
                  ),
                  itemBuilder: (_, i) {
                    final n = _notifications[i];
                    final iconColor = _color(n.type, colorScheme);
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: iconColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Icon(_icon(n.type), color: iconColor, size: 14),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  n.message,
                                  style: TextStyle(
                                    color: colorScheme.onSurface,
                                    fontSize: 13,
                                    height: 1.3,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  _formatTime(n.createdAt),
                                  style: TextStyle(
                                    color: colorScheme.onSurface.withValues(alpha: 0.4),
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Close',
            style: TextStyle(color: colorScheme.primary),
          ),
        ),
      ],
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

/// Empty state shown when no notifications exist
class _EmptyState extends StatelessWidget {
  final ColorScheme colorScheme;
  const _EmptyState({required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.notifications_off_outlined,
            color: colorScheme.onSurface.withValues(alpha: 0.2),
            size: 40,
          ),
          const SizedBox(height: 12),
          Text(
            'No notifications yet',
            style: TextStyle(
              color: colorScheme.onSurface.withValues(alpha: 0.4),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Activity from your agents and guilds will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colorScheme.onSurface.withValues(alpha: 0.25),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
