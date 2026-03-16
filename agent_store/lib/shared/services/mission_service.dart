import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/mission_model.dart';

class MissionService {
  MissionService._();

  static final MissionService instance = MissionService._();
  static const _storageKey = 'missions_v1';

  final List<MissionModel> _missions = <MissionModel>[];

  List<MissionModel> get missions => List.unmodifiable(_missions);

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return;

    try {
      final data = (jsonDecode(raw) as List<dynamic>)
          .map((e) => MissionModel.fromJson(e as Map<String, dynamic>))
          .toList();
      _missions
        ..clear()
        ..addAll(data);
      _sort();
    } catch (_) {
      _missions.clear();
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

    _missions.add(MissionModel(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: cleanTitle,
      slug: slug,
      prompt: cleanPrompt,
      useCount: 0,
      createdAt: DateTime.now(),
    ));
    _sort();
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
    await _save();
  }

  Future<void> deleteMission(String id) async {
    _missions.removeWhere((m) => m.id == id);
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
    final prefs = await SharedPreferences.getInstance();
    final data = jsonEncode(_missions.map((m) => m.toJson()).toList());
    await prefs.setString(_storageKey, data);
  }

  void _sort() {
    _missions.sort((a, b) {
      final byUsage = b.useCount.compareTo(a.useCount);
      if (byUsage != 0) return byUsage;
      return b.createdAt.compareTo(a.createdAt);
    });
  }
}
