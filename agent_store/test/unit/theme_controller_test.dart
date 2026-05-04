// Unit tests for ThemeController.
//
// Same shape as the LocaleController tests — verifies the default mode,
// persistence on setMode, and graceful fallback when SharedPreferences
// holds a value the controller no longer understands.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:agent_store/controllers/theme_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Get.reset();
  });

  test('default ThemeMode is dark when storage is empty', () async {
    final ctrl = ThemeController();
    ctrl.onInit();
    await Future<void>.delayed(Duration.zero);
    expect(ctrl.mode.value, ThemeMode.dark);
  });

  test('setMode persists and restores across instances', () async {
    final ctrl = ThemeController();
    ctrl.onInit();
    await Future<void>.delayed(Duration.zero);

    await ctrl.setMode(ThemeMode.light);
    expect(ctrl.mode.value, ThemeMode.light);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('theme_mode_v1'), 'light');

    final ctrl2 = ThemeController();
    ctrl2.onInit();
    await Future<void>.delayed(Duration.zero);
    expect(ctrl2.mode.value, ThemeMode.light);
  });

  test('unknown persisted value falls back to default dark mode', () async {
    SharedPreferences.setMockInitialValues({'theme_mode_v1': 'rainbow'});
    final ctrl = ThemeController();
    ctrl.onInit();
    await Future<void>.delayed(Duration.zero);
    expect(ctrl.mode.value, ThemeMode.dark);
  });
}
