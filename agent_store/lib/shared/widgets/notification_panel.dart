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

  void _refresh() {
    if (mounted) setState(() => _unread = NotificationService.instance.unreadCount);
  }

  void _openPanel() async {
    await showDialog(
      context: context,
      builder: (_) => const _NotificationDialog(),
    );
    _refresh(); // unread count güncelle
  }

  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    children: [
      IconButton(
        icon: const Icon(Icons.notifications_outlined, color: Color(0xFF6B5A40), size: 20),
        onPressed: _openPanel,
        tooltip: 'Notifications',
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
      ),
      if (_unread > 0)
        Positioned(
          right: -2, top: -2,
          child: Container(
            width: 14, height: 14,
            decoration: const BoxDecoration(
              color: Color(0xFF81231E),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text('$_unread',
                style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
            ),
          ),
        ),
    ],
  );
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
    NotificationService.instance.markAllRead();
    _notifications = NotificationService.instance.getAll();
  }

  IconData _icon(String type) {
    switch (type) {
      case 'purchase': return Icons.shopping_cart_outlined;
      case 'save': return Icons.bookmark_outline;
      default: return Icons.info_outline;
    }
  }

  Color _color(String type) {
    switch (type) {
      case 'purchase': return const Color(0xFF5A8A48);
      case 'save': return const Color(0xFF81231E);
      default: return const Color(0xFF6B5A40);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: const Color(0xFFB8AA88),
    title: Row(children: [
      const Text('Notifications', style: TextStyle(color: Colors.white, fontSize: 16)),
      const Spacer(),
      if (_notifications.isNotEmpty)
        TextButton(
          onPressed: () { NotificationService.instance.clear(); setState(() => _notifications = []); },
          child: const Text('Clear all', style: TextStyle(color: Color(0xFF6B5A40), fontSize: 12)),
        ),
    ]),
    content: SizedBox(
      width: 340,
      child: _notifications.isEmpty
          ? const Center(child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('No notifications yet', style: TextStyle(color: Color(0xFF7A6E52)))))
          : ListView.separated(
              shrinkWrap: true,
              itemCount: _notifications.length,
              separatorBuilder: (_, __) => const Divider(color: Color(0xFFADA07A), height: 1),
              itemBuilder: (_, i) {
                final n = _notifications[i];
                return ListTile(
                  leading: Icon(_icon(n.type), color: _color(n.type), size: 20),
                  title: Text(n.message, style: const TextStyle(color: Colors.white, fontSize: 13)),
                  subtitle: Text(
                    '${n.createdAt.day}/${n.createdAt.month} ${n.createdAt.hour}:${n.createdAt.minute.toString().padLeft(2, '0')}',
                    style: const TextStyle(color: Color(0xFF7A6E52), fontSize: 11),
                  ),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                );
              },
            ),
    ),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context),
        child: const Text('Close', style: TextStyle(color: Color(0xFF81231E)))),
    ],
  );
}
