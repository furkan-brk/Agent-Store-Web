
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../controllers/guild_master_controller.dart';
import '../../../features/character/character_types.dart';

class GuildMasterScreen extends StatelessWidget {
  final List<Map<String, dynamic>>? initialAgents;
  final String? initialGuildName;

  const GuildMasterScreen({super.key, this.initialAgents, this.initialGuildName});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.put(GuildMasterController(
      initialAgents: initialAgents,
      initialGuildName: initialGuildName,
    ));

    return Obx(() => switch (ctrl.phase.value) {
      GuildMasterPhase.input   => _buildInput(ctrl),
      GuildMasterPhase.loading => _buildLoading(),
      GuildMasterPhase.ready   => _buildReady(ctrl),
    });
  }

  Widget _buildInput(GuildMasterController ctrl) {
    final problemCtrl = TextEditingController();
    return Center(child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: Padding(padding: const EdgeInsets.all(32), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Center(child: Container(
          width: 64, height: 64,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF9B2828), Color(0xFF5A1515)], begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFCAB891).withValues(alpha: 0.25), width: 1.5),
            boxShadow: [BoxShadow(color: const Color(0xFF81231E).withValues(alpha: 0.45), blurRadius: 24, spreadRadius: 4)],
          ),
          child: const Icon(Icons.auto_awesome, color: Color(0xFF2B2C1E), size: 32),
        )),
        const SizedBox(height: 24),
        const Text('Guild Master', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF2B2C1E), fontSize: 28, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        const Text('AI-Powered Team Builder', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF6B5A40), fontSize: 14)),
        const SizedBox(height: 32),
        _GlowTextField(controller: problemCtrl, hintText: 'Describe your challenge or project...\n\nExample: I need to build a secure REST API with a nice dashboard and marketing copy.', maxLines: 5),
        Obx(() {
          if (ctrl.error.value != null) {
            return Padding(padding: const EdgeInsets.only(top: 12), child: Text(ctrl.error.value!, style: const TextStyle(color: Color(0xFFCAB891), fontSize: 13)));
          }
          return const SizedBox.shrink();
        }),
        const SizedBox(height: 20),
        SizedBox(height: 48, child: ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF81231E), foregroundColor: const Color(0xFFDDD1BB), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          onPressed: () => ctrl.findTeam(problemCtrl.text),
          child: const Text('Find My Team  →', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        )),
      ])),
    ));
  }

  Widget _buildLoading() => const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
    CircularProgressIndicator(color: Color(0xFF81231E)),
    SizedBox(height: 20),
    Text('Analyzing your challenge...', style: TextStyle(color: Color(0xFF6B5A40), fontSize: 15)),
  ]));

  Widget _buildReady(GuildMasterController ctrl) {
    final chatCtrl = TextEditingController();
    final scrollCtrl = ScrollController();

    void scrollToBottom() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (scrollCtrl.hasClients) {
          scrollCtrl.animateTo(scrollCtrl.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
        }
      });
    }

    return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      // Left panel
      SizedBox(width: 350, child: Container(
        decoration: const BoxDecoration(color: Color(0xFFC8BA9A), border: Border(right: BorderSide(color: Color(0xFFADA07A)))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(padding: const EdgeInsets.fromLTRB(20, 24, 20, 12), child: Obx(() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('YOUR TEAM', style: TextStyle(color: Color(0xFF81231E), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
            const SizedBox(height: 6),
            Text(ctrl.suggestion.value?['suggested_name'] as String? ?? 'Custom Squad', style: const TextStyle(color: Color(0xFF2B2C1E), fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(ctrl.suggestion.value?['reasoning'] as String? ?? '', style: const TextStyle(color: Color(0xFF6B5A40), fontSize: 13, height: 1.5)),
          ]))),
          const Divider(color: Color(0xFFADA07A)),
          Expanded(child: Obx(() => ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            itemCount: ctrl.teamAgents.length,
            itemBuilder: (_, i) => _AgentMiniCard(
              agent: ctrl.teamAgents[i],
              selected: ctrl.selectedAgentIds.contains((ctrl.teamAgents[i]['id'] as num).toInt()),
              onTap: () => ctrl.toggleAgent((ctrl.teamAgents[i]['id'] as num).toInt()),
            ),
          ))),
          Padding(padding: const EdgeInsets.all(16), child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF6B5A40), side: const BorderSide(color: Color(0xFFADA07A)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            icon: const Icon(Icons.refresh, size: 16), label: const Text('New Problem'),
            onPressed: ctrl.reset,
          )),
        ]),
      )),
      // Right panel — chat
      Expanded(child: Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFADA07A)))),
          child: Obx(() => Row(children: [
            const Icon(Icons.chat_bubble_outline, color: Color(0xFF81231E), size: 18),
            const SizedBox(width: 10),
            const Text('GUILD MASTER CHAT', style: TextStyle(color: Color(0xFF81231E), fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
            const Spacer(),
            Text('${ctrl.selectedAgentIds.length} agent${ctrl.selectedAgentIds.length == 1 ? '' : 's'} active', style: const TextStyle(color: Color(0xFF7A6E52), fontSize: 12)),
          ])),
        ),
        Expanded(child: Obx(() => ctrl.messages.isEmpty
          ? const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.forum_outlined, color: Color(0xFFC0B490), size: 48),
              SizedBox(height: 12),
              Text('Ask your team anything!', style: TextStyle(color: Color(0xFF7A6E52), fontSize: 14)),
            ]))
          : ListView.builder(
              controller: scrollCtrl,
              padding: const EdgeInsets.all(16),
              itemCount: ctrl.messages.length + (ctrl.isChatLoading.value ? 1 : 0),
              itemBuilder: (_, i) {
                if (i == ctrl.messages.length) {
                  return const Padding(padding: EdgeInsets.only(top: 8), child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF81231E)))));
                }
                final msg = ctrl.messages[i];
                if (msg.isUser) return _UserBubble(text: msg.userText!);
                return _TeamResponseGroup(responses: msg.teamResponses!);
              },
            ))),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFADA07A)))),
          child: Row(children: [
            Expanded(child: TextField(
              controller: chatCtrl,
              style: const TextStyle(color: Color(0xFF2B2C1E), fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Message your team...',
                hintStyle: const TextStyle(color: Color(0xFF5A5038)),
                filled: true, fillColor: const Color(0xFFB8AA88),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFADA07A))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFADA07A))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF81231E))),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
              onSubmitted: (v) async {
                final t = v.trim();
                chatCtrl.clear();
                await ctrl.sendChat(t);
                scrollToBottom();
              },
            )),
            const SizedBox(width: 10),
            Obx(() => SizedBox(height: 46, child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF81231E), foregroundColor: const Color(0xFFDDD1BB), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), padding: const EdgeInsets.symmetric(horizontal: 20)),
              onPressed: ctrl.isChatLoading.value ? null : () async {
                final t = chatCtrl.text.trim();
                chatCtrl.clear();
                await ctrl.sendChat(t);
                scrollToBottom();
              },
              child: const Icon(Icons.send, size: 18),
            ))),
          ]),
        ),
      ])),
    ]);
  }
}

