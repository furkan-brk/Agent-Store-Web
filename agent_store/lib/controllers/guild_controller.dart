import 'package:get/get.dart';
import '../shared/models/guild_model.dart';
import '../shared/services/api_service.dart';

class GuildController extends GetxController {
  final guilds = <GuildModel>[].obs;
  final isLoading = true.obs;
  final error = RxnString();

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    isLoading.value = true;
    error.value = null;
    try {
      final result = await ApiService.instance.listGuilds();
      guilds.value = result.guilds;
    } catch (e) {
      error.value = e.toString();
    }
    isLoading.value = false;
  }
}
