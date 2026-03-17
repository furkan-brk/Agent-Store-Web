// lib/features/legend/services/legend_service.dart

import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../models/workflow_models.dart';
import '../../../shared/services/api_service.dart';
import '../../../shared/services/local_kv_store.dart';
import '../../../shared/services/notification_service.dart';

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
      return;
    }

    await refresh();
  }

  Future<void> refresh() async {
    final local = await _loadLocal();
    if (ApiService.instance.isAuthenticated) {
      List<LegendWorkflow> remote = <LegendWorkflow>[];

      if (local.isNotEmpty) {
        remote = await ApiService.instance.batchSyncLegendWorkflows(local);
      }

      if (remote.isEmpty) {
        remote = await ApiService.instance.getLegendWorkflows();
      }

      // Detect sync failure: authenticated + remote empty + local non-empty
      if (remote.isEmpty && local.isNotEmpty) {
        debugPrint('LegendService: sync failed — ${local.length} workflows saved locally only');
        await NotificationService.instance.add(
          'Workflow sync failed — ${local.length} workflows saved locally only',
          type: 'info',
        );
      } else {
        debugPrint('LegendService: sync OK — ${remote.length} remote, ${local.length} local');
      }

      _workflows = _mergeWorkflows(local, remote);
      _sortWorkflows();
      await _persistLocal();
      return;
    }
    _workflows = local;
    _sortWorkflows();
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

  List<LegendWorkflow> _mergeWorkflows(List<LegendWorkflow> local, List<LegendWorkflow> remote) {
    final merged = <String, LegendWorkflow>{};
    for (final workflow in local) {
      merged[workflow.id] = workflow;
    }
    for (final workflow in remote) {
      merged[workflow.id] = workflow;
    }
    return merged.values.toList();
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
