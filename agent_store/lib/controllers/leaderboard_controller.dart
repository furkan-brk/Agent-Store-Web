import 'package:get/get.dart';
import '../shared/services/api_service.dart';

class LeaderboardController extends GetxController {
  final data = Rxn<Map<String, dynamic>>();
  final isLoading = true.obs;
  final error = RxnString();

  /// Active time window: 'all' | '7d' | '30d'
  final window = 'all'.obs;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load({String? forWindow}) async {
    final w = forWindow ?? window.value;
    window.value = w;
    isLoading.value = true;
    error.value = null;
    final result = await ApiService.instance.getLeaderboard(window: w);
    if (result != null) {
      data.value = result;
    } else {
      error.value = 'Failed to load leaderboard.';
    }
    isLoading.value = false;
  }

  void selectWindow(String w) {
    if (w == window.value) return;
    load(forWindow: w);
  }
}