// ── Sub-widgets (pure stateless) ──────────────────────────────────────────────

class _GlowTextField extends StatefulWidget {
  final TextEditingController controller;
  final String hintText;
  final int maxLines;
  const _GlowTextField({required this.controller, required this.hintText, this.maxLines = 1});
  @override
  State<_GlowTextField> createState() => _GlowTextFieldState();
}

class _GlowTextFieldState extends State<_GlowTextField> {
  bool _focused = false;
  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 200),
    decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), boxShadow: _focused ? [BoxShadow(color: const Color(0xFF81231E).withValues(alpha: 0.3), blurRadius: 16, spreadRadius: 2)] : []),
    child: Focus(
      onFocusChange: (f) => setState(() => _focused = f),
      child: TextField(controller: widget.controller, maxLines: widget.maxLines,
        style: const TextStyle(color: Color(0xFF2B2C1E), fontSize: 14),
        decoration: InputDecoration(
          hintText: widget.hintText, hintStyle: const TextStyle(color: Color(0xFF5A5038), fontSize: 13),
          filled: true, fillColor: const Color(0xFFB8AA88),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFADA07A))),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFADA07A))),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF81231E), width: 1.5)),
          contentPadding: const EdgeInsets.all(16),
        ),
      ),
    ),
  );
}

