import 'dart:async';

import 'package:get/get.dart';

import 'create_agent_controller.dart';
import 'creator_controller.dart';
import 'guild_controller.dart';
import 'guild_master_controller.dart';
import 'leaderboard_controller.dart';
import 'library_controller.dart';
import 'settings_controller.dart';
import 'store_controller.dart';
import '../shared/services/api_service.dart';
import '../shared/services/app_telemetry_service.dart';

enum _PreloadTier { fast, medium, slow }

class StartupPreloadController extends GetxService {
  bool _started = false;

  void start() {
    if (_started) return;
    _started = true;
    // Start after startup path to avoid blocking first frame.
    unawaited(Future<void>.delayed(const Duration(milliseconds: 50), _preload));
  }

  Future<void> _preload() async {
    // Stage 1: critical pages first.
    _ensure<StoreController>(() => StoreController());
    _ensure<GuildController>(() => GuildController());

    final probe = await ApiService.instance.probeNetwork();
    final tier = _resolveTier(probe.elapsedMs, probe.success);
    _telemetry.logPreloadTier(
      tier: tier.name,
      probeMs: probe.elapsedMs,
      probeSuccess: probe.success,
    );

    // Stage 2: progressively warm the rest based on network quality.
    switch (tier) {
      case _PreloadTier.fast:
        _preloadSecondary();
      case _PreloadTier.medium:
        _schedule(const Duration(milliseconds: 250), _preloadSecondary);
      case _PreloadTier.slow:
        _schedule(const Duration(milliseconds: 600), () {
          _ensure<CreateAgentController>(() => CreateAgentController());
          _ensure<SettingsController>(() => SettingsController());
        });
        _schedule(const Duration(milliseconds: 1400), () {
          _ensure<LeaderboardController>(() => LeaderboardController());
          _ensure<GuildMasterController>(() => GuildMasterController());
        });
        _schedule(const Duration(milliseconds: 2200), _preloadAuthHeavy);
    }
  }

  AppTelemetryService get _telemetry => Get.find<AppTelemetryService>();

  _PreloadTier _resolveTier(int elapsedMs, bool success) {
    if (!success) return _PreloadTier.slow;
    if (elapsedMs <= 350) return _PreloadTier.fast;
    if (elapsedMs <= 900) return _PreloadTier.medium;
    return _PreloadTier.slow;
  }

  void _preloadSecondary() {
    _ensure<CreateAgentController>(() => CreateAgentController());
    _ensure<LeaderboardController>(() => LeaderboardController());
    _ensure<SettingsController>(() => SettingsController());
    _ensure<GuildMasterController>(() => GuildMasterController());
    _preloadAuthHeavy();
  }

  void _preloadAuthHeavy() {
    if (!ApiService.instance.isAuthenticated) return;
    _ensure<LibraryController>(() => LibraryController());
    _ensure<CreatorController>(() => CreatorController());
  }

  void _schedule(Duration delay, void Function() task) {
    unawaited(Future<void>.delayed(delay, () {
      if (!_started) return;
      task();
    }));
  }

  T _ensure<T extends GetxController>(T Function() builder) {
    if (Get.isRegistered<T>()) return Get.find<T>();
    return Get.put<T>(builder(), permanent: true);
  }
}
