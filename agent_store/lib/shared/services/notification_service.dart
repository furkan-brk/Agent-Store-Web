// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:convert';
import 'dart:html' as html;

class AppNotification {
  final String id;
  final String message;
  final String type; // 'purchase', 'save', 'info'
  final DateTime createdAt;
  final bool read;

  AppNotification({
    required this.id,
    required this.message,
    required this.type,
    required this.createdAt,
    this.read = false,
  });

  AppNotification copyWith({bool? read}) => AppNotification(
    id: id, message: message, type: type, createdAt: createdAt,
    read: read ?? this.read,
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'message': message, 'type': type,
    'createdAt': createdAt.toIso8601String(), 'read': read,
  };

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
    id: j['id'] as String,
    message: j['message'] as String,
    type: j['type'] as String? ?? 'info',
    createdAt: DateTime.parse(j['createdAt'] as String),
    read: j['read'] as bool? ?? false,
  );
}

class NotificationService {
  static final NotificationService instance = NotificationService._();
  NotificationService._();

  static const _key = 'agent_store_notifications';

  List<AppNotification> getAll() {
    final raw = html.window.localStorage[_key];
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list.map((e) => AppNotification.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) { return []; }
  }

  int get unreadCount => getAll().where((n) => !n.read).length;

  void add(String message, {String type = 'info'}) {
    final notifications = getAll();
    notifications.insert(0, AppNotification(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      message: message, type: type,
      createdAt: DateTime.now(),
    ));
    // Keep max 30
    final trimmed = notifications.take(30).toList();
    html.window.localStorage[_key] = jsonEncode(trimmed.map((n) => n.toJson()).toList());
  }

  void markAllRead() {
    final updated = getAll().map((n) => n.copyWith(read: true)).toList();
    html.window.localStorage[_key] = jsonEncode(updated.map((n) => n.toJson()).toList());
  }

  void clear() => html.window.localStorage.remove(_key);
}
