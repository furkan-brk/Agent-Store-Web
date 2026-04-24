import 'package:get/get.dart';
import '../shared/models/agent_model.dart';
import '../shared/services/api_service.dart';
import '../shared/services/mission_service.dart';

// ── Phase ─────────────────────────────────────────────────────────────────────

enum GuildMasterPhase { input, loading, ready }

// ── Chat message model ────────────────────────────────────────────────────────

class GuildChatMessage {
  final String id;
  final bool isUser;
  final String text;
  final int? agentId;
  final String? agentTitle;
  final String? characterType;
  final String? role;

  /// True when this message is a cross-agent interaction (agents talking to
  /// each other), as opposed to a direct agent reply to the user.
  final bool isCrossAgent;

  /// True when this row is a lightweight marker in the "All" feed indicating
  /// the user sent a private DM on an individual agent tab. The real content
  /// lives only in that agent's thread; the All thread only sees this hint.
  final bool isPrivateMarker;

  final DateTime timestamp;

  GuildChatMessage({
    required this.id,
    required this.isUser,
    required this.text,
    this.agentId,
    this.agentTitle,
    this.characterType,
    this.role,
    this.isCrossAgent = false,
    this.isPrivateMarker = false,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

// ── Controller ────────────────────────────────────────────────────────────────

class GuildMasterController extends GetxController {
  final List<Map<String, dynamic>>? initialAgents;
  final String? initialGuildName;
  GuildMasterController({this.initialAgents, this.initialGuildName});

  // Phase
  final phase = GuildMasterPhase.input.obs;
  final error = RxnString();

  // Team metadata
  final suggestion = Rxn<Map<String, dynamic>>();
  final teamAgents = <Map<String, dynamic>>[].obs;

  // Which agent IDs are selected for the next broadcast
  final selectedAgentIds = <int>[].obs;

  // Optional "team leader" — when set, broadcasts are prefixed with a
  // coordination instruction so the named agent acts as the spokesperson.
  final leaderAgentId = RxnInt();

  // Library agents — loaded on demand for @-mention autocomplete
  final libraryAgents = <AgentModel>[].obs;
  final isLibraryLoading = false.obs;

  // Chat state
  final isChatLoading = false.obs;
  final isCrossLoading = false.obs;

  // Per-agent message threads  (agentId → messages)
  // Using a plain Map with RxList values; the outer Map is not observed —
  // the individual lists are, so Obx inside the chat will react correctly.
  final Map<int, RxList<GuildChatMessage>> agentThreads = {};

  // "All" combined feed — every message in arrival order
  final allMessages = <GuildChatMessage>[].obs;

  // Active tab: null = "All", int = a specific agentId
  final activeTabId = Rxn<int>();

  // Text preserved across input→loading→input error cycle
  String lastProblem = '';

  // Signals the composer to fill an example text into Monaco
  final exampleHint = RxnString();

  void setExampleHint(String text) {
    exampleHint.value = text;
  }

  // ── Lifecycle ───────────────────────────────────────────────────────────────

  @override
  void onInit() {
    super.onInit();
    if (initialAgents != null && initialAgents!.isNotEmpty) {
      teamAgents.addAll(initialAgents!);
      _initThreads();
      selectedAgentIds.addAll(
        initialAgents!.map((a) => (a['id'] as num).toInt()),
      );
      suggestion.value = {
        'suggested_name': initialGuildName ?? 'Guild Team',
        'reasoning': 'Team assembled from your guild. Chat to collaborate!',
      };
      phase.value = GuildMasterPhase.ready;
    }
    ensureLibraryLoaded();
  }

  // ── Library loading ─────────────────────────────────────────────────────────

  /// Loads agents available for `@`-mention autocomplete:
  ///   • user's library (saved/purchased agents) — marked `owned: true`
  ///   • top 100 popular store agents — for referencing unsaved agents
  /// Merged by id, library takes precedence.
  Future<void> ensureLibraryLoaded() async {
    if (isLibraryLoading.value || libraryAgents.isNotEmpty) return;
    isLibraryLoading.value = true;
    try {
      final libraryFut = ApiService.instance.isAuthenticated
          ? ApiService.instance.getLibrary()
          : Future.value(<AgentModel>[]);
      final storeFut =
          ApiService.instance.listAgents(limit: 100, sort: 'popular');

      final results = await Future.wait([libraryFut, storeFut]);
      final library = results[0] as List<AgentModel>;
      final storeRes =
          results[1] as ({List<AgentModel> agents, int total});

      // Merge by id — library version wins (has up-to-date owned flag etc.)
      final byId = <int, AgentModel>{};
      for (final a in storeRes.agents) {
        byId[a.id] = a;
      }
      for (final a in library) {
        byId[a.id] = a;
      }
      libraryAgents.value = byId.values.toList();
    } finally {
      isLibraryLoading.value = false;
    }
  }

  // ── Thread helpers ──────────────────────────────────────────────────────────

  void _initThreads() {
    agentThreads.clear();
    for (final a in teamAgents) {
      final id = (a['id'] as num).toInt();
      agentThreads[id] = RxList<GuildChatMessage>([]);
    }
  }

  /// Returns the message list for [agentId], or [allMessages] if null.
  RxList<GuildChatMessage> getThread(int? agentId) {
    if (agentId == null) return allMessages;
    return agentThreads[agentId] ?? RxList<GuildChatMessage>([]);
  }


  // ── Team discovery ──────────────────────────────────────────────────────────

  Future<void> findTeam(String problem) async {
    final raw = problem.trim();
    if (raw.isEmpty) return;
    lastProblem = raw;
    phase.value = GuildMasterPhase.loading;
    error.value = null;

    // Expand #mission tags so the LLM sees the full mission prompt
    final expanded = await MissionService.instance.expandMissionTags(raw);
    final result = await ApiService.instance.suggestGuild(expanded);
    if (result == null) {
      error.value = 'Could not contact Guild Master. Check your connection.';
      phase.value = GuildMasterPhase.input;
      return;
    }

    final agents = (result['matching_agents'] as List<dynamic>? ?? [])
        .map((e) => e as Map<String, dynamic>)
        .toList();

    suggestion.value = result;
    teamAgents.value = agents;
    _initThreads();
    selectedAgentIds.value =
        agents.map((a) => (a['id'] as num).toInt()).toList();
    allMessages.clear();
    activeTabId.value = null;
    phase.value = GuildMasterPhase.ready;
  }

  // ── Per-agent selection ─────────────────────────────────────────────────────

  void toggleAgentSelection(int id) {
    if (selectedAgentIds.contains(id)) {
      selectedAgentIds.remove(id);
    } else {
      selectedAgentIds.add(id);
    }
  }

  /// Appends new agents to the current team, creating empty threads and
  /// auto-selecting them. Existing members (matched by id) are skipped.
  void addAgentsToTeam(List<Map<String, dynamic>> agents) {
    final existing = teamAgents
        .map((a) => (a['id'] as num).toInt())
        .toSet();
    var added = 0;
    for (final a in agents) {
      final id = (a['id'] as num?)?.toInt();
      if (id == null || existing.contains(id)) continue;
      teamAgents.add(a);
      agentThreads[id] = RxList<GuildChatMessage>([]);
      if (!selectedAgentIds.contains(id)) selectedAgentIds.add(id);
      existing.add(id);
      added++;
    }
    if (added > 0) {
      // Nudge reactive listeners watching the list.
      teamAgents.refresh();
    }
  }

  /// Sets or clears the team leader. Passing the currently-selected id clears.
  void setLeader(int? id) {
    if (id == null || leaderAgentId.value == id) {
      leaderAgentId.value = null;
    } else {
      leaderAgentId.value = id;
    }
  }

  void switchToTab(int? agentId) => activeTabId.value = agentId;

  // ── Broadcast send ──────────────────────────────────────────────────────────

  Future<void> sendBroadcast(String rawMessage) async {
    if (selectedAgentIds.isEmpty || isChatLoading.value) return;

    final trimmed = rawMessage.trim();
    if (trimmed.isEmpty) return;

    // Expand #mission tags before sending
    final expandedMessage =
        await MissionService.instance.expandMissionTags(trimmed);
    if (expandedMessage.isEmpty) return;

    // Determine routing: if an individual agent tab is active, this is a
    // private DM to that single agent. Otherwise, broadcast to all selected.
    final dmTargetId = activeTabId.value;
    final isPrivate = dmTargetId != null && selectedAgentIds.contains(dmTargetId);
    final recipients = isPrivate ? <int>[dmTargetId] : selectedAgentIds.toList();

    // Apply Team Leader coordination prefix when set (broadcast only).
    String message = expandedMessage;
    if (!isPrivate && leaderAgentId.value != null) {
      final leader = teamAgents.firstWhereOrNull(
        (a) => (a['id'] as num?)?.toInt() == leaderAgentId.value,
      );
      final leaderName = leader?['title'] as String? ?? 'Team Leader';
      message =
          '[Team Leader: $leaderName] Please coordinate: $expandedMessage';
    }

    // 1. Add user message to recipient threads.
    //    Display the raw text (with #mission-slug visible); send the
    //    prefixed/expanded version to the backend below.
    final userMsg = GuildChatMessage(
      id: _nextId(),
      isUser: true,
      text: trimmed,
    );
    for (final id in recipients) {
      agentThreads[id]?.add(userMsg);
    }

    if (isPrivate) {
      // Surface a lock marker in the combined "All" feed so the user knows
      // a private conversation just happened, without leaking the content.
      final targetAgent = teamAgents.firstWhereOrNull(
        (a) => (a['id'] as num?)?.toInt() == dmTargetId,
      );
      allMessages.add(GuildChatMessage(
        id: _nextId(),
        isUser: true,
        text: targetAgent?['title'] as String? ?? 'Agent',
        agentId: dmTargetId,
        agentTitle: targetAgent?['title'] as String?,
        isPrivateMarker: true,
      ));
    } else {
      allMessages.add(userMsg);
    }

    isChatLoading.value = true;

    // 2. Call backend — one call returns responses from all recipients
    final responses = await ApiService.instance.teamChat(
      message,
      recipients,
    );

    final agentReplies = <GuildChatMessage>[];

    if (responses == null) {
      isChatLoading.value = false;
      error.value = 'Agents did not respond. Check your connection and try again.';
      return;
    }

    if (responses.isNotEmpty) {
      for (final r in responses) {
        final agentId = (r['agent_id'] as num?)?.toInt();
        if (agentId == null) continue;

        final replyMsg = GuildChatMessage(
          id: _nextId(),
          isUser: false,
          text: (r['reply'] as String?) ?? '',
          agentId: agentId,
          agentTitle: r['agent_title'] as String?,
          characterType: r['character_type'] as String?,
          role: r['role'] as String?,
        );

        // Always route to the agent's own thread. Only surface in the "All"
        // feed for broadcasts; private DMs stay within the individual tab.
        agentThreads[agentId]?.add(replyMsg);
        if (!isPrivate) allMessages.add(replyMsg);
        agentReplies.add(replyMsg);
      }
    }

    isChatLoading.value = false;

    // 3. Trigger one round of cross-agent interaction when ≥2 agents replied.
    //    Skipped for private DMs (only a single recipient).
    if (!isPrivate && agentReplies.length >= 2) {
      isCrossLoading.value = true;
      await _crossAgentRound(message, agentReplies);
      isCrossLoading.value = false;
    }
  }

  // ── Cross-agent interaction ─────────────────────────────────────────────────
  //
  // After the initial responses, we send a "team discussion" prompt so agents
  // can briefly respond to each other's points.  The cross responses are added
  // to EVERY agent's thread (all team members see the discussion) and to the
  // "All" feed.

  Future<void> _crossAgentRound(
    String userMessage,
    List<GuildChatMessage> initialReplies,
  ) async {
    final summary = initialReplies
        .map((m) => '- ${m.agentTitle ?? 'Agent'}: "${m.text}"')
        .join('\n');

    final crossPrompt =
        '[TEAM DISCUSSION]\nUser asked: "$userMessage"\n\n'
        'Team responses:\n$summary\n\n'
        'Now briefly respond to what your colleagues said (1-2 sentences). '
        'Be specific about their points.';

    final cross = await ApiService.instance.teamChat(
      crossPrompt,
      selectedAgentIds.toList(),
    );

    if (cross == null) return;

    for (final r in cross) {
      final agentId = (r['agent_id'] as num?)?.toInt();
      if (agentId == null) continue;

      final crossMsg = GuildChatMessage(
        id: _nextId(),
        isUser: false,
        text: (r['reply'] as String?) ?? '',
        agentId: agentId,
        agentTitle: r['agent_title'] as String?,
        characterType: r['character_type'] as String?,
        role: r['role'] as String?,
        isCrossAgent: true,
      );

      // Cross-agent messages appear in ALL threads (team discussion)
      for (final thread in agentThreads.values) {
        thread.add(crossMsg);
      }
      allMessages.add(crossMsg);
    }
  }

  // ── Reset ───────────────────────────────────────────────────────────────────

  void reset() {
    lastProblem = '';
    phase.value = GuildMasterPhase.input;
    suggestion.value = null;
    teamAgents.clear();
    agentThreads.clear();
    selectedAgentIds.clear();
    leaderAgentId.value = null;
    allMessages.clear();
    activeTabId.value = null;
    error.value = null;
    exampleHint.value = null;
  }

  // ── Utilities ───────────────────────────────────────────────────────────────

  static int _msgCounter = 0;
  static String _nextId() =>
      '${DateTime.now().microsecondsSinceEpoch}-${++_msgCounter}';
}

