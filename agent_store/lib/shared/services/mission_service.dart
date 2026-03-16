import 'dart:convert';

import '../models/mission_model.dart';
import 'api_service.dart';
import 'local_kv_store.dart';

class MissionService {
  MissionService._();

  static final MissionService instance = MissionService._();
  static const _storageKey = 'missions_v1';

  final List<MissionModel> _missions = <MissionModel>[];

  List<MissionModel> get missions => List.unmodifiable(_missions);

  Future<void> init() async => refresh();

  Future<void> refresh() async {
    final local = await _loadLocal();
    if (ApiService.instance.isAuthenticated) {
      // If there are local missions, batch-sync them to the backend in one
      // request instead of N sequential POSTs. The backend upserts each and
      // returns the complete list from the DB.
      List<MissionModel> remote;
      if (local.isNotEmpty) {
        remote = await ApiService.instance.batchSyncMissions(local);
        // If batch sync returned empty (e.g. network error), fall back to GET.
        if (remote.isEmpty) {
          remote = await ApiService.instance.getUserMissions();
        }
      } else {
        remote = await ApiService.instance.getUserMissions();
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
