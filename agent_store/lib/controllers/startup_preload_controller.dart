import 'dart:async';

import 'package:get/get.dart';

import 'create_agent_controller.dart';
import 'creator_controller.dart';
import 'guild_controller.dart';
import 'leaderboard_controller.dart';
import 'library_controller.dart';
import 'store_controller.dart';
import '../shared/services/api_service.dart';

class StartupPreloadController extends GetxService {
  bool _started = false;

  void start() {
    if (_started) return;
    _started = true;
    // Start after startup path to avoid blocking first frame.
    unawaited(Future<void>.delayed(const Duration(milliseconds: 50), _preload));
  }

  Future<void> _preload() async {
    _ensure<StoreController>(() => StoreController());
    _ensure<GuildController>(() => GuildController());
    _ensure<LeaderboardController>(() => LeaderboardController());
    _ensure<CreateAgentController>(() => CreateAgentController());

    if (ApiService.instance.isAuthenticated) {
      _ensure<LibraryController>(() => LibraryController());
      _ensure<CreatorController>(() => CreatorController());
    }
  }

  T _ensure<T extends GetxController>(T Function() builder) {
    if (Get.isRegistered<T>()) return Get.find<T>();
    return Get.put<T>(builder(), permanent: true);
  }
}
