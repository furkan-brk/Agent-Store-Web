import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme.dart';
import '../../../features/character/character_types.dart';
import '../../../shared/models/agent_model.dart';
import '../../../shared/services/api_service.dart';
import '../../../shared/widgets/pixel_character_widget.dart';
import '../../../shared/widgets/skeleton_widgets.dart';

class GuildCreateScreen extends StatefulWidget {
  const GuildCreateScreen({super.key});

  @override
  State<GuildCreateScreen> createState() => _GuildCreateScreenState();
}

class _GuildCreateScreenState extends State<GuildCreateScreen> {
  late final _GuildCreateController _ctrl;
  final _nameCtrl = TextEditingController();
  final _nameFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _ctrl = Get.put(_GuildCreateController());
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() => Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        foregroundColor: AppTheme.textH,
        elevation: 0,
        title: const Text('Create Guild', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textH)),
      ),
      body: _ctrl.isCreating.value
          ? _buildCreatingState()
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // -- Page header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Row(children: [
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.groups_rounded, color: AppTheme.primary, size: 24),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Create a New Guild', style: TextStyle(color: AppTheme.textH, fontSize: 16, fontWeight: FontWeight.bold)),
                      SizedBox(height: 4),
                      Text('Unite 2-4 agents for powerful synergy bonuses', style: TextStyle(color: AppTheme.textM, fontSize: 12)),
                    ])),
                  ]),
                ),
                const SizedBox(height: 28),

                // -- Guild Name section
                const _SectionLabel(label: 'Guild Name', icon: Icons.edit_rounded),
                const SizedBox(height: 10),
                TextField(
                  controller: _nameCtrl,
                  focusNode: _nameFocus,
                  style: const TextStyle(color: AppTheme.textH, fontSize: 14),
                  maxLength: 40,
                  decoration: InputDecoration(
                    hintText: 'e.g. Wizard-Oracle Guild',
                    hintStyle: const TextStyle(color: AppTheme.textM, fontSize: 13),
                    filled: true,
                    fillColor: AppTheme.card,
                    counterStyle: const TextStyle(color: AppTheme.textM, fontSize: 10),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.border)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.border)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.primary, width: 1.5)),
                  ),
                ),
                const SizedBox(height: 24),

                // -- Select Members section
                Row(children: [
                  const _SectionLabel(label: 'Select Members', icon: Icons.person_add_rounded),
                  const SizedBox(width: 10),
                  Obx(() => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _ctrl.selectedIds.length >= 2
                          ? const Color(0xFF5A8A48).withValues(alpha: 0.15)
                          : AppTheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _ctrl.selectedIds.length >= 2
                            ? const Color(0xFF5A8A48).withValues(alpha: 0.3)
                            : AppTheme.primary.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Text(
                      '${_ctrl.selectedIds.length}/4',
                      style: TextStyle(
                        color: _ctrl.selectedIds.length >= 2 ? const Color(0xFF5A8A48) : AppTheme.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )),
                ]),
                const SizedBox(height: 6),
                const Text(
                  'Select 2-4 agents. Tip: Mix different types for synergy bonuses.',
                  style: TextStyle(color: AppTheme.textM, fontSize: 11),
                ),
                const SizedBox(height: 16),

                // -- Agent grid
                if (_ctrl.isLoadingAgents.value)
                  _buildAgentLoadingSkeleton()
                else if (_ctrl.allAgents.isEmpty)
                  _buildNoAgentsState()
                else
                  Obx(() => _AgentSelector(
                    agents: _ctrl.allAgents,
                    selectedIds: _ctrl.selectedIds.toList(),
                    onToggle: _ctrl.toggleAgent,
                  )),

                // -- Error message
                Obx(() {
                  if (_ctrl.error.value != null) {
                    return Container(
                      margin: const EdgeInsets.only(top: 16),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
                      ),
                      child: Row(children: [
                        const Icon(Icons.warning_amber_rounded, color: AppTheme.primary, size: 16),
                        const SizedBox(width: 8),
                        Expanded(child: Text(
                          _ctrl.error.value!,
                          style: const TextStyle(color: AppTheme.primary, fontSize: 12),
                        )),
                      ]),
                    );
                  }
                  return const SizedBox.shrink();
                }),
                const SizedBox(height: 28),

                // -- Submit button
                Obx(() => SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: _ctrl.selectedIds.length >= 2 ? AppTheme.primary : AppTheme.card2,
                      foregroundColor: _ctrl.selectedIds.length >= 2 ? AppTheme.textH : AppTheme.textM,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _ctrl.selectedIds.length >= 2
                        ? () => _ctrl.create(_nameCtrl.text, context)
                        : null,
                    icon: const Icon(Icons.groups_rounded, size: 18),
                    label: Text(
                      _ctrl.selectedIds.length < 2
                          ? 'Select at least ${2 - _ctrl.selectedIds.length} more agent${_ctrl.selectedIds.length == 1 ? '' : 's'}'
                          : 'Create Guild',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                  ),
                )),
                const SizedBox(height: 32),
              ]),
            ),
    ));
  }

  Widget _buildCreatingState() {
    return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 80, height: 80,
        decoration: BoxDecoration(
          color: AppTheme.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
        ),
        child: const Center(child: SizedBox(
          width: 32, height: 32,
          child: CircularProgressIndicator(color: AppTheme.primary, strokeWidth: 3),
        )),
      ),
      const SizedBox(height: 20),
      const Text('Creating guild...', style: TextStyle(color: AppTheme.textH, fontSize: 16, fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      const Text('Setting up formation and synergy calculations', style: TextStyle(color: AppTheme.textM, fontSize: 13)),
    ]));
  }

  Widget _buildAgentLoadingSkeleton() {
    return ShimmerScope(
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: List.generate(6, (_) => SizedBox(
          width: 170,
          height: 200,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.card,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.border),
            ),
            child: const Column(mainAxisSize: MainAxisSize.min, children: [
              ShimmerBox(width: 72, height: 72, radius: 36, color: AppTheme.card2),
              SizedBox(height: 8),
              ShimmerBox(width: 80, height: 10, radius: 4, color: AppTheme.card2),
              SizedBox(height: 4),
              ShimmerBox(width: 60, height: 8, radius: 4, color: AppTheme.card2),
            ]),
          ),
        )),
      ),
    );
  }

  Widget _buildNoAgentsState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.inventory_2_outlined, color: AppTheme.textM, size: 40),
        const SizedBox(height: 12),
        const Text('No agents available', style: TextStyle(color: AppTheme.textH, fontSize: 15, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        const Text('Create some agents first to form a guild', style: TextStyle(color: AppTheme.textM, fontSize: 12)),
        const SizedBox(height: 16),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: AppTheme.primary,
            foregroundColor: AppTheme.textH,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: () => context.go('/create'),
          icon: const Icon(Icons.add_rounded, size: 16),
          label: const Text('Create Agent'),
        ),
      ]),
    );
  }
}

