// lib/features/settings/screens/notifications_screen.dart
//
// Settings → Notifications: top section is a (channel × type) preference
// matrix backed by /user/notifications/prefs; bottom section is an inbox
// list with cursor pagination + mark-all-read.
//
// Pure GetX controller — backend may not yet be wired (v3.11.2 backend
// task T1 lands separately). Empty payloads render the default-allow
// matrix and a friendly empty inbox state without surfacing errors.

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/theme.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../../shared/services/api_service.dart';
import '../../../shared/utils/app_snack_bar.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/page_header.dart';
import '../widgets/settings_sidebar.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final ctrl = Get.isRegistered<NotificationPrefsController>()
        ? Get.find<NotificationPrefsController>()
        : Get.put(NotificationPrefsController());

    return SettingsLayout(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeader(
            icon: Icons.notifications_outlined,
            title: l.notificationsSection,
            subtitle: l.settingsSubtitle,
          ),
          const SizedBox(height: 24),

          // ── Preferences matrix ────────────────────────────────────────
          _SectionTitle(text: l.notificationPreferences),
          const SizedBox(height: 8),
          Obx(() => _PrefsMatrix(ctrl: ctrl)),

          const SizedBox(height: 24),

          // ── Inbox header + mark-all CTA ──────────────────────────────
          Row(children: [
            Expanded(child: _SectionTitle(text: l.notificationInbox)),
            Obx(() {
              final hasUnread = ctrl.events.any((e) => (e['read_at'] == null));
              if (!hasUnread) return const SizedBox.shrink();
              return TextButton.icon(
                onPressed: () => ctrl.markAllRead(context),
                icon: const Icon(Icons.done_all_rounded, size: 16),
                label: Text(l.markAllAsRead),
                style: TextButton.styleFrom(foregroundColor: AppTheme.gold),
              );
            }),
          ]),
          const SizedBox(height: 8),
          Obx(() => _Inbox(ctrl: ctrl)),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

// ─── Controller ────────────────────────────────────────────────────────────

class NotificationPrefsController extends GetxController {
  final prefs = <Map<String, dynamic>>[].obs;
  final events = <Map<String, dynamic>>[].obs;
  final isPrefsLoading = true.obs;
  final isInboxLoading = true.obs;
  final error = RxnString();
  final hasMore = true.obs;

  static const channels = <String>['web', 'email'];
  static const types = <String>['social', 'system', 'credit'];

  @override
  void onInit() {
    super.onInit();
    loadAll();
  }

  Future<void> loadAll() async {
    await Future.wait([loadPrefs(), reloadInbox()]);
  }

  Future<void> loadPrefs() async {
    isPrefsLoading.value = true;
    error.value = null;
    final remote = await ApiService.instance.getNotificationPrefs();
    // Default-allow seeding: any (channel, type) combo not returned by the
    // server falls back to enabled=true so the toggle reflects the
    // contractual default rather than appearing as off.
    final byKey = <String, Map<String, dynamic>>{
      for (final p in remote)
        '${p['channel']}_${p['type']}': Map<String, dynamic>.from(p),
    };
    final seeded = <Map<String, dynamic>>[];
    for (final ch in channels) {
      for (final ty in types) {
        final key = '${ch}_$ty';
        seeded.add(byKey[key] ??
            <String, dynamic>{
              'channel': ch,
              'type': ty,
              'enabled': true,
            });
      }
    }
    prefs.value = seeded;
    isPrefsLoading.value = false;
  }

  bool isEnabled(String channel, String type) {
    final row = prefs.firstWhereOrNull(
      (p) => p['channel'] == channel && p['type'] == type,
    );
    return row?['enabled'] as bool? ?? true;
  }

  /// Optimistic toggle — flips local state immediately, then asks the
  /// server to persist; on failure rolls back and surfaces an error
  /// snackbar.
  Future<void> togglePref(
    BuildContext context,
    String channel,
    String type,
    bool next,
  ) async {
    final idx = prefs.indexWhere(
      (p) => p['channel'] == channel && p['type'] == type,
    );
    if (idx < 0) return;
    final original = Map<String, dynamic>.from(prefs[idx]);
    prefs[idx] = {...original, 'enabled': next};
    final ok = await ApiService.instance
        .updateNotificationPref(channel, type, next);
    if (!ok) {
      // Revert on failure
      prefs[idx] = original;
      if (context.mounted) {
        AppSnackBar.error(context, 'Could not update notification preference.');
      }
    }
  }

  Future<void> reloadInbox() async {
    isInboxLoading.value = true;
    final next = await ApiService.instance.getNotificationInbox();
    events.value = next;
    hasMore.value = next.length >= 20;
    isInboxLoading.value = false;
  }

  Future<void> loadMore() async {
    if (!hasMore.value || events.isEmpty) return;
    final beforeId = (events.last['id'] as num?)?.toInt() ?? 0;
    final more = await ApiService.instance.getNotificationInbox(
      beforeId: beforeId,
    );
    if (more.isEmpty) {
      hasMore.value = false;
      return;
    }
    events.addAll(more);
    hasMore.value = more.length >= 20;
  }

  Future<void> markRead(int id) async {
    final idx = events.indexWhere((e) => e['id'] == id);
    if (idx < 0) return;
    final original = Map<String, dynamic>.from(events[idx]);
    events[idx] = {
      ...original,
      'read_at': DateTime.now().toUtc().toIso8601String(),
    };
    final ok = await ApiService.instance.markNotificationRead(id);
    if (!ok) {
      events[idx] = original;
    }
  }

  Future<void> markAllRead(BuildContext context) async {
    final originals =
        events.map((e) => Map<String, dynamic>.from(e)).toList();
    events.value = events
        .map((e) => {
              ...e,
              'read_at':
                  e['read_at'] ?? DateTime.now().toUtc().toIso8601String(),
            })
        .toList();
    final ok = await ApiService.instance.markAllNotificationsRead();
    if (!ok) {
      events.value = originals;
      if (context.mounted) {
        AppSnackBar.error(context, 'Could not mark notifications as read.');
      }
    }
  }
}

// ─── Widgets ───────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          color: AppTheme.textM,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _PrefsMatrix extends StatelessWidget {
  final NotificationPrefsController ctrl;
  const _PrefsMatrix({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    if (ctrl.isPrefsLoading.value) {
      return Container(
        height: 160,
        decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.border),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: AppTheme.gold, strokeWidth: 2),
        ),
      );
    }
    final l = AppLocalizations.of(context);
    String typeLabel(String t) {
      switch (t) {
        case 'social':
          return l.typeSocial;
        case 'system':
          return l.typeSystem;
        case 'credit':
          return l.typeCredit;
      }
      return t;
    }

    String channelLabel(String c) {
      switch (c) {
        case 'web':
          return l.channelWeb;
        case 'email':
          return l.channelEmail;
      }
      return c;
    }

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const SizedBox(width: 80),
              ...NotificationPrefsController.channels.map(
                (ch) => Expanded(
                  child: Text(
                    channelLabel(ch),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppTheme.textM,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 8),
            ...NotificationPrefsController.types.map(
              (ty) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(children: [
                  SizedBox(
                    width: 80,
                    child: Text(
                      typeLabel(ty),
                      style: const TextStyle(
                        color: AppTheme.textH,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  ...NotificationPrefsController.channels.map((ch) {
                    final enabled = ctrl.isEnabled(ch, ty);
                    return Expanded(
                      child: Center(
                        child: Switch.adaptive(
                          value: enabled,
                          onChanged: (v) =>
                              ctrl.togglePref(context, ch, ty, v),
                          activeColor: AppTheme.primary,
                          inactiveThumbColor: AppTheme.textM,
                          inactiveTrackColor: AppTheme.card2,
                        ),
                      ),
                    );
                  }),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Inbox extends StatelessWidget {
  final NotificationPrefsController ctrl;
  const _Inbox({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    if (ctrl.isInboxLoading.value) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.border),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: AppTheme.gold, strokeWidth: 2),
        ),
      );
    }
    if (ctrl.events.isEmpty) {
      final l = AppLocalizations.of(context);
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 32),
        decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.border),
        ),
        child: EmptyState(
          icon: Icons.notifications_off_outlined,
          title: l.noNotifications,
          subtitle: l.noNotificationsSubtitle,
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: ctrl.events.length,
            separatorBuilder: (_, __) =>
                const Divider(height: 1, color: AppTheme.border, indent: 16),
            itemBuilder: (_, i) => _InboxRow(
              event: ctrl.events[i],
              onTap: () {
                final id = (ctrl.events[i]['id'] as num?)?.toInt() ?? 0;
                if (id > 0) ctrl.markRead(id);
              },
            ),
          ),
          if (ctrl.hasMore.value)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: TextButton.icon(
                onPressed: ctrl.loadMore,
                icon: const Icon(Icons.expand_more_rounded, size: 18),
                label: const Text('Load more'),
                style: TextButton.styleFrom(foregroundColor: AppTheme.gold),
              ),
            ),
        ],
      ),
    );
  }
}

class _InboxRow extends StatelessWidget {
  final Map<String, dynamic> event;
  final VoidCallback onTap;
  const _InboxRow({required this.event, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isUnread = event['read_at'] == null;
    final title = (event['title'] as String?) ?? '(untitled)';
    final body = (event['body'] as String?) ?? '';
    final createdAt = (event['created_at'] as String?) ?? '';

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(top: 6, right: 12),
              decoration: BoxDecoration(
                color: isUnread ? AppTheme.gold : Colors.transparent,
                shape: BoxShape.circle,
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: AppTheme.textH,
                      fontSize: 13,
                      fontWeight: isUnread ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                  if (body.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      body,
                      style: const TextStyle(
                        color: AppTheme.textM,
                        fontSize: 12,
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    _relative(createdAt),
                    style: const TextStyle(
                      color: AppTheme.textM,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _relative(String iso) {
    if (iso.isEmpty) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      final delta = DateTime.now().difference(dt);
      if (delta.inSeconds < 60) return 'just now';
      if (delta.inMinutes < 60) return '${delta.inMinutes}m ago';
      if (delta.inHours < 24) return '${delta.inHours}h ago';
      if (delta.inDays < 7) return '${delta.inDays}d ago';
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }
}
