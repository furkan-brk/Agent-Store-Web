import 'package:get/get.dart';

import '../../../shared/models/agent_model.dart';
import '../controllers/card_editor_controller.dart';

/// Hands a fresh [CardEditorController] to the screen for a given agent.
///
/// We don't lazyPut by tag here because the screen needs the controller
/// constructed with an [AgentModel] argument that's only available after
/// the initial fetch. Use [bind] from the screen once the agent loads.
class CardEditorBinding {
  CardEditorBinding._();

  /// Insert (or replace) the controller scoped to [agentId].
  static CardEditorController bind(AgentModel initial) {
    final tag = 'card_editor_${initial.id}';
    if (Get.isRegistered<CardEditorController>(tag: tag)) {
      Get.delete<CardEditorController>(tag: tag);
    }
    return Get.put(CardEditorController(initial: initial), tag: tag);
  }

  /// Clean up the controller when the screen is leaving.
  static void unbind(int agentId) {
    final tag = 'card_editor_$agentId';
    if (Get.isRegistered<CardEditorController>(tag: tag)) {
      Get.delete<CardEditorController>(tag: tag);
    }
  }
}
