// Unit tests for LocaleController.
//
// LocaleController owns the active app Locale and persists it through
// LocalKvStore (SharedPreferences in production). These tests assert
// the three contractually load-bearing behaviours: default fallback,
// persisted restore, and unknown-code fallback. They drive the GetX
// onInit lifecycle by hand so the controller's restore Future can
// actually be awaited.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:agent_store/controllers/locale_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Get.reset();
  });

  test('default locale is English when storage is empty', () async {
    final ctrl = LocaleController();
    ctrl.onInit();
    // Restore is async — yield once so the microtask fires.
    await Future<void>.delayed(Duration.zero);
    expect(ctrl.current.value, const Locale('en'));
  });

  test('setLocale persists to SharedPreferences and updates Rx', () async {
    final ctrl = LocaleController();
    ctrl.onInit();
    await Future<void>.delayed(Duration.zero);

    await ctrl.setLocale(const Locale('tr'));
    expect(ctrl.current.value, const Locale('tr'));

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('locale_v1'), 'tr');

    // A fresh controller should restore the persisted locale.
    final ctrl2 = LocaleController();
    ctrl2.onInit();
    await Future<void>.delayed(Duration.zero);
    expect(ctrl2.current.value, const Locale('tr'));
  });

  test('unknown persisted code falls back to default', () async {
    SharedPreferences.setMockInitialValues({'locale_v1': 'xx'});
    final ctrl = LocaleController();
    ctrl.onInit();
    await Future<void>.delayed(Duration.zero);
    expect(ctrl.current.value, const Locale('en'));
  });
}
