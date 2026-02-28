import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../features/character/character_types.dart';
import '../../../shared/models/agent_model.dart';
import '../../../shared/services/api_service.dart';
import '../../../shared/widgets/pixel_character_widget.dart';

class GuildCreateScreen extends StatefulWidget {
  const GuildCreateScreen({super.key});

  @override
  State<GuildCreateScreen> createState() => _GuildCreateScreenState();
}

class _GuildCreateScreenState extends State<GuildCreateScreen> {
  final _nameCtrl = TextEditingController();
  List<AgentModel> _allAgents = [];
  final List<int> _selectedAgentIds = [];
  bool _loadingAgents = true;
  bool _creating = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAgents();
  }

  @override
  void dispose() { _nameCtrl.dispose(); super.dispose(); }

  Future<void> _loadAgents() async {
    final result = await ApiService.instance.listAgents(limit: 50);
    if (mounted) setState(() { _allAgents = result.agents; _loadingAgents = false; });
  }

  Future<void> _create() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) { setState(() => _error = 'Guild name is required'); return; }
    if (_selectedAgentIds.isEmpty) { setState(() => _error = 'Select at least one agent'); return; }
    if (_selectedAgentIds.length > 4) { setState(() => _error = 'Max 4 members per guild'); return; }

    setState(() { _creating = true; _error = null; });
    final guild = await ApiService.instance.createGuild(name: name);
    if (guild == null) {
      if (mounted) setState(() { _error = 'Failed to create guild'; _creating = false; });
      return;
    }
    // Add members
    for (final agentId in _selectedAgentIds) {
      await ApiService.instance.addGuildMember(guild.id, agentId);
    }
    if (mounted) context.go('/guild/${guild.id}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F1E),
        foregroundColor: Colors.white,
        title: const Text('Create Guild', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ),
      body: _creating
          ? const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              CircularProgressIndicator(color: Color(0xFF6366F1)),
              SizedBox(height: 16),
              Text('Creating guild...', style: TextStyle(color: Color(0xFF9CA3AF))),
            ]))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Guild Name', style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12, letterSpacing: 1)),
                const SizedBox(height: 8),
                TextField(
                  controller: _nameCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'e.g. Wizard-Oracle Guild',
                    hintStyle: const TextStyle(color: Color(0xFF4B5563)),
                    filled: true,
                    fillColor: const Color(0xFF13131F),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFF374151)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFF6366F1)),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                Row(children: [
                  const Text('Select Members', style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12, letterSpacing: 1)),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('${_selectedAgentIds.length}/4',
                      style: const TextStyle(color: Color(0xFF6366F1), fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ]),
                const SizedBox(height: 4),
                const Text('2–4 agents. Tip: Mix different types for synergy bonuses.',
                  style: TextStyle(color: Color(0xFF4B5563), fontSize: 11)),
                const SizedBox(height: 12),

                if (_loadingAgents)
                  const Center(child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(color: Color(0xFF6366F1)),
                  ))
                else
                  _AgentSelector(
                    agents: _allAgents,
                    selectedIds: _selectedAgentIds,
                    onToggle: (id) {
                      setState(() {
                        if (_selectedAgentIds.contains(id)) {
                          _selectedAgentIds.remove(id);
                        } else if (_selectedAgentIds.length < 4) {
                          _selectedAgentIds.add(id);
                        }
                      });
                    },
                  ),

                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: Color(0xFFEF4444), fontSize: 12)),
                ],
                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _selectedAgentIds.length >= 2 ? _create : null,
                    child: const Text('Create Guild', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  ),
                ),
              ]),
            ),
    );
  }
}

class _AgentSelector extends StatelessWidget {
  final List<AgentModel> agents;
  final List<int> selectedIds;
  final void Function(int id) onToggle;

  const _AgentSelector({
    required this.agents, required this.selectedIds, required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 160,
        mainAxisExtent: 190,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
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
              color: selected ? const Color(0xFF6366F1).withValues(alpha: 0.12) : const Color(0xFF13131F),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected ? const Color(0xFF6366F1) : rc.withValues(alpha: 0.25),
                width: selected ? 2 : 1,
              ),
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
              Text(agent.title,
                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text('${agent.characterType.displayName} · ${agent.subclass.displayName}',
                style: TextStyle(color: agent.characterType.accentColor, fontSize: 8),
                maxLines: 1, overflow: TextOverflow.ellipsis),
              if (selected)
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Icon(Icons.check_circle, color: Color(0xFF6366F1), size: 14),
                ),
            ]),
          ),
        );
      },
    );
  }
}
