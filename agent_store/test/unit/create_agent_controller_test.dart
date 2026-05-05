// Unit tests for CreateAgentController.
//
// CreateAgentController calls ApiService.instance directly (no DI). The
// `submit()` flow makes an http.post that takes 120 s and isn't testable
// without a real backend, so we focus on:
//   - step navigation (clamped to [0, 2])
//   - keyword-based character detection (deterministic per prompt)
//   - reset() returns to defaults
//   - hasInsufficientCredits derives correctly from credits Rx
//   - refreshCredits is a no-op when unauthenticated (returns 0 from
//     ApiService — which the controller then writes into credits)

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:agent_store/controllers/create_agent_controller.dart';
import 'package:agent_store/features/character/character_types.dart';
import 'package:agent_store/shared/services/api_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Get.reset();
    ApiService.instance.clearToken();
  });

  tearDown(() => Get.reset());

  test('initial step is 0 with default loading state', () {
    final c = CreateAgentController();
    expect(c.step.value, 0);
    expect(c.isLoading.value, isFalse);
    expect(c.preview.value, CharacterType.wizard);
    expect(c.createdAgent.value, isNull);
  });

  test('nextStep increments and clamps at 2', () {
    final c = CreateAgentController();
    c.nextStep();
    expect(c.step.value, 1);
    c.nextStep();
    expect(c.step.value, 2);
    c.nextStep(); // already at max — must clamp.
    expect(c.step.value, 2);
  });

  test('prevStep decrements and clamps at 0', () {
    final c = CreateAgentController();
    c.step.value = 1;
    c.prevStep();
    expect(c.step.value, 0);
    c.prevStep(); // already at min — must not go negative.
    expect(c.step.value, 0);
  });

  test('reset() returns step / preview / createdAgent / isLoading to defaults',
      () {
    final c = CreateAgentController();
    c.step.value = 2;
    c.isLoading.value = true;
    c.preview.value = CharacterType.bard;

    c.reset();
    expect(c.step.value, 0);
    expect(c.isLoading.value, isFalse);
    expect(c.preview.value, CharacterType.wizard);
    expect(c.createdAgent.value, isNull);
  });

  test('detectCharacterType picks wizard for backend keywords', () {
    final c = CreateAgentController();
    c.detectCharacterType(
      'You are an expert backend Python Golang API developer working with SQL '
      'databases, Docker, Kubernetes, and microservices.',
    );
    expect(c.preview.value, CharacterType.wizard);
  });

  test('detectCharacterType picks bard for creative-writing keywords', () {
    final c = CreateAgentController();
    c.detectCharacterType(
      'You write creative stories, blog content, poems, and dialogue with '
      'a strong narrative voice.',
    );
    expect(c.preview.value, CharacterType.bard);
  });

  test('detectCharacterType picks artisan for design / UI keywords', () {
    final c = CreateAgentController();
    c.detectCharacterType(
      'You are a frontend Flutter UI UX designer who builds responsive '
      'layouts with CSS and Tailwind components.',
    );
    expect(c.preview.value, CharacterType.artisan);
  });

  test('hasInsufficientCredits flips at the kAgentCost boundary', () {
    final c = CreateAgentController();

    c.credits.value = 0;
    expect(c.hasInsufficientCredits, isTrue);

    c.credits.value = 9;
    expect(c.hasInsufficientCredits, isTrue);

    c.credits.value = CreateAgentController.kAgentCost; // 10
    expect(c.hasInsufficientCredits, isFalse);

    c.credits.value = 50;
    expect(c.hasInsufficientCredits, isFalse);
  });

  test('refreshCredits is a no-op when unauthenticated', () async {
    final c = CreateAgentController();
    c.credits.value = 42; // pretend we had a previous balance
    expect(ApiService.instance.isAuthenticated, isFalse);

    await c.refreshCredits();
    // The early-return in refreshCredits leaves the Rx untouched.
    expect(c.credits.value, 42);
  });

  test('keywordsFor returns the bundled keyword list for each type', () {
    // Public accessor used by the prompt-quality card. Smoke-test that the
    // wiring exposes a non-empty list per type and that the lists are
    // type-specific (wizard ≠ bard).
    final wizardKw = CreateAgentController.keywordsFor(CharacterType.wizard);
    final bardKw = CreateAgentController.keywordsFor(CharacterType.bard);

    expect(wizardKw, isNotEmpty);
    expect(bardKw, isNotEmpty);
    expect(wizardKw, contains('backend'));
    expect(bardKw, contains('story'));
    // Type-specific — the two lists shouldn't be identical.
    expect(wizardKw, isNot(equals(bardKw)));
  });

  test('stepLabels has exactly three labels in order', () {
    expect(CreateAgentController.stepLabels, ['Basic Info', 'Prompt', 'Preview']);
  });
}
