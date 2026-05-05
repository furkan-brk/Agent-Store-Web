// v3.11.4: Guild membership audit-log section.
//
// Renders the guild's audit trail (joined / left / role_changed /
// permission_changed) under the existing Compatibility section. Append-only
// pattern — keeps the existing GuildDetail screen untouched besides one
// extra widget mount.
//
// Tests inject a `fetchOverride` so they can exercise the loaded / empty /
// loading branches without hitting the network.

import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../shared/services/api_service.dart';
import '../../../shared/widgets/skeleton_widgets.dart';

typedef GuildEventsFetcher = Future<List<Map<String, dynamic>>> Function();

class GuildEventLog extends StatefulWidget {
  final int guildId;

  /// Limit forwarded to the backend ?limit param. Backend caps at 50.
  final int limit;

  /// Test seam: allows widget tests to inject a stub fetcher without
  /// mounting the full ApiService singleton.
  final GuildEventsFetcher? fetchOverride;

  const GuildEventLog({
    super.key,
    required this.guildId,
    this.limit = 20,
    this.fetchOverride,
  });

  @override
  State<GuildEventLog> createState() => _GuildEventLogState();
}

class _GuildEventLogState extends State<GuildEventLog> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = (widget.fetchOverride ??
        () => ApiService.instance.getGuildEvents(widget.guildId, limit: widget.limit))();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 24, bottom: 8),
          child: Row(
            children: [
              Icon(Icons.history, size: 18, color: AppTheme.gold),
              SizedBox(width: 8),
              Text(
                'Activity',
                style: TextStyle(
                  color: AppTheme.textH,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        FutureBuilder<List<Map<String, dynamic>>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return Column(
                children: List.generate(3, (_) => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 4),
                  child: ShimmerBox(
                    width: double.infinity,
                    height: 48,
                    radius: 8,
                    color: AppTheme.card2,
                  ),
                )),
              );
            }
            final rows = snap.data ?? const <Map<String, dynamic>>[];
            if (rows.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  'No activity yet — events appear when members join, leave, or roles change.',
                  style: TextStyle(color: AppTheme.textM, fontSize: 12),
                ),
              );
            }
            return Column(
              children: rows.map(_buildEventRow).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildEventRow(Map<String, dynamic> row) {
    final type = row['event_type']?.toString() ?? 'unknown';
    final wallet = row['wallet']?.toString() ?? '';
    final created = row['created_at']?.toString() ?? '';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(_iconForType(type), size: 16, color: _colorForType(type)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_truncateWallet(wallet)} · ${_labelForType(type)}',
                  style: const TextStyle(color: AppTheme.textH, fontSize: 13),
                ),
                if (created.isNotEmpty)
                  Text(
                    _relativeTime(created),
                    style: const TextStyle(color: AppTheme.textM, fontSize: 11),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconForType(String t) {
    switch (t) {
      case 'joined':
        return Icons.person_add_alt_1;
      case 'left':
        return Icons.person_remove_alt_1;
      case 'role_changed':
        return Icons.swap_horiz;
      case 'permission_changed':
        return Icons.lock_outline;
    }
    return Icons.circle_outlined;
  }

  Color _colorForType(String t) {
    switch (t) {
      case 'joined':
        return AppTheme.success;
      case 'left':
        return AppTheme.primary;
      case 'role_changed':
      case 'permission_changed':
        return AppTheme.gold;
    }
    return AppTheme.textM;
  }

  String _labelForType(String t) {
    switch (t) {
      case 'joined':
        return 'joined the guild';
      case 'left':
        return 'left the guild';
      case 'role_changed':
        return 'role updated';
      case 'permission_changed':
        return 'permissions updated';
    }
    return t;
  }

  String _truncateWallet(String w) {
    if (w.length <= 12) return w;
    return '${w.substring(0, 6)}…${w.substring(w.length - 4)}';
  }

  String _relativeTime(String iso) {
    try {
      final t = DateTime.parse(iso).toLocal();
      final delta = DateTime.now().difference(t);
      if (delta.inMinutes < 1) return 'just now';
      if (delta.inMinutes < 60) return '${delta.inMinutes}m ago';
      if (delta.inHours < 24) return '${delta.inHours}h ago';
      return '${delta.inDays}d ago';
    } catch (_) {
      return iso;
    }
  }
}
