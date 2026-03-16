import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'app/router.dart';
import 'app/theme.dart';
import 'controllers/auth_controller.dart';
import 'controllers/startup_preload_controller.dart';
import 'shared/services/api_service.dart';
import 'shared/services/app_telemetry_service.dart';
import 'shared/services/mission_service.dart';
import 'shared/services/wallet_service.dart';
import 'features/legend/services/legend_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Get.put(AppTelemetryService(), permanent: true);
  // Restore JWT and wallet address from SharedPreferences before anything else.
  // WalletService.init() also silently checks MetaMask via eth_accounts (no popup).
  await ApiService.instance.init();
  await MissionService.instance.init();
  await LegendService.instance.init();
  await WalletService.instance.init();
  // Register global AuthController — lives for the entire app lifetime.
  // By this point both services have their persisted state restored,
  // so AuthController.onInit() can read isAuthenticated + isConnected.
  Get.put(AuthController(), permanent: true);
  // Warm up frequently used page controllers in background.
  Get.put(StartupPreloadController(), permanent: true).start();
  runApp(const AgentStoreApp());
}

class AgentStoreApp extends StatelessWidget {
  const AgentStoreApp({super.key});

  @override
  Widget build(BuildContext context) {
    final telemetry = Get.find<AppTelemetryService>();
    return MaterialApp.router(
      title: 'Agent Store',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      routerConfig: AppRouter.router,
      builder: (context, child) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          telemetry.markFirstFrame();
        });
        return child ?? const SizedBox.shrink();
      },
    );
  }
}
