// lib/features/legend/services/legend_service.dart

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../models/workflow_models.dart';
import '../../../shared/services/api_service.dart';
import '../../../shared/services/local_kv_store.dart';
import '../../../shared/services/mission_service.dart' show SyncStatus;


class LegendService {
  static final LegendService instance = LegendService._();
  LegendService._();

  /// Old global key (pre per-wallet migration).
  static const _legacyKey = 'legend_workflows_v1';

  /// Per-wallet key prefix.
  static const _keyPrefix = 'legend_workflows_v2';

  String? _currentWallet;

  String get _storageKey {
    final w = _currentWallet;
    return w != null && w.isNotEmpty ? '${_keyPrefix}_$w' : '${_keyPrefix}_guest';
  }

  List<LegendWorkflow> _workflows = [];

  List<LegendWorkflow> get workflows => List.unmodifiable(_workflows);

  // ── Sync status tracking ────────────────────────────────────────────
  final ValueNotifier<SyncStatus> syncStatusNotifier = ValueNotifier(SyncStatus.synced);
  SyncStatus get syncStatus => syncStatusNotifier.value;
  String? _syncError;
  String? get syncError => _syncError;
  DateTime? _lastSyncTime;
  DateTime? get lastSyncTime => _lastSyncTime;
  Timer? _periodicSyncTimer;

  Future<void> init() async {
    _currentWallet = (await LocalKvStore.instance.getString('wallet_address'))?.toLowerCase();
    await _migrateLegacyKey();
    await refresh();
  }

  /// Called by AuthController when the wallet connects or disconnects.
  Future<void> onWalletChanged(String? wallet) async {
    final newWallet = wallet?.toLowerCase();
    if (newWallet == _currentWallet) return;

    if (_currentWallet == null && newWallet != null && _workflows.isNotEmpty) {
      _currentWallet = newWallet;
      await _persistLocal();
      await LocalKvStore.instance.remove('${_keyPrefix}_guest');
    } else {
      _currentWallet = newWallet;
    }

    if (newWallet == null) {
      _workflows = [];
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
      List<LegendWorkflow> remote = <LegendWorkflow>[];

      try {
        // 1. Always fetch remote (DB is the primary source of truth).
        remote = await ApiService.instance.retry(
          () => ApiService.instance.getLegendWorkflows(),
        );

        // 2. If local has workflows not in remote, sync them up.
        if (local.isNotEmpty) {
          final remoteIds = remote.map((w) => w.id).toSet();
          final localOnly = local.where((w) => !remoteIds.contains(w.id)).toList();
          if (localOnly.isNotEmpty) {
            final synced = await ApiService.instance.retry(
              () => ApiService.instance.batchSyncLegendWorkflows(localOnly),
            );
            if (synced.isNotEmpty) {
              remote = await ApiService.instance.retry(
                () => ApiService.instance.getLegendWorkflows(),
              );
            }
          }
        }
      } catch (e) {
        debugPrint('LegendService: retry exhausted — $e');
      }

      if (remote.isEmpty && local.isNotEmpty) {
        debugPrint('LegendService: sync failed — using ${local.length} local workflows');
        _syncError = 'Sync failed — using local cache';
        syncStatusNotifier.value = SyncStatus.failed;
        _workflows = local;
      } else {
        debugPrint('LegendService: sync OK — ${remote.length} remote, ${local.length} local');
        _syncError = null;
        _lastSyncTime = DateTime.now();
        syncStatusNotifier.value = SyncStatus.synced;
        _workflows = remote;
      }
      _sortWorkflows();
      await _persistLocal();
      return;
    }

    // Not authenticated — local-only mode.
    _workflows = local;
    _sortWorkflows();
    syncStatusNotifier.value = SyncStatus.pending;
  }

  /// Force re-sync all local workflows to the backend.
  Future<void> forceSyncToBackend() async {
    if (!ApiService.instance.isAuthenticated || _workflows.isEmpty) return;
    syncStatusNotifier.value = SyncStatus.syncing;
    _syncError = null;

    try {
      final remote = await ApiService.instance.retry(
        () => ApiService.instance.batchSyncLegendWorkflows(_workflows),
      );
      if (remote.isNotEmpty) {
        _workflows = remote;
        _sortWorkflows();
        await _persistLocal();
        _lastSyncTime = DateTime.now();
        syncStatusNotifier.value = SyncStatus.synced;
        _syncError = null;
        debugPrint('LegendService: force sync OK — ${remote.length} workflows');
        return;
      }
    } catch (e) {
      debugPrint('LegendService: force sync failed — $e');
    }
    _syncError = 'Sync failed — please try again later';
    syncStatusNotifier.value = SyncStatus.failed;
  }

  Future<void> _migrateLegacyKey() async {
    final oldRaw = await LocalKvStore.instance.getString(_legacyKey);
    if (oldRaw == null || oldRaw.isEmpty) return;

    final existing = await LocalKvStore.instance.getString(_storageKey);
    if (existing == null || existing.isEmpty) {
      await LocalKvStore.instance.setString(_storageKey, oldRaw);
      debugPrint('LegendService: migrated legacy key → $_storageKey');
    }
    await LocalKvStore.instance.remove(_legacyKey);
  }

  Future<List<LegendWorkflow>> _loadLocal() async {
    final raw = await LocalKvStore.instance.getString(_storageKey);
    if (raw == null || raw.isEmpty) return <LegendWorkflow>[];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((e) => LegendWorkflow.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return <LegendWorkflow>[];
    }
  }

  Future<LegendWorkflow> saveWorkflow(LegendWorkflow wf) async {
    _workflows.removeWhere((w) => w.id == wf.id);
    _workflows.insert(0, wf);
    _sortWorkflows();
    await _persist();
    if (ApiService.instance.isAuthenticated) {
      final saved = await ApiService.instance.saveLegendWorkflow(wf);
      if (saved != null) {
        _workflows.removeWhere((w) => w.id == saved.id);
        _workflows.insert(0, saved);
        _sortWorkflows();
        await _persistLocal();
        return saved;
      }
    }
    return wf;
  }

  Future<void> deleteWorkflow(String id) async {
    _workflows.removeWhere((w) => w.id == id);
    _sortWorkflows();
    if (ApiService.instance.isAuthenticated) {
      await ApiService.instance.deleteLegendWorkflow(id);
    }
    await _persist();
  }

  void _sortWorkflows() {
    _workflows.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  Future<void> _persist() async {
    await _persistLocal();
  }

  Future<void> _persistLocal() async {
    await LocalKvStore.instance.setString(
      _storageKey,
      jsonEncode(_workflows.map((w) => w.toJson()).toList()),
    );
  }

  /// Create a brand-new empty workflow.
  LegendWorkflow newWorkflow(String name) => LegendWorkflow(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        nodes: [],
        edges: [],
        updatedAt: DateTime.now(),
      );
}
