import 'package:get/get.dart';
import '../shared/models/guild_model.dart';
import '../shared/services/api_service.dart';

class GuildDetailController extends GetxController {
  final int guildId;
  GuildDetailController(this.guildId);

  final detail = Rxn<GuildDetailModel>();
  final isLoading = true.obs;
  final error = RxnString();
  final isJoining = false.obs;
  final hasJoined = false.obs;
  final selectedAgentIds = <int>[].obs;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    isLoading.value = true;
    error.value = null;
    try {
      final d = await ApiService.instance.getGuild(guildId);
      detail.value = d;
    } catch (e) {
      error.value = e.toString();
    }
    isLoading.value = false;
  }

  Future<void> joinGuild() async {
    isJoining.value = true;
    final ok = await ApiService.instance.joinGuild(guildId);
    if (ok) {
      hasJoined.value = true;
      await load();
    }
    isJoining.value = false;
  }

  Future<void> leaveGuild() async {
    isJoining.value = true;
    final ok = await ApiService.instance.leaveGuild(guildId);
    if (ok) {
      hasJoined.value = false;
      await load();
    }
    isJoining.value = false;
  }

  void toggleAgentSelection(int id) {
    if (selectedAgentIds.contains(id)) {
      selectedAgentIds.remove(id);
    } else {
      selectedAgentIds.add(id);
    }
  }

  Future<void> addMember(int agentId) async {
    final ok = await ApiService.instance.addGuildMember(guildId, agentId);
    if (ok) await load();
  }

  Future<void> removeMember(int agentId) async {
    final ok = await ApiService.instance.removeGuildMember(guildId, agentId);
    if (ok) await load();
  }
}
