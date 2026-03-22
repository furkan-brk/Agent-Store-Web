import 'dart:math';
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

  static final _rng = Random();

  /// Keyword map for scoring-based character type detection.
  /// Each type has ~30 keywords; all types compete equally via score count.
  static const _keywords = <CharacterType, List<String>>{
    CharacterType.wizard: [
      'backend', 'golang', 'python', 'api', 'database', 'server', 'code',
      'developer', 'sql', 'java', 'programmer', 'rust', 'typescript',
      'javascript', 'node', 'docker', 'kubernetes', 'microservice', 'cli',
      'script', 'algorithm', 'compiler', 'debug', 'refactor', 'git',
      'deploy', 'terraform', 'lambda', 'redis', 'mongodb', 'graphql',
      'grpc', 'yazılım', 'programlama',
    ],
    CharacterType.strategist: [
      'plan', 'strategy', 'project', 'manager', 'roadmap', 'agile',
      'scrum', 'task', 'lead', 'coordinate', 'prioritize', 'deadline',
      'sprint', 'okr', 'milestone', 'kanban', 'delegate', 'decision',
      'stakeholder', 'timeline', 'objective', 'organize', 'schedule',
      'workflow', 'yönetim', 'hedef', 'planlama',
    ],
    CharacterType.oracle: [
      'data', 'analytics', 'insight', 'statistics', 'machine learning',
      'neural', 'deep learning', 'dataset', 'visualization', 'prediction',
      'tableau', 'pandas', 'numpy', 'tensorflow', 'pytorch', 'regression',
      'classification', 'clustering', 'nlp', 'llm', 'embedding', 'vector',
      'rag', 'model', 'forecast', 'metric', 'dashboard', 'bigquery',
      'analiz', 'veri', 'tahmin',
    ],
    CharacterType.guardian: [
      'security', 'firewall', 'pentest', 'infra', 'hacker', 'encrypt',
      'auth', 'vulnerability', 'devops', 'cloud', 'aws', 'azure',
      'monitoring', 'backup', 'ssl', 'tls', 'oauth', 'jwt',
      'compliance', 'audit', 'sre', 'incident', 'malware', 'phishing',
      'vpn', 'proxy', 'sandbox', 'güvenlik', 'koruma', 'şifre',
    ],
    CharacterType.artisan: [
      'frontend', 'ui', 'ux', 'design', 'flutter', 'react', 'css',
      'figma', 'prototype', 'responsive', 'layout', 'animation',
      'tailwind', 'component', 'widget', 'wireframe', 'pixel',
      'typography', 'icon', 'illustration', 'accessibility', 'swiftui',
      'html', 'sass', 'bootstrap', 'tasarım', 'arayüz', 'görsel',
    ],
    CharacterType.bard: [
      'write', 'story', 'creative', 'content', 'blog', 'copy', 'poem',
      'translate', 'email', 'summarize', 'tone', 'chat', 'conversation',
      'dialogue', 'screenplay', 'novel', 'fiction', 'essay', 'slogan',
      'headline', 'caption', 'speech', 'presentation', 'pitch',
      'narrative', 'persona', 'roleplay', 'letter', 'hikaye', 'çeviri',
      'şiir', 'metin',
    ],
    CharacterType.scholar: [
      'research', 'study', 'academic', 'science', 'learn', 'explain',
      'teach', 'tutor', 'knowledge', 'history', 'math', 'physics',
      'chemistry', 'biology', 'philosophy', 'literature', 'encyclopedia',
      'thesis', 'paper', 'journal', 'lecture', 'curriculum', 'exam',
      'university', 'professor', 'textbook', 'quiz', 'homework',
      'eğitim', 'öğren', 'bilim', 'ders', 'araştır',
    ],
    CharacterType.merchant: [
      'business', 'sales', 'marketing', 'growth', 'revenue', 'startup',
      'finance', 'ecommerce', 'pricing', 'customer', 'roi', 'brand',
      'negotiate', 'profit', 'investment', 'stock', 'crypto', 'blockchain',
      'seo', 'ads', 'campaign', 'funnel', 'conversion', 'churn',
      'retention', 'b2b', 'saas', 'ticaret', 'pazarlama', 'müşteri',
      'gelir', 'fiyat', 'satış',
    ],
  };

  void detectCharacterType(String promptText) {
    final p = promptText.toLowerCase();
    final scores = <CharacterType, int>{};
    for (final entry in _keywords.entries) {
      int score = 0;
      for (final kw in entry.value) {
        if (p.contains(kw)) score++;
      }
      if (score > 0) scores[entry.key] = score;
    }
    CharacterType? t;
    if (scores.isNotEmpty) {
      t = scores.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
    }
    // Random fallback when no keywords match (mirrors backend behavior)
    t ??= CharacterType.values[_rng.nextInt(CharacterType.values.length)];
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
