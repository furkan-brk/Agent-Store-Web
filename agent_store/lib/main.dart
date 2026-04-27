import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:get/get.dart';
import 'app/router.dart';
import 'app/theme.dart';
import 'controllers/auth_controller.dart';
import 'controllers/startup_preload_controller.dart';
import 'shared/services/api_service.dart';
import 'shared/services/app_telemetry_service.dart';
import 'shared/services/mission_service.dart';
import 'shared/services/network_guard.dart';
import 'shared/services/wallet_service.dart';
import 'features/legend/services/legend_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) {
    // Keep routes stable on refresh and avoid mixed path/hash URLs.
    usePathUrlStrategy();
  }
  Get.put(AppTelemetryService(), permanent: true);
  // Restore JWT and wallet address from LocalKvStore before anything else.
  // WalletService.init() also silently checks MetaMask via eth_accounts (no popup).
  await ApiService.instance.init();
  await MissionService.instance.init();
  await LegendService.instance.init();
  await WalletService.instance.init();
  // Register global AuthController — lives for the entire app lifetime.
  // By this point both services have their persisted state restored,
  // so AuthController.onInit() can read isAuthenticated + isConnected.
  Get.put(AuthController(), permanent: true);
  // NetworkGuard watches MetaMask chainChanged events and exposes
  // onCorrectNetwork / currentChainId to the AppShell banner.
  Get.put(NetworkGuard(), permanent: true);
  // Warm up frequently used page controllers in background.
  Get.put(StartupPreloadController(), permanent: true).start();
  runApp(const AgentStoreApp());
}

class AgentStoreApp extends StatelessWidget {
  const AgentStoreApp({super.key});

  static bool _firstFrameMarked = false;

  @override
  Widget build(BuildContext context) {
    final telemetry = Get.find<AppTelemetryService>();
    return MaterialApp.router(
      title: 'Agent Store',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      routerConfig: AppRouter.router,
      builder: (context, child) {
        if (!_firstFrameMarked) {
          _firstFrameMarked = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            telemetry.markFirstFrame();
          });
        }
        return child ?? const SizedBox.shrink();
      },
    );
  }
}
