import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

class AppTelemetryService extends GetxService {
  final Stopwatch _appSinceStart = Stopwatch()..start();
  bool _firstFrameLogged = false;
  String? _lastRoute;
  bool _firstRouteTransitionLogged = false;

  AppTelemetryService() {
    debugPrint('[telemetry] app_start=0ms');
  }

  void markFirstFrame() {
    if (_firstFrameLogged) return;
    _firstFrameLogged = true;
    debugPrint('[telemetry] first_frame_ms=${_appSinceStart.elapsedMilliseconds}');
  }

  void onRouteSeen(String route) {
    if (route.isEmpty) return;
    if (_lastRoute == null) {
      _lastRoute = route;
      debugPrint('[telemetry] initial_route=$route at ${_appSinceStart.elapsedMilliseconds}ms');
      return;
    }
    if (_lastRoute == route) return;

    final from = _lastRoute!;
    _lastRoute = route;
    final elapsed = _appSinceStart.elapsedMilliseconds;
    debugPrint('[telemetry] route_change $from -> $route at ${elapsed}ms');
    if (!_firstRouteTransitionLogged) {
      _firstRouteTransitionLogged = true;
      debugPrint('[telemetry] first_route_transition_ms=$elapsed');
    }
  }

  void logPreloadTier({
    required String tier,
    required int probeMs,
    required bool probeSuccess,
  }) {
    debugPrint(
      '[telemetry] preload_tier=$tier probe_ms=$probeMs probe_success=$probeSuccess',
    );
  }
}