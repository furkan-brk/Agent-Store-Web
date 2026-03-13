import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../shared/models/agent_model.dart';
import '../../../shared/services/api_service.dart';
import '../../store/widgets/agent_card.dart';
import 'package:go_router/go_router.dart';

class PublicProfileScreen extends StatelessWidget {
  final String wallet;
  const PublicProfileScreen({super.key, required this.wallet});

  @override
  Widget build(BuildContext context) {
    // Use a unique tag per wallet so controllers don't clash
    final ctrl = Get.put(_PublicProfileController(wallet), tag: wallet);
    return Obx(() => Scaffold(
      backgroundColor: const Color(0xFFDDD1BB),
      body: CustomScrollView(slivers: [
        SliverAppBar(
          backgroundColor: const Color(0xFFC8BA9A),
          pinned: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF2B2C1E), size: 18),
            onPressed: () => context.canPop() ? context.pop() : context.go('/'),
          ),
          title: Text(_shorten(wallet), style: const TextStyle(color: Color(0xFF2B2C1E), fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
          centerTitle: false,
        ),
        if (ctrl.isLoading.value)
          const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
        else if (ctrl.error.value != null)
          SliverFillRemaining(child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.error_outline, color: Color(0xFF7A6E52), size: 56),
            const SizedBox(height: 12),
            Text(ctrl.error.value!, style: const TextStyle(color: Color(0xFF6B5A40), fontSize: 16)),
            const SizedBox(height: 20),
            TextButton(onPressed: ctrl.load, child: const Text('Retry', style: TextStyle(color: Color(0xFF81231E)))),
          ])))
        else ...[
          SliverToBoxAdapter(child: _ProfileHeader(wallet: wallet, ctrl: ctrl)),
          if (ctrl.agents.isEmpty)
            const SliverFillRemaining(child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.auto_awesome_outlined, color: Color(0xFFC0B490), size: 56),
              SizedBox(height: 12),
              Text('No agents created yet', style: TextStyle(color: Color(0xFF6B5A40), fontSize: 16)),
            ])))
          else
            SliverPadding(
              padding: const EdgeInsets.all(24),
              sliver: SliverGrid(
                delegate: SliverChildBuilderDelegate((_, i) => AgentCard(agent: ctrl.agents[i]), childCount: ctrl.agents.length),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 300, crossAxisSpacing: 16, mainAxisSpacing: 16, childAspectRatio: 0.72),
              ),
            ),
        ],
      ]),
    ));
  }

  static String _shorten(String w) => w.length > 10 ? '${w.substring(0, 6)}...${w.substring(w.length - 4)}' : w;
}

class _ProfileHeader extends StatelessWidget {
  final String wallet;
  final _PublicProfileController ctrl;
  const _ProfileHeader({required this.wallet, required this.ctrl});

  @override
  Widget build(BuildContext context) => Container(
    color: const Color(0xFFC8BA9A),
    padding: const EdgeInsets.fromLTRB(32, 24, 32, 28),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(width: 52, height: 52,
          decoration: BoxDecoration(color: const Color(0xFF81231E).withValues(alpha: 0.15), shape: BoxShape.circle, border: Border.all(color: const Color(0xFF81231E).withValues(alpha: 0.4))),
          child: const Icon(Icons.person_outline, color: Color(0xFF81231E), size: 28)),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(PublicProfileScreen._shorten(wallet), style: const TextStyle(color: Color(0xFF2B2C1E), fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
          const SizedBox(height: 6),
          Row(children: [
            _StatChip(label: 'Agents', value: '${ctrl.agentCount}'),
            const SizedBox(width: 12),
            Container(width: 1, height: 14, color: const Color(0xFFC0B490)),
            const SizedBox(width: 12),
            _StatChip(label: 'Total Saves', value: '${ctrl.totalSaves}'),
          ]),
        ])),
      ]),
      const SizedBox(height: 20),
      const Divider(color: Color(0xFFADA07A), height: 1),
      const SizedBox(height: 16),
      const Text('Created Agents', style: TextStyle(color: Color(0xFF6B5A40), fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
    ]),
  );
}

class _StatChip extends StatelessWidget {
  final String label; final String value;
  const _StatChip({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => RichText(text: TextSpan(children: [
    TextSpan(text: value, style: const TextStyle(color: Color(0xFF2B2C1E), fontWeight: FontWeight.bold, fontSize: 15)),
    TextSpan(text: '  $label', style: const TextStyle(color: Color(0xFF7A6E52), fontSize: 13)),
  ]));
}

// ── Local micro-controller ────────────────────────────────────────────────────

class _PublicProfileController extends GetxController {
  final String wallet;
  _PublicProfileController(this.wallet);

  final profile = Rxn<Map<String, dynamic>>();
  final agents = <AgentModel>[].obs;
  final isLoading = true.obs;
  final error = RxnString();

  int get agentCount => (profile.value?['agent_count'] as num?)?.toInt() ?? agents.length;
  int get totalSaves => (profile.value?['total_saves'] as num?)?.toInt() ?? agents.fold(0, (s, a) => s + a.saveCount);

  @override
  void onInit() { super.onInit(); load(); }

  Future<void> load() async {
    isLoading.value = true;
    error.value = null;
    try {
      final result = await ApiService.instance.getPublicProfile(wallet);
      if (result == null) { error.value = 'Profile not found.'; }
      else {
        profile.value = result;
        agents.value = (result['agents'] as List<dynamic>? ?? []).map((e) => AgentModel.fromJson(e as Map<String, dynamic>)).toList();
      }
    } catch (_) { error.value = 'Failed to load profile.'; }
    isLoading.value = false;
  }
}
