// lib/features/legend/services/legend_service.dart

import 'dart:convert';

import '../models/workflow_models.dart';
import '../../../shared/services/api_service.dart';
import '../../../shared/services/local_kv_store.dart';

class LegendService {
  static final LegendService instance = LegendService._();
  LegendService._();

  static const _key = 'legend_workflows_v1';

  List<LegendWorkflow> _workflows = [];

  List<LegendWorkflow> get workflows => List.unmodifiable(_workflows);

  Future<void> init() async => refresh();

  Future<void> refresh() async {
    final local = await _loadLocal();
    if (ApiService.instance.isAuthenticated) {
      // Batch-sync all local workflows to the backend in a single request.
      // The backend upserts each and returns the complete DB list.
      List<LegendWorkflow> remote;
      if (local.isNotEmpty) {
        remote = await ApiService.instance.batchSyncLegendWorkflows(local);
        // If batch sync returned empty (e.g. network error), fall back to GET.
        if (remote.isEmpty) {
          remote = await ApiService.instance.getLegendWorkflows();
        }
      } else {
        remote = await ApiService.instance.getLegendWorkflows();
      }
      _workflows = _mergeWorkflows(local, remote);
      _sortWorkflows();
      await _persistLocal();
      return;
    }
    _workflows = local;
    _sortWorkflows();
  }

  Future<List<LegendWorkflow>> _loadLocal() async {
    final raw = await LocalKvStore.instance.getString(_key);
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
      _key,
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
