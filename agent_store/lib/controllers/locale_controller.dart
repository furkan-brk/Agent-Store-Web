// lib/controllers/locale_controller.dart
//
// GetX controller that owns the active app locale. Persists the choice in
// SharedPreferences so the user's language survives a refresh. Default
// fallback is English; an unknown persisted code also falls back to English.
//
// Used by main.dart's MaterialApp.router (via Obx) and by the Settings →
// Appearance language dropdown.

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../shared/services/local_kv_store.dart';

class LocaleController extends GetxController {
  static const _kStorageKey = 'locale_v1';

  /// Whitelist of locales we actually ship ARB files for. Anything else
  /// stored historically is treated as "use default".
  static const supportedCodes = <String>['en', 'tr'];

  static const Locale defaultLocale = Locale('en');

  static LocaleController get to => Get.find();

  final current = defaultLocale.obs;

  @override
  void onInit() {
    super.onInit();
    _restore();
  }

  Future<void> _restore() async {
    final raw = await LocalKvStore.instance.getString(_kStorageKey);
    if (raw == null || raw.isEmpty) return;
    if (!supportedCodes.contains(raw)) return;
    current.value = Locale(raw);
  }

  /// Switches the active locale and persists. Unknown codes are silently
  /// ignored so callers can pass whatever Flutter hands them.
  Future<void> setLocale(Locale locale) async {
    final code = locale.languageCode;
    if (!supportedCodes.contains(code)) return;
    current.value = Locale(code);
    await LocalKvStore.instance.setString(_kStorageKey, code);
  }
}