// -- Section label helper --

class _SectionLabel extends StatelessWidget {
  final String label;
  final IconData icon;
  const _SectionLabel({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 14, color: AppTheme.textM),
      const SizedBox(width: 6),
      Text(
        label.toUpperCase(),
        style: const TextStyle(color: AppTheme.textM, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 1),
      ),
    ]);
  }
}

// -- Local controller --

class _GuildCreateController extends GetxController {
  final allAgents = <AgentModel>[].obs;
  final selectedIds = <int>[].obs;
  final isLoadingAgents = true.obs;
  final isCreating = false.obs;
  final error = RxnString();

  @override
  void onInit() { super.onInit(); _loadAgents(); }

  Future<void> _loadAgents() async {
    try {
      final result = await ApiService.instance.listAgents(limit: 50);
      allAgents.value = result.agents;
    } catch (e) {
      error.value = 'Failed to load agents: $e';
    }
    isLoadingAgents.value = false;
  }

  void toggleAgent(int id) {
    if (selectedIds.contains(id)) {
      selectedIds.remove(id);
    } else if (selectedIds.length < 4) {
      selectedIds.add(id);
    }
  }

  Future<void> create(String name, BuildContext ctx) async {
    final n = name.trim();
    if (n.isEmpty) { error.value = 'Guild name is required'; return; }
    if (n.length < 3) { error.value = 'Guild name must be at least 3 characters'; return; }
    if (selectedIds.length < 2) { error.value = 'Select at least 2 agents'; return; }
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

// -- Agent selector grid --

class _AgentSelector extends StatelessWidget {
  final List<AgentModel> agents;
  final List<int> selectedIds;
  final void Function(int) onToggle;
  const _AgentSelector({required this.agents, required this.selectedIds, required this.onToggle});

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 12,
    runSpacing: 12,
    children: agents.map((agent) {
      final selected = selectedIds.contains(agent.id);
      return SizedBox(
        width: 170,
        height: 200,
        child: _AgentSelectorCard(
          agent: agent,
          selected: selected,
          onTap: () => onToggle(agent.id),
        ),
      );
    }).toList(),
  );
}

class _AgentSelectorCard extends StatefulWidget {
  final AgentModel agent;
  final bool selected;
  final VoidCallback onTap;
  const _AgentSelectorCard({required this.agent, required this.selected, required this.onTap});

  @override
  State<_AgentSelectorCard> createState() => _AgentSelectorCardState();
}

class _AgentSelectorCardState extends State<_AgentSelectorCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final agent = widget.agent;
    final selected = widget.selected;
    final typeColor = agent.characterType.primaryColor;
    final borderColor = selected
        ? AppTheme.primary
        : _hovered
            ? typeColor.withValues(alpha: 0.5)
            : AppTheme.border;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: selected
                ? AppTheme.primary.withValues(alpha: 0.1)
                : _hovered ? AppTheme.card2 : AppTheme.card,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: borderColor, width: selected ? 2 : 1),
            boxShadow: selected
                ? [BoxShadow(color: AppTheme.primary.withValues(alpha: 0.1), blurRadius: 8)]
                : null,
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            PixelCharacterWidget(
              characterType: agent.characterType,
              rarity: agent.rarity,
              subclass: agent.subclass,
              size: 72,
              agentId: agent.id,
            ),
            const SizedBox(height: 6),
            Text(
              agent.title,
              style: const TextStyle(color: AppTheme.textH, fontSize: 10, fontWeight: FontWeight.bold),
              maxLines: 1, overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              '${agent.characterType.displayName} -- ${agent.subclass.displayName}',
              style: TextStyle(color: typeColor, fontSize: 8),
              maxLines: 1, overflow: TextOverflow.ellipsis,
            ),
            if (selected) ...[
              const SizedBox(height: 4),
              Container(
                width: 20, height: 20,
                decoration: const BoxDecoration(
                  color: AppTheme.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_rounded, color: AppTheme.textH, size: 14),
              ),
            ],
          ]),
        ),
      ),
    );
  }
}
