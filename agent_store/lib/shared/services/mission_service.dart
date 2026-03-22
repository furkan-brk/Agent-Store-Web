import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../models/mission_model.dart';
import 'api_service.dart';
import 'local_kv_store.dart';
import 'notification_service.dart';

enum SyncStatus { synced, syncing, pending, failed }

class MissionService {
  MissionService._();

  static final MissionService instance = MissionService._();

  /// Old global key (pre per-wallet migration).
  static const _legacyKey = 'missions_v1';

  /// Per-wallet key prefix.
  static const _keyPrefix = 'missions_v2';

  String? _currentWallet;

  String get _storageKey {
    final w = _currentWallet;
    return w != null && w.isNotEmpty ? '${_keyPrefix}_$w' : '${_keyPrefix}_guest';
  }

  final List<MissionModel> _missions = <MissionModel>[];

  List<MissionModel> get missions => List.unmodifiable(_missions);

  // ── Sync status tracking ────────────────────────────────────────────
  final ValueNotifier<SyncStatus> syncStatusNotifier = ValueNotifier(SyncStatus.synced);
  SyncStatus get syncStatus => syncStatusNotifier.value;
  String? _syncError;
  String? get syncError => _syncError;
  DateTime? _lastSyncTime;
  DateTime? get lastSyncTime => _lastSyncTime;
  Timer? _periodicSyncTimer;

  Future<void> init() async {
    // Read saved wallet to scope localStorage per-wallet from the start.
    _currentWallet = (await LocalKvStore.instance.getString('wallet_address'))?.toLowerCase();

    // One-time migration from old global key → per-wallet key.
    await _migrateLegacyKey();

    await refresh();
  }

  /// Called by AuthController when the wallet connects or disconnects.
  Future<void> onWalletChanged(String? wallet) async {
    final newWallet = wallet?.toLowerCase();
    if (newWallet == _currentWallet) return;

    if (_currentWallet == null && newWallet != null && _missions.isNotEmpty) {
      // User had guest missions and is now connecting — move them to the
      // wallet-specific key so they survive future disconnects.
      _currentWallet = newWallet;
      await _saveLocal();
      await LocalKvStore.instance.remove('${_keyPrefix}_guest');
    } else {
      _currentWallet = newWallet;
    }

    if (newWallet == null) {
      // Disconnecting — clear in-memory list, stop periodic sync.
      _missions.clear();
      _stopPeriodicSync();
      return;
    }

    await refresh();
    _startPeriodicSync();
  }

