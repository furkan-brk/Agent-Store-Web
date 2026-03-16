class MissionModel {
  final String id;
  final String title;
  final String slug;
  final String prompt;
  final int useCount;
  final DateTime createdAt;

  const MissionModel({
    required this.id,
    required this.title,
    required this.slug,
    required this.prompt,
    required this.useCount,
    required this.createdAt,
  });

  MissionModel copyWith({
    String? id,
    String? title,
    String? slug,
    String? prompt,
    int? useCount,
    DateTime? createdAt,
  }) {
    return MissionModel(
      id: id ?? this.id,
      title: title ?? this.title,
      slug: slug ?? this.slug,
      prompt: prompt ?? this.prompt,
      useCount: useCount ?? this.useCount,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'slug': slug,
        'prompt': prompt,
        'use_count': useCount,
        'created_at': createdAt.toIso8601String(),
      };

  factory MissionModel.fromJson(Map<String, dynamic> json) {
    return MissionModel(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      prompt: json['prompt'] as String? ?? '',
      useCount: json['use_count'] as int? ?? 0,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
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
