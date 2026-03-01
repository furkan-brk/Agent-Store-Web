import 'package:get/get.dart';
import '../shared/services/api_service.dart';
import '../shared/services/wallet_service.dart';

class SettingsController extends GetxController {
  final isDarkMode = true.obs; // always dark in this app
  final notificationsEnabled = true.obs;

  bool get isAuthenticated => ApiService.instance.isAuthenticated;
  String? get wallet => WalletService.instance.connectedWallet;

  void toggleNotifications() => notificationsEnabled.toggle();

  Future<bool> deleteAccount() async {
    // Placeholder: clear local data
    WalletService.instance.disconnect();
    ApiService.instance.clearToken();
    return true;
  }
}
