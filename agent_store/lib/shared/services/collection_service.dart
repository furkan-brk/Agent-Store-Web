// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'dart:convert';

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

  List<AgentCollection> getAll() {
    try {
      final raw = html.window.localStorage[_key];
      if (raw == null || raw.isEmpty) return [];
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => AgentCollection.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  void _save(List<AgentCollection> collections) {
    html.window.localStorage[_key] =
        jsonEncode(collections.map((c) => c.toJson()).toList());
  }

  AgentCollection create(String name, String color) {
    final collection = AgentCollection(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name.trim().isEmpty ? 'Unnamed' : name.trim(),
      agentIds: [],
      color: color,
      createdAt: DateTime.now(),
    );
    final all = getAll()..add(collection);
    _save(all);
    return collection;
  }

  void addAgent(String collectionId, int agentId) {
    final all = getAll();
    final idx = all.indexWhere((c) => c.id == collectionId);
    if (idx == -1) return;
    final c = all[idx];
    if (c.agentIds.contains(agentId)) return;
    all[idx] = c.copyWith(agentIds: [...c.agentIds, agentId]);
    _save(all);
  }

  void removeAgent(String collectionId, int agentId) {
    final all = getAll();
    final idx = all.indexWhere((c) => c.id == collectionId);
    if (idx == -1) return;
    final c = all[idx];
    all[idx] = c.copyWith(
        agentIds: c.agentIds.where((id) => id != agentId).toList());
    _save(all);
  }

  void delete(String collectionId) {
    final all = getAll()..removeWhere((c) => c.id == collectionId);
    _save(all);
  }

  List<AgentCollection> collectionsForAgent(int agentId) =>
      getAll().where((c) => c.agentIds.contains(agentId)).toList();
}
