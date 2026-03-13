import 'package:get/get.dart';
import '../shared/services/api_service.dart';

class LeaderboardController extends GetxController {
  final data = Rxn<Map<String, dynamic>>();
  final isLoading = true.obs;
  final error = RxnString();

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    isLoading.value = true;
    error.value = null;
    final result = await ApiService.instance.getLeaderboard();
    if (result != null) {
      data.value = result;
    } else {
      error.value = 'Failed to load leaderboard.';
    }
    isLoading.value = false;
  }
}
