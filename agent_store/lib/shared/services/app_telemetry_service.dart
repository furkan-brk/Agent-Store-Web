import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

class AppTelemetryService extends GetxService {
  final Stopwatch _appSinceStart = Stopwatch()..start();
  Timer? _startupSummaryTimer;
  bool _firstFrameLogged = false;
  int? _firstFrameMs;
  int? _initialRouteMs;
  String? _initialRoute;
  String? _lastRoute;
  int _routeChangeCount = 0;
  bool _firstRouteTransitionLogged = false;
  int? _firstRouteTransitionMs;
  String? _preloadTier;
  int? _probeMs;
  bool? _probeSuccess;

  AppTelemetryService() {
    debugPrint('[telemetry] app_start=0ms');
    _startupSummaryTimer = Timer(const Duration(seconds: 5), _emitStartupSummary);
  }

  void markFirstFrame() {
    if (_firstFrameLogged) return;
    _firstFrameLogged = true;
    _firstFrameMs = _appSinceStart.elapsedMilliseconds;
    debugPrint('[telemetry] first_frame_ms=$_firstFrameMs');
  }

  void onRouteSeen(String route) {
    if (route.isEmpty) return;
    if (_lastRoute == null) {
      _lastRoute = route;
      _initialRoute = route;
      _initialRouteMs = _appSinceStart.elapsedMilliseconds;
      debugPrint('[telemetry] initial_route=$route at ${_initialRouteMs}ms');
      return;
    }
    if (_lastRoute == route) return;

    final from = _lastRoute!;
    _lastRoute = route;
    final elapsed = _appSinceStart.elapsedMilliseconds;
    _routeChangeCount++;
    debugPrint('[telemetry] route_change $from -> $route at ${elapsed}ms');
    if (!_firstRouteTransitionLogged) {
      _firstRouteTransitionLogged = true;
      _firstRouteTransitionMs = elapsed;
      debugPrint('[telemetry] first_route_transition_ms=$elapsed');
    }
  }

  void logPreloadTier({
    required String tier,
    required int probeMs,
    required bool probeSuccess,
  }) {
    _preloadTier = tier;
    _probeMs = probeMs;
    _probeSuccess = probeSuccess;
    debugPrint(
      '[telemetry] preload_tier=$tier probe_ms=$probeMs probe_success=$probeSuccess',
    );
  }

  void _emitStartupSummary() {
    final elapsed = _appSinceStart.elapsedMilliseconds;
    debugPrint(
      '[telemetry-summary] t=${elapsed}ms first_frame_ms=${_firstFrameMs ?? -1} '
      'initial_route=${_initialRoute ?? '-'} initial_route_ms=${_initialRouteMs ?? -1} '
      'first_route_transition_ms=${_firstRouteTransitionMs ?? -1} route_changes=$_routeChangeCount '
      'preload_tier=${_preloadTier ?? '-'} probe_ms=${_probeMs ?? -1} probe_success=${_probeSuccess ?? false}',
    );
  }

  @override
  void onClose() {
    _startupSummaryTimer?.cancel();
    super.onClose();
  }
}