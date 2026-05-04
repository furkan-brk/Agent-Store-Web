// Widget tests for the v3.11.1 Step 0 credit warning banner.
//
// We can't import _CreditWarningBanner directly (private to
// create_agent_screen.dart), so we test the public-facing surface:
// CreateAgentController.hasInsufficientCredits + kAgentCost contract.
// The widget render is exercised by the screen's integration test
// in v3.11.x deferred suite.

import 'package:agent_store/controllers/create_agent_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

void main() {
  setUp(() {
    Get.testMode = true;
    if (Get.isRegistered<CreateAgentController>()) {
      Get.delete<CreateAgentController>(force: true);
    }
  });

  tearDown(() {
    if (Get.isRegistered<CreateAgentController>()) {
      Get.delete<CreateAgentController>(force: true);
    }
  });

  group('CreateAgentController.hasInsufficientCredits', () {
    test('credits < kAgentCost (10) → true', () {
      final c = Get.put(CreateAgentController());
      c.credits.value = 5;
      expect(c.hasInsufficientCredits, isTrue);
    });

    test('credits == kAgentCost (10) → false', () {
      final c = Get.put(CreateAgentController());
      c.credits.value = CreateAgentController.kAgentCost;
      expect(c.hasInsufficientCredits, isFalse);
    });

    test('credits >> kAgentCost (10) → false', () {
      final c = Get.put(CreateAgentController());
      c.credits.value = 100;
      expect(c.hasInsufficientCredits, isFalse);
    });

    test('cost constant is 10 (matches publish button label)', () {
      expect(CreateAgentController.kAgentCost, 10);
    });
  });
}
