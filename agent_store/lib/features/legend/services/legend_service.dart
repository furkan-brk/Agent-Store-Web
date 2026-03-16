// lib/features/legend/services/legend_service.dart

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:developer' as developer;
import '../models/workflow_models.dart';

class LegendService {
  static final LegendService instance = LegendService._();
  LegendService._();

  static const _key = 'legend_workflows_v1';

  List<LegendWorkflow> _workflows = [];

  List<LegendWorkflow> get workflows => List.unmodifiable(_workflows);

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return;
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      _workflows = list.map((e) => LegendWorkflow.fromJson(e as Map<String, dynamic>)).toList();
      _sortWorkflows();
    } catch (_) {}
  }

  Future<LegendWorkflow> saveWorkflow(LegendWorkflow wf) async {
     developer.log('[LegendService] saveWorkflow: name="${wf.name}", id="${wf.id}"');
    _workflows.removeWhere((w) => w.id == wf.id);
    _workflows.insert(0, wf);
    _sortWorkflows();
     developer.log('[LegendService] Workflow added. Total workflows: ${_workflows.length}');
    await _persist();
    return wf;
  }

  Future<void> deleteWorkflow(String id) async {
    _workflows.removeWhere((w) => w.id == id);
    _sortWorkflows();
    await _persist();
  }

  void _sortWorkflows() {
    _workflows.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
     developer.log('[LegendService] Persisting ${_workflows.length} workflows');
    await prefs.setString(
      _key,
      jsonEncode(_workflows.map((w) => w.toJson()).toList()),
    );
     final saved = prefs.getString(_key);
     developer.log('[LegendService] Persist complete. Verify: ${saved?.length ?? 0} bytes');
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
