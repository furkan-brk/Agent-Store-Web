import 'dart:convert';
import 'local_kv_store.dart';

class AgentCollection {
  final String id;
  final String name;
  final List<int> agentIds;
  final String color;
  final DateTime createdAt;

  const AgentCollection({
    required this.id,
    required this.name,
    required this.agentIds,
    required this.color,
    required this.createdAt,
  });

  AgentCollection copyWith({
    String? id,
    String? name,
    List<int>? agentIds,
    String? color,
    DateTime? createdAt,
  }) =>
      AgentCollection(
        id: id ?? this.id,
        name: name ?? this.name,
        agentIds: agentIds ?? List<int>.from(this.agentIds),
        color: color ?? this.color,
        createdAt: createdAt ?? this.createdAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'agentIds': agentIds,
        'color': color,
        'createdAt': createdAt.toIso8601String(),
      };

  factory AgentCollection.fromJson(Map<String, dynamic> json) =>
      AgentCollection(
        id: json['id'] as String,
        name: json['name'] as String,
        agentIds: (json['agentIds'] as List<dynamic>)
            .map((e) => (e as num).toInt())
            .toList(),
        color: json['color'] as String,
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.now(),
      );
}

class CollectionService {
  static CollectionService? _instance;
  static CollectionService get instance =>
      _instance ??= CollectionService._();
  CollectionService._();

  static const _key = 'agent_collections';

  static const List<String> colorOptions = [
    '#6366F1',
    '#10B981',
    '#F59E0B',
    '#EF4444',
    '#8B5CF6',
    '#3B82F6',
  ];

  Future<List<AgentCollection>> getAll() async {
    try {
      final raw = await LocalKvStore.instance.getString(_key);
      if (raw == null || raw.isEmpty) return [];
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => AgentCollection.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _save(List<AgentCollection> collections) async {
    await LocalKvStore.instance.setString(
        _key, jsonEncode(collections.map((c) => c.toJson()).toList()));
  }

  Future<AgentCollection> create(String name, String color) async {
    final collection = AgentCollection(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name.trim().isEmpty ? 'Unnamed' : name.trim(),
      agentIds: [],
      color: color,
      createdAt: DateTime.now(),
    );
    final all = await getAll()..add(collection);
    await _save(all);
    return collection;
  }

  Future<void> addAgent(String collectionId, int agentId) async {
    final all = await getAll();
    final idx = all.indexWhere((c) => c.id == collectionId);
    if (idx == -1) return;
    final c = all[idx];
    if (c.agentIds.contains(agentId)) return;
    all[idx] = c.copyWith(agentIds: [...c.agentIds, agentId]);
    await _save(all);
  }

  Future<void> removeAgent(String collectionId, int agentId) async {
    final all = await getAll();
    final idx = all.indexWhere((c) => c.id == collectionId);
    if (idx == -1) return;
    final c = all[idx];
    all[idx] = c.copyWith(
        agentIds: c.agentIds.where((id) => id != agentId).toList());
    await _save(all);
  }

  Future<void> delete(String collectionId) async {
    final all = await getAll()..removeWhere((c) => c.id == collectionId);
    await _save(all);
  }

  Future<List<AgentCollection>> collectionsForAgent(int agentId) async =>
      (await getAll()).where((c) => c.agentIds.contains(agentId)).toList();
}
