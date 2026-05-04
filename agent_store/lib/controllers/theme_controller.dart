// lib/controllers/theme_controller.dart
//
// GetX controller that owns the active ThemeMode (dark / light / system).
// Persists the choice in SharedPreferences so the user's preference
// survives a refresh. Default is dark — matches the original app shell.
//
// Used by main.dart's MaterialApp.router via Obx and by the Settings →
// Appearance theme radio.

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../shared/services/local_kv_store.dart';

class ThemeController extends GetxController {
  static const _kStorageKey = 'theme_mode_v1';

  static const ThemeMode defaultMode = ThemeMode.dark;

  static ThemeController get to => Get.find();

  final mode = defaultMode.obs;

  @override
  void onInit() {
    super.onInit();
    _restore();
  }

  Future<void> _restore() async {
    final raw = await LocalKvStore.instance.getString(_kStorageKey);
    if (raw == null || raw.isEmpty) return;
    final restored = _parse(raw);
    if (restored != null) mode.value = restored;
  }

  Future<void> setMode(ThemeMode m) async {
    mode.value = m;
    await LocalKvStore.instance.setString(_kStorageKey, _serialize(m));
  }

  static String _serialize(ThemeMode m) {
    switch (m) {
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.light:
        return 'light';
      case ThemeMode.system:
        return 'system';
    }
  }

  static ThemeMode? _parse(String raw) {
    switch (raw) {
      case 'dark':
        return ThemeMode.dark;
      case 'light':
        return ThemeMode.light;
      case 'system':
        return ThemeMode.system;
    }
    return null;
  }
}
