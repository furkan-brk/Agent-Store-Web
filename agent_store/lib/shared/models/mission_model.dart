class MissionModel {
  final String id;
  final String title;
  final String slug;
  final String prompt;
  final int useCount;
  final DateTime createdAt;
  /// Server-issued optimistic concurrency token (v3.7-13.1). Zero on rows
  /// the server hasn't seen yet; copyWith bumps it after a successful sync
  /// so the next save can pass [If-Match: revisionId] to avoid clobbering
  /// concurrent edits from a second tab/device.
  final int revisionId;

  const MissionModel({
    required this.id,
    required this.title,
    required this.slug,
    required this.prompt,
    required this.useCount,
    required this.createdAt,
    this.revisionId = 0,
  });

  MissionModel copyWith({
    String? id,
    String? title,
    String? slug,
    String? prompt,
    int? useCount,
    DateTime? createdAt,
    int? revisionId,
  }) {
    return MissionModel(
      id: id ?? this.id,
      title: title ?? this.title,
      slug: slug ?? this.slug,
      prompt: prompt ?? this.prompt,
      useCount: useCount ?? this.useCount,
      createdAt: createdAt ?? this.createdAt,
      revisionId: revisionId ?? this.revisionId,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'slug': slug,
        'prompt': prompt,
        'use_count': useCount,
        'created_at': createdAt.toIso8601String(),
        'revision_id': revisionId,
      };

  factory MissionModel.fromJson(Map<String, dynamic> json) {
    // Server may return revision_id as int or as a string (jsonb). Accept both.
    final rawRev = json['revision_id'];
    final rev = rawRev is int
        ? rawRev
        : (rawRev is String ? int.tryParse(rawRev) ?? 0 : 0);
    return MissionModel(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      prompt: json['prompt'] as String? ?? '',
      useCount: json['use_count'] as int? ?? 0,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
      revisionId: rev,
    );
  }

  static String slugify(String title) {
    final s = title
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'[^a-z0-9\s_-]'), '')
        .replaceAll(RegExp(r'[\s_]+'), '-')
        .replaceAll(RegExp(r'-{2,}'), '-');
    return s.isEmpty ? 'mission' : s;
  }
}
