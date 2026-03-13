import 'package:get/get.dart';
import '../shared/services/api_service.dart';

enum GuildMasterPhase { input, loading, ready }

class _Msg {
  final bool isUser;
  final String? userText;
  final List<Map<String, dynamic>>? teamResponses;
  const _Msg.user(String text) : isUser = true, userText = text, teamResponses = null;
  const _Msg.team(List<Map<String, dynamic>> r) : isUser = false, teamResponses = r, userText = null;
}

class GuildMasterController extends GetxController {
  // allow initialization with pre-loaded agents (from guild detail)
  final List<Map<String, dynamic>>? initialAgents;
  final String? initialGuildName;
  GuildMasterController({this.initialAgents, this.initialGuildName});

  final phase = GuildMasterPhase.input.obs;
  final suggestion = Rxn<Map<String, dynamic>>();
  final teamAgents = <Map<String, dynamic>>[].obs;
  final selectedAgentIds = <int>[].obs;
  final messages = <_Msg>[].obs;
  final isChatLoading = false.obs;
  final error = RxnString();

  @override
  void onInit() {
    super.onInit();
    if (initialAgents != null && initialAgents!.isNotEmpty) {
      teamAgents.addAll(initialAgents!);
      selectedAgentIds.addAll(initialAgents!.map((a) => (a['id'] as num).toInt()));
      suggestion.value = {
        'suggested_name': initialGuildName ?? 'Guild Team',
        'reasoning': 'Team assembled from your guild. Chat to collaborate!',
      };
      phase.value = GuildMasterPhase.ready;
    }
  }

  Future<void> findTeam(String problem) async {
    if (problem.trim().isEmpty) return;
    phase.value = GuildMasterPhase.loading;
    error.value = null;

    final result = await ApiService.instance.suggestGuild(problem.trim());
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
    selectedAgentIds.value = agents.map((a) => (a['id'] as num).toInt()).toList();
    messages.clear();
    phase.value = GuildMasterPhase.ready;
  }

  Future<void> sendChat(String message) async {
    if (message.trim().isEmpty || selectedAgentIds.isEmpty || isChatLoading.value) return;
    messages.add(_Msg.user(message));
    isChatLoading.value = true;

    final responses = await ApiService.instance.teamChat(message, selectedAgentIds.toList());
    if (responses != null && responses.isNotEmpty) {
      messages.add(_Msg.team(responses));
    }
    isChatLoading.value = false;
  }

  void toggleAgent(int id) {
    if (selectedAgentIds.contains(id)) {
      selectedAgentIds.remove(id);
    } else {
      selectedAgentIds.add(id);
    }
  }

  void reset() {
    phase.value = GuildMasterPhase.input;
    suggestion.value = null;
    teamAgents.clear();
    selectedAgentIds.clear();
    messages.clear();
    error.value = null;
  }
}

// expose _Msg for screens to use
typedef GuildMasterMsg = _Msg;
