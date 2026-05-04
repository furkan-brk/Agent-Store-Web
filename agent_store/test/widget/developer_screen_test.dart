// Smoke widget tests for the Developer Settings screen.
//
// The screen calls ApiService.instance directly, so we can't drive a
// real create/revoke round-trip here. The tests focus on the contract
// the UI offers regardless of network state: the create button is
// reachable, the title is rendered, and the empty-state CTA carries
// the localized label. Heavier flows (modal submit, revoke confirm)
// belong in integration tests that mock the singleton.
//
// SettingsLayout reaches for GoRouterState, so we drive the screen
// through MaterialApp.router with a one-route config — cheaper than
// faking inherited widgets and keeps the rendered tree honest.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:agent_store/controllers/locale_controller.dart';
import 'package:agent_store/controllers/theme_controller.dart';
import 'package:agent_store/features/settings/screens/developer_screen.dart';
import 'package:agent_store/l10n/gen/app_localizations.dart';

Widget _wrap() {
  final router = GoRouter(
    initialLocation: '/settings/developer',
    routes: [
      GoRoute(path: '/settings', builder: (_, __) => const SizedBox.shrink()),
      GoRoute(
        path: '/settings/developer',
        builder: (_, __) => const DeveloperScreen(),
      ),
      GoRoute(
        path: '/settings/notifications',
        builder: (_, __) => const SizedBox.shrink(),
      ),
      GoRoute(
        path: '/settings/appearance',
        builder: (_, __) => const SizedBox.shrink(),
      ),
    ],
  );
  return MaterialApp.router(
    routerConfig: router,
    locale: const Locale('en'),
    localizationsDelegates: const [
      ...AppLocalizations.localizationsDelegates,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Get.reset();
    Get.put(LocaleController());
    Get.put(ThemeController());
  });

  testWidgets('renders the localized developer page header', (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.pump(); // first paint after router resolves
    // PageHeader uses the localized "Developer" string from app_en.arb.
    expect(find.text('Developer'), findsAtLeastNWidgets(1));
  });

  testWidgets('Create API Key button is present in header', (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.pump();
    // The trailing CTA in the PageHeader is the entry point to the modal.
    expect(find.text('Create API Key'), findsAtLeastNWidgets(1));
  });

  testWidgets('shows loading spinner before the keys list resolves', (tester) async {
    await tester.pumpWidget(_wrap());
    // Synchronous pump — the load() Future hasn't resolved, so the
    // body shows a CircularProgressIndicator.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
