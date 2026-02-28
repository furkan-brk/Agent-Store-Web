import 'agent_model.dart';

class GuildMemberModel {
  final int id;
  final int guildId;
  final int agentId;
  final AgentModel? agent;
  final String role;
  final DateTime joinedAt;

  const GuildMemberModel({
    required this.id,
    required this.guildId,
    required this.agentId,
    this.agent,
    required this.role,
    required this.joinedAt,
  });

  factory GuildMemberModel.fromJson(Map<String, dynamic> json) {
    AgentModel? agentModel;
    if (json['agent'] != null) {
      try {
        agentModel = AgentModel.fromJson(json['agent'] as Map<String, dynamic>);
      } catch (_) {}
    }
    return GuildMemberModel(
      id:       (json['id'] as num?)?.toInt() ?? 0,
      guildId:  (json['guild_id'] as num?)?.toInt() ?? 0,
      agentId:  (json['agent_id'] as num?)?.toInt() ?? 0,
      agent:    agentModel,
      role:     json['role'] as String? ?? 'Member',
      joinedAt: DateTime.tryParse(json['joined_at'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

class SynergyBonus {
  final String name;
  final Map<String, int> bonus;

  const SynergyBonus({required this.name, required this.bonus});

  factory SynergyBonus.fromJson(Map<String, dynamic> json) {
    final rawBonus = json['bonus'] as Map<String, dynamic>? ?? {};
    return SynergyBonus(
      name:  json['name'] as String? ?? '',
      bonus: rawBonus.map((k, v) => MapEntry(k, (v as num).toInt())),
    );
  }

  String get bonusText {
    return bonus.entries.map((e) => '+${e.value} ${_statLabel(e.key)}').join(', ');
  }

  String _statLabel(String key) => switch (key) {
    'intelligence' => 'INT',
    'defense'      => 'DEF',
    'speed'        => 'SPD',
    'creativity'   => 'CRT',
    'power'        => 'PWR',
    _              => key.toUpperCase(),
  };
}

class GuildModel {
  final int id;
  final String name;
  final String creatorWallet;
  final String rarity;
  final List<GuildMemberModel> members;
  final DateTime createdAt;

  const GuildModel({
    required this.id,
    required this.name,
    required this.creatorWallet,
    required this.rarity,
    required this.members,
    required this.createdAt,
  });

  factory GuildModel.fromJson(Map<String, dynamic> json) {
    final rawMembers = json['members'] as List<dynamic>? ?? [];
    return GuildModel(
      id:            (json['id'] as num?)?.toInt() ?? 0,
      name:          json['name'] as String? ?? '',
      creatorWallet: json['creator_wallet'] as String? ?? '',
      rarity:        json['rarity'] as String? ?? 'common',
      members:       rawMembers
          .map((e) => GuildMemberModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      createdAt:     DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }

  int get memberCount => members.length;

  String get roleIcon {
    return switch (rarity.toLowerCase()) {
      'legendary' => '👑',
      'epic'      => '💎',
      'rare'      => '⭐',
      'uncommon'  => '🔥',
      _           => '🛡',
    };
  }
}

class GuildDetailModel {
  final GuildModel guild;
  final List<SynergyBonus> synergy;
  final Map<String, int> bonuses;

  const GuildDetailModel({
    required this.guild,
    required this.synergy,
    required this.bonuses,
  });

  factory GuildDetailModel.fromJson(Map<String, dynamic> json) {
    final rawSynergy = json['synergy'] as List<dynamic>? ?? [];
    final rawBonuses = json['bonuses'] as Map<String, dynamic>? ?? {};
    return GuildDetailModel(
      guild:   GuildModel.fromJson(json['guild'] as Map<String, dynamic>),
      synergy: rawSynergy
          .map((e) => SynergyBonus.fromJson(e as Map<String, dynamic>))
          .toList(),
      bonuses: rawBonuses.map((k, v) => MapEntry(k, (v as num).toInt())),
    );
  }
}
