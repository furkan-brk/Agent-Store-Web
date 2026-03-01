import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import '../../../features/character/character_types.dart';
import '../../../shared/models/agent_model.dart';
import '../../../shared/services/api_service.dart';
import '../../../shared/widgets/pixel_character_widget.dart';

class GuildCreateScreen extends StatelessWidget {
  const GuildCreateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.put(_GuildCreateController());
    final nameCtrl = TextEditingController();

    return Obx(() => Scaffold(
      backgroundColor: const Color(0xFFDDD1BB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFC8BA9A),
        foregroundColor: const Color(0xFF2B2C1E),
        title: const Text('Create Guild', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ),
      body: ctrl.isCreating.value
          ? const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              CircularProgressIndicator(color: Color(0xFF81231E)),
              SizedBox(height: 16),
              Text('Creating guild...', style: TextStyle(color: Color(0xFF6B5A40))),
            ]))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Guild Name', style: TextStyle(color: Color(0xFF6B5A40), fontSize: 12, letterSpacing: 1)),
                const SizedBox(height: 8),
                TextField(
                  controller: nameCtrl,
                  style: const TextStyle(color: Color(0xFF2B2C1E)),
                  decoration: InputDecoration(
                    hintText: 'e.g. Wizard-Oracle Guild',
                    hintStyle: const TextStyle(color: Color(0xFF5A5038)),
                    filled: true, fillColor: const Color(0xFFE8DEC9),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFC0B490))),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF81231E))),
                  ),
                ),
                const SizedBox(height: 24),
                Row(children: [
                  const Text('Select Members', style: TextStyle(color: Color(0xFF6B5A40), fontSize: 12, letterSpacing: 1)),
                  const SizedBox(width: 8),
                  Obx(() => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: const Color(0xFF81231E).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                    child: Text('${ctrl.selectedIds.length}/4', style: const TextStyle(color: Color(0xFF81231E), fontSize: 11, fontWeight: FontWeight.bold)),
                  )),
                ]),
                const SizedBox(height: 4),
                const Text('2–4 agents. Tip: Mix different types for synergy bonuses.', style: TextStyle(color: Color(0xFF5A5038), fontSize: 11)),
                const SizedBox(height: 12),
                if (ctrl.isLoadingAgents.value)
                  const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator(color: Color(0xFF81231E))))
                else
                  Obx(() => _AgentSelector(
                    agents: ctrl.allAgents,
                    selectedIds: ctrl.selectedIds.toList(),
                    onToggle: ctrl.toggleAgent,
                  )),
                Obx(() {
                  if (ctrl.error.value != null) {
                    return Padding(padding: const EdgeInsets.only(top: 12), child: Text(ctrl.error.value!, style: const TextStyle(color: Color(0xFF81231E), fontSize: 12)));
                  }
                  return const SizedBox.shrink();
                }),
                const SizedBox(height: 24),
                Obx(() => SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: const Color(0xFF81231E), padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                    onPressed: ctrl.selectedIds.length >= 2 ? () => ctrl.create(nameCtrl.text, context) : null,
                    child: const Text('Create Guild', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  ),
                )),
              ]),
            ),
    ));
  }
}

// ── Local controller ──────────────────────────────────────────────────────────

class _GuildCreateController extends GetxController {
  final allAgents = <AgentModel>[].obs;
  final selectedIds = <int>[].obs;
  final isLoadingAgents = true.obs;
  final isCreating = false.obs;
  final error = RxnString();

  @override
  void onInit() { super.onInit(); _loadAgents(); }

  Future<void> _loadAgents() async {
    final result = await ApiService.instance.listAgents(limit: 50);
    allAgents.value = result.agents;
    isLoadingAgents.value = false;
  }

  void toggleAgent(int id) {
    if (selectedIds.contains(id)) {
      selectedIds.remove(id);
    } else if (selectedIds.length < 4) selectedIds.add(id);
  }

  Future<void> create(String name, BuildContext ctx) async {
    final n = name.trim();
    if (n.isEmpty) { error.value = 'Guild name is required'; return; }
    if (selectedIds.isEmpty) { error.value = 'Select at least one agent'; return; }
    if (selectedIds.length > 4) { error.value = 'Max 4 members per guild'; return; }

    isCreating.value = true; error.value = null;
    final guild = await ApiService.instance.createGuild(name: n);
    if (guild == null) { error.value = 'Failed to create guild'; isCreating.value = false; return; }
    for (final agentId in selectedIds) {
      await ApiService.instance.addGuildMember(guild.id, agentId);
    }
    isCreating.value = false;
    if (ctx.mounted) ctx.go('/guild/${guild.id}');
  }
}

// ── Agent selector (pure stateless) ──────────────────────────────────────────

class _AgentSelector extends StatelessWidget {
  final List<AgentModel> agents;
  final List<int> selectedIds;
  final void Function(int) onToggle;
  const _AgentSelector({required this.agents, required this.selectedIds, required this.onToggle});

  @override
  Widget build(BuildContext context) => GridView.builder(
    shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 160, mainAxisExtent: 190, crossAxisSpacing: 10, mainAxisSpacing: 10),
    itemCount: agents.length,
    itemBuilder: (_, i) {
      final agent = agents[i];
      final selected = selectedIds.contains(agent.id);
      final rc = agent.rarity.color;
      return InkWell(
        onTap: () => onToggle(agent.id),
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF81231E).withValues(alpha: 0.12) : const Color(0xFFE8DEC9),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: selected ? const Color(0xFF81231E) : rc.withValues(alpha: 0.25), width: selected ? 2 : 1),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            PixelCharacterWidget(characterType: agent.characterType, rarity: agent.rarity, subclass: agent.subclass, size: 72, agentId: agent.id),
            const SizedBox(height: 6),
            Text(agent.title, style: const TextStyle(color: Color(0xFF2B2C1E), fontSize: 10, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text('${agent.characterType.displayName} · ${agent.subclass.displayName}', style: TextStyle(color: agent.characterType.accentColor, fontSize: 8), maxLines: 1, overflow: TextOverflow.ellipsis),
            if (selected) const Padding(padding: EdgeInsets.only(top: 4), child: Icon(Icons.check_circle, color: Color(0xFF81231E), size: 14)),
          ]),
        ),
      );
    },
  );
}