  void _startPeriodicSync() {
    _periodicSyncTimer?.cancel();
    _periodicSyncTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      if (ApiService.instance.isAuthenticated &&
          (syncStatus == SyncStatus.failed || syncStatus == SyncStatus.pending)) {
        forceSyncToBackend();
      }
    });
  }

  void _stopPeriodicSync() {
    _periodicSyncTimer?.cancel();
    _periodicSyncTimer = null;
  }

  Future<void> refresh() async {
    final local = await _loadLocal();
    if (ApiService.instance.isAuthenticated) {
      syncStatusNotifier.value = SyncStatus.syncing;
      _syncError = null;
      List<MissionModel> remote = <MissionModel>[];

      try {
        // Always try to sync local missions to backend first (with retry).
        if (local.isNotEmpty) {
          remote = await ApiService.instance.retry(
            () => ApiService.instance.batchSyncMissions(local),
          );
        }

        // If batch sync failed or local was empty, fetch from backend.
        if (remote.isEmpty) {
          remote = await ApiService.instance.retry(
            () => ApiService.instance.getUserMissions(),
          );
        }
      } catch (e) {
        debugPrint('MissionService: retry exhausted — $e');
      }

      // Detect sync failure: authenticated + remote empty + local non-empty
      if (remote.isEmpty && local.isNotEmpty) {
        debugPrint('MissionService: sync failed — ${local.length} missions saved locally only');
        _syncError = 'Sync failed — ${local.length} missions saved locally only';
        syncStatusNotifier.value = SyncStatus.failed;
        await NotificationService.instance.add(
          'Mission sync failed — ${local.length} missions saved locally only',
          type: 'info',
        );
      } else {
        debugPrint('MissionService: sync OK — ${remote.length} remote, ${local.length} local');
        _syncError = null;
        _lastSyncTime = DateTime.now();
        syncStatusNotifier.value = SyncStatus.synced;
      }

      _missions
        ..clear()
        ..addAll(_mergeMissions(local, remote));
      _sort();
      await _saveLocal();
      return;
    }

    _missions
      ..clear()
      ..addAll(local);
    _sort();
    syncStatusNotifier.value = SyncStatus.pending;
  }

  /// Force re-sync all local missions to the backend. Callable from UI.
  Future<void> forceSyncToBackend() async {
    if (!ApiService.instance.isAuthenticated || _missions.isEmpty) return;
    syncStatusNotifier.value = SyncStatus.syncing;
    _syncError = null;

    try {
      final remote = await ApiService.instance.retry(
        () => ApiService.instance.batchSyncMissions(_missions),
      );
      if (remote.isNotEmpty) {
        _missions
          ..clear()
          ..addAll(remote);
        _sort();
        await _saveLocal();
        _lastSyncTime = DateTime.now();
        syncStatusNotifier.value = SyncStatus.synced;
        _syncError = null;
        debugPrint('MissionService: force sync OK — ${remote.length} missions');
        return;
      }
    } catch (e) {
      debugPrint('MissionService: force sync failed — $e');
    }
    _syncError = 'Sync failed — please try again later';
    syncStatusNotifier.value = SyncStatus.failed;
  }

  /// Migrate the old global `missions_v1` key to the new per-wallet key.
  Future<void> _migrateLegacyKey() async {
    final oldRaw = await LocalKvStore.instance.getString(_legacyKey);
    if (oldRaw == null || oldRaw.isEmpty) return;

    // Only migrate if the new per-wallet key is still empty.
    final existing = await LocalKvStore.instance.getString(_storageKey);
    if (existing == null || existing.isEmpty) {
      await LocalKvStore.instance.setString(_storageKey, oldRaw);
      debugPrint('MissionService: migrated legacy key → $_storageKey');
    }
    await LocalKvStore.instance.remove(_legacyKey);
  }

  Future<List<MissionModel>> _loadLocal() async {
    final raw = await LocalKvStore.instance.getString(_storageKey);
    if (raw == null || raw.isEmpty) return <MissionModel>[];

    try {
      return (jsonDecode(raw) as List<dynamic>)
          .map((e) => MissionModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return <MissionModel>[];
    }
  }

  Future<void> addMission({required String title, required String prompt}) async {
    final cleanTitle = title.trim();
    final cleanPrompt = prompt.trim();
    if (cleanTitle.isEmpty || cleanPrompt.isEmpty) return;

    var slug = MissionModel.slugify(cleanTitle);
    var i = 2;
    while (_missions.any((m) => m.slug == slug)) {
      slug = '${MissionModel.slugify(cleanTitle)}-$i';
      i++;
    }

    final mission = MissionModel(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: cleanTitle,
      slug: slug,
      prompt: cleanPrompt,
      useCount: 0,
      createdAt: DateTime.now(),
    );
    _missions.add(mission);
    _sort();
    if (ApiService.instance.isAuthenticated) {
      final saved = await ApiService.instance.saveMission(mission);
      if (saved != null) {
        final idx = _missions.indexWhere((m) => m.id == mission.id);
        if (idx != -1) _missions[idx] = saved;
      }
    }
    await _save();
  }

  Future<void> updateMission({required String id, required String title, required String prompt}) async {
    final idx = _missions.indexWhere((m) => m.id == id);
    if (idx == -1) return;

    final cleanTitle = title.trim();
    final cleanPrompt = prompt.trim();
    if (cleanTitle.isEmpty || cleanPrompt.isEmpty) return;

    var slug = MissionModel.slugify(cleanTitle);
    var i = 2;
    while (_missions.any((m) => m.id != id && m.slug == slug)) {
      slug = '${MissionModel.slugify(cleanTitle)}-$i';
      i++;
    }

    _missions[idx] = _missions[idx].copyWith(
      title: cleanTitle,
      slug: slug,
      prompt: cleanPrompt,
    );
    _sort();
    if (ApiService.instance.isAuthenticated) {
      final saved = await ApiService.instance.saveMission(_missions[idx]);
      if (saved != null) {
        _missions[idx] = saved;
        _sort();
      }
    }
    await _save();
  }

  Future<void> deleteMission(String id) async {
    _missions.removeWhere((m) => m.id == id);
    if (ApiService.instance.isAuthenticated) {
      await ApiService.instance.deleteMission(id);
    }
    await _save();
  }

  List<MissionModel> search(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return missions.take(8).toList();
    return _missions
        .where((m) => m.slug.contains(q) || m.title.toLowerCase().contains(q))
        .take(8)
        .toList();
  }

  Future<void> incrementUsageBySlug(String slug) async {
    final idx = _missions.indexWhere((m) => m.slug == slug);
    if (idx == -1) return;
    _missions[idx] = _missions[idx].copyWith(useCount: _missions[idx].useCount + 1);
    _sort();
    if (ApiService.instance.isAuthenticated) {
      final saved = await ApiService.instance.saveMission(_missions[idx]);
      if (saved != null) {
        final savedIdx = _missions.indexWhere((m) => m.id == saved.id);
        if (savedIdx != -1) _missions[savedIdx] = saved;
        _sort();
      }
    }
    await _save();
  }

  Future<String> expandMissionTags(String input) async {
    if (input.isEmpty || _missions.isEmpty) return input;

    final usedSlugs = <String>{};
    final expanded = input.replaceAllMapped(RegExp(r'#([a-zA-Z0-9_-]+)'), (m) {
      final slug = (m.group(1) ?? '').toLowerCase();
      MissionModel? mission;
      for (final x in _missions) {
        if (x.slug == slug) {
          mission = x;
          break;
        }
      }
      if (mission == null) return m.group(0) ?? '';
      usedSlugs.add(slug);
      return mission.prompt;
    });

    for (final slug in usedSlugs) {
      await incrementUsageBySlug(slug);
    }

    return expanded;
  }

  Future<void> _save() async {
    await _saveLocal();
  }

  Future<void> _saveLocal() async {
    final data = jsonEncode(_missions.map((m) => m.toJson()).toList());
    await LocalKvStore.instance.setString(_storageKey, data);
  }

  List<MissionModel> _mergeMissions(List<MissionModel> local, List<MissionModel> remote) {
    final merged = <String, MissionModel>{};
    for (final mission in local) {
      merged[mission.id] = mission;
    }
    for (final mission in remote) {
      merged[mission.id] = mission;
    }
    return merged.values.toList();
  }

  void _sort() {
    _missions.sort((a, b) {
      final byUsage = b.useCount.compareTo(a.useCount);
      if (byUsage != 0) return byUsage;
      return b.createdAt.compareTo(a.createdAt);
    });
  }
}