class _AgentMiniCard extends StatelessWidget {
  final Map<String, dynamic> agent;
  final bool selected;
  final VoidCallback onTap;
  const _AgentMiniCard({required this.agent, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final charType = characterTypeFromString(agent['character_type'] as String? ?? '');
    final color = charType.primaryColor;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFE8DEC9), borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? color : const Color(0xFFADA07A), width: selected ? 1.5 : 1),
          boxShadow: selected ? [BoxShadow(color: color.withValues(alpha: 0.25), blurRadius: 10, spreadRadius: 1)] : [],
        ),
        child: Row(children: [
          Container(width: 44, height: 44, decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8), border: Border.all(color: color.withValues(alpha: 0.4)), boxShadow: [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 8)]),
            child: Icon(_charTypeIcon(charType), color: color, size: 22)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(agent['title'] as String? ?? 'Unknown Agent', style: const TextStyle(color: Color(0xFF2B2C1E), fontSize: 13, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)), child: Text(charType.displayName, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w500))),
          ])),
          Icon(selected ? Icons.check_circle : Icons.circle_outlined, color: selected ? color : const Color(0xFFC0B490), size: 18),
        ]),
      ),
    );
  }

  IconData _charTypeIcon(CharacterType t) => switch (t) {
    CharacterType.wizard     => Icons.code,
    CharacterType.strategist => Icons.flag,
    CharacterType.oracle     => Icons.bar_chart,
    CharacterType.guardian   => Icons.shield,
    CharacterType.artisan    => Icons.brush,
    CharacterType.bard       => Icons.edit,
    CharacterType.scholar    => Icons.school,
    CharacterType.merchant   => Icons.trending_up,
  };
}

class _UserBubble extends StatelessWidget {
  final String text;
  const _UserBubble({required this.text});
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerRight,
    child: Container(
      margin: const EdgeInsets.only(bottom: 12, left: 60),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: const Color(0xFF81231E), borderRadius: BorderRadius.circular(12)),
      child: Text(text, style: const TextStyle(color: Color(0xFF2B2C1E), fontSize: 14)),
    ),
  );
}

class _TeamResponseGroup extends StatelessWidget {
  final List<Map<String, dynamic>> responses;
  const _TeamResponseGroup({required this.responses});
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: responses.map((r) => _TeamResponseCard(response: r)).toList());
}

class _TeamResponseCard extends StatefulWidget {
  final Map<String, dynamic> response;
  const _TeamResponseCard({required this.response});
  @override
  State<_TeamResponseCard> createState() => _TeamResponseCardState();
}

class _TeamResponseCardState extends State<_TeamResponseCard> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 350))..forward();
    _opacity = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
  }
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final charType = characterTypeFromString(widget.response['character_type'] as String? ?? '');
    final color = charType.primaryColor;
    final title = widget.response['agent_title'] as String? ?? 'Agent';
    final role  = widget.response['role']        as String? ?? 'Specialist';
    final reply = widget.response['reply']        as String? ?? '';
    return FadeTransition(opacity: _opacity, child: Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: const Color(0xFFE8DEC9), borderRadius: BorderRadius.circular(10), border: Border(left: BorderSide(color: color, width: 3))),
      child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 28, height: 28, decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)), child: Icon(_charTypeIcon(charType), color: color, size: 14)),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(color: Color(0xFF2B2C1E), fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(width: 8),
          Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(4)), child: Text(role, style: TextStyle(color: color, fontSize: 10))),
        ]),
        const SizedBox(height: 10),
        Text(reply, style: const TextStyle(color: Color(0xFF4A4033), fontSize: 13, height: 1.55)),
      ])),
    ));
  }
  IconData _charTypeIcon(CharacterType t) => switch (t) {
    CharacterType.wizard     => Icons.code,
    CharacterType.strategist => Icons.flag,
    CharacterType.oracle     => Icons.bar_chart,
    CharacterType.guardian   => Icons.shield,
    CharacterType.artisan    => Icons.brush,
    CharacterType.bard       => Icons.edit,
    CharacterType.scholar    => Icons.school,
    CharacterType.merchant   => Icons.trending_up,
  };
}
