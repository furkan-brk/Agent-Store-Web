// lib/features/legend/services/legend_service.dart

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
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
    _workflows.removeWhere((w) => w.id == wf.id);
    _workflows.insert(0, wf);
    _sortWorkflows();
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
    await prefs.setString(
      _key,
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
