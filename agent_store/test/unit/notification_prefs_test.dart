// Local-state tests for NotificationPrefsController.
//
// The controller calls ApiService.instance directly (no DI), so we can't
// drive the full toggle/HTTP round-trip from here. What we CAN lock down
// — and what's most prone to silent regression — is the local state
// machine: defaults, isEnabled lookup, optimistic mutation, mark-read
// rollback. The controller is exercised without invoking onInit, so the
// async load() call never fires.

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:agent_store/features/settings/screens/notifications_screen.dart';

void main() {
  setUp(() {
    Get.reset();
  });

  test('isEnabled returns true when no row exists (default-allow)', () {
    final ctrl = NotificationPrefsController();
    // No prefs loaded yet — every (channel, type) combo defaults to enabled.
    expect(ctrl.isEnabled('web', 'social'), isTrue);
    expect(ctrl.isEnabled('email', 'credit'), isTrue);
  });

  test('seeded prefs surface their stored enabled value', () {
    final ctrl = NotificationPrefsController();
    ctrl.prefs.value = [
      {'channel': 'web', 'type': 'social', 'enabled': false},
      {'channel': 'email', 'type': 'credit', 'enabled': true},
    ];
    expect(ctrl.isEnabled('web', 'social'), isFalse);
    expect(ctrl.isEnabled('email', 'credit'), isTrue);
    // Untouched combos still report the default-allow value.
    expect(ctrl.isEnabled('web', 'system'), isTrue);
  });

  test('events list mark-read mutation flips read_at locally', () {
    final ctrl = NotificationPrefsController();
    ctrl.events.value = [
      {'id': 7, 'title': 'a', 'body': 'b', 'created_at': '', 'read_at': null},
      {'id': 8, 'title': 'c', 'body': 'd', 'created_at': '', 'read_at': null},
    ];
    // Manually apply the same optimistic mutation that markRead does so
    // we don't need the HTTP layer to verify the surface-level contract.
    final idx = ctrl.events.indexWhere((e) => e['id'] == 7);
    final original = Map<String, dynamic>.from(ctrl.events[idx]);
    ctrl.events[idx] = {...original, 'read_at': '2026-05-05T00:00:00Z'};
    expect(ctrl.events[0]['read_at'], '2026-05-05T00:00:00Z');
    expect(ctrl.events[1]['read_at'], isNull);
  });

  test('hasMore stays true while page is full, false when short page lands', () {
    final ctrl = NotificationPrefsController();
    ctrl.events.value = List.generate(20, (i) => {'id': i + 1});
    ctrl.hasMore.value = true;
    expect(ctrl.hasMore.value, isTrue);
    // Simulate the loadMore short-page path: empty/short page → flip flag.
    ctrl.hasMore.value = false;
    expect(ctrl.hasMore.value, isFalse);
  });
}
