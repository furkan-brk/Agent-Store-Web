import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../shared/models/agent_model.dart';
import '../shared/services/api_service.dart';
import '../features/character/character_types.dart';

class CreateAgentController extends GetxController {
  final step = 0.obs;
  final isLoading = false.obs;
  final loadingMsg = 'Analyzing prompt…'.obs;
  final preview = CharacterType.wizard.obs;
  final createdAgent = Rxn<AgentModel>();
  final credits = 100.obs;

  static const stepLabels = ['Basic Info', 'Prompt', 'Preview'];

  @override
  void onInit() {
    super.onInit();
    refreshCredits();
  }

  /// Refresh credits from API. Called on init and before every submission.
  Future<void> refreshCredits() async {
    if (ApiService.instance.isAuthenticated) {
      credits.value = await ApiService.instance.getCredits();
    }
  }

  void detectCharacterType(String promptText) {
    final p = promptText.toLowerCase();
    CharacterType t = CharacterType.wizard;
    if (p.contains('plan') || p.contains('strateg') || p.contains('manager')) {
      t = CharacterType.strategist;
    } else if (p.contains('data') || p.contains('analyt') || p.contains('ml')) {
      t = CharacterType.oracle;
    } else if (p.contains('security') || p.contains('infra')) {
      t = CharacterType.guardian;
    } else if (p.contains('frontend') || p.contains('ui') || p.contains('design')) {
      t = CharacterType.artisan;
    } else if (p.contains('write') || p.contains('creat') || p.contains('story')) {
      t = CharacterType.bard;
    } else if (p.contains('research') || p.contains('learn') || p.contains('study')) {
      t = CharacterType.scholar;
    } else if (p.contains('business') || p.contains('sales') || p.contains('market')) {
      t = CharacterType.merchant;
    }
    preview.value = t;
  }

  Future<bool> checkCredits(BuildContext context) async {
    // Always refresh from API before checking — prevents stale values
    await refreshCredits();
    const agentCost = 10;
    if (credits.value < agentCost) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Insufficient credits: ${credits.value}/10. Top up to create an agent.'),
          backgroundColor: Colors.orange.shade800,
        ));
      }
      return false;
    }
    return true;
  }

  void nextStep() => step.value = (step.value + 1).clamp(0, 2);
  void prevStep() { if (step.value > 0) step.value--; }

  Future<AgentModel?> submit(String title, String description, String prompt) async {
    isLoading.value = true;
    loadingMsg.value = 'Analyzing prompt…';

    Future.delayed(const Duration(seconds: 4), () {
      if (isLoading.value) loadingMsg.value = 'Building character profile…';
    });
    Future.delayed(const Duration(seconds: 14), () {
      if (isLoading.value) loadingMsg.value = 'Generating avatar image…';
    });
    Future.delayed(const Duration(seconds: 55), () {
      if (isLoading.value) loadingMsg.value = 'Almost there…';
    });

    final agent = await ApiService.instance.createAgent(
      title: title, description: description, prompt: prompt,
    );
    isLoading.value = false;
    if (agent != null) createdAgent.value = agent;
    return agent;
  }

  void reset() {
    step.value = 0;
    isLoading.value = false;
    createdAgent.value = null;
    preview.value = CharacterType.wizard;
  }
}
