import 'package:flutter/material.dart';
import '../../../features/character/character_types.dart';
import '../../../shared/services/api_service.dart';

// ── Message types ─────────────────────────────────────────────────────────────

sealed class _Msg {}

class _UserMsg extends _Msg {
  final String text;
  _UserMsg(this.text);
}

class _TeamMsg extends _Msg {
  final List<Map<String, dynamic>> responses;
  _TeamMsg(this.responses);
}

// ── Screen phases ─────────────────────────────────────────────────────────────

enum _Phase { input, loading, ready }

// ── Main screen ───────────────────────────────────────────────────────────────

class GuildMasterScreen extends StatefulWidget {
  /// When provided, the screen skips the input phase and loads
  /// the given agents directly into the team chat.
  final List<Map<String, dynamic>>? initialAgents;
  final String? initialGuildName;

  const GuildMasterScreen({
    super.key,
    this.initialAgents,
    this.initialGuildName,
  });

  @override
  State<GuildMasterScreen> createState() => _GuildMasterScreenState();
}

class _GuildMasterScreenState extends State<GuildMasterScreen> {
  _Phase _phase = _Phase.input;

  // Input phase
  final _problemCtrl = TextEditingController();

  // Ready phase
  Map<String, dynamic>? _suggestion;
  final List<Map<String, dynamic>> _teamAgents = [];
  final List<int> _selectedAgentIds = [];
  final List<_Msg> _messages = [];
  final _chatCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _chatLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final agents = widget.initialAgents;
    if (agents != null && agents.isNotEmpty) {
      _teamAgents.addAll(agents);
      _selectedAgentIds.addAll(agents.map((a) => (a['id'] as num).toInt()));
      _suggestion = {
        'suggested_name': widget.initialGuildName ?? 'Guild Team',
        'reasoning': 'Team assembled from your guild. Chat to collaborate!',
      };
      _phase = _Phase.ready;
    }
  }

  @override
  void dispose() {
    _problemCtrl.dispose();
    _chatCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _findTeam() async {
    final problem = _problemCtrl.text.trim();
    if (problem.isEmpty) return;

    setState(() { _phase = _Phase.loading; _error = null; });

    final result = await ApiService.instance.suggestGuild(problem);
    if (!mounted) return;

    if (result == null) {
      setState(() {
        _phase = _Phase.input;
        _error = 'Could not contact Guild Master. Check your connection.';
      });
      return;
    }

    final agents = (result['matching_agents'] as List<dynamic>? ?? [])
        .map((e) => e as Map<String, dynamic>)
        .toList();

    setState(() {
      _suggestion = result;
      _teamAgents
        ..clear()
        ..addAll(agents);
      _selectedAgentIds
        ..clear()
        ..addAll(agents.map((a) => (a['id'] as num).toInt()));
      _messages.clear();
      _phase = _Phase.ready;
    });
  }

  Future<void> _sendChat() async {
    final message = _chatCtrl.text.trim();
    if (message.isEmpty || _selectedAgentIds.isEmpty || _chatLoading) return;

    _chatCtrl.clear();
    setState(() {
      _messages.add(_UserMsg(message));
      _chatLoading = true;
    });
    _scrollToBottom();

    final responses = await ApiService.instance.teamChat(message, _selectedAgentIds);
    if (!mounted) return;

    setState(() {
      if (responses != null && responses.isNotEmpty) {
        _messages.add(_TeamMsg(responses));
      }
      _chatLoading = false;
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _reset() {
    setState(() {
      _phase = _Phase.input;
      _problemCtrl.clear();
      _suggestion = null;
      _teamAgents.clear();
      _selectedAgentIds.clear();
      _messages.clear();
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) => switch (_phase) {
    _Phase.input   => _buildInput(),
    _Phase.loading => _buildLoading(),
    _Phase.ready   => _buildReady(),
  };

  // ── Phase: input ──────────────────────────────────────────────────────────

  Widget _buildInput() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Icon
              Center(
                child: Container(
                  width: 64, height: 64,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.4),
                      blurRadius: 24, spreadRadius: 4,
                    )],
                  ),
                  child: const Icon(Icons.auto_awesome, color: Colors.white, size: 32),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Guild Master',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              const Text(
                'AI-Powered Team Builder',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
              ),
              const SizedBox(height: 32),
              // Problem input
              _GlowTextField(
                controller: _problemCtrl,
                hintText: 'Describe your challenge or project...\n\nExample: I need to build a secure REST API with a nice dashboard and marketing copy.',
                maxLines: 5,
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: Color(0xFFEF4444), fontSize: 13)),
              ],
              const SizedBox(height: 20),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _findTeam,
                  child: const Text('Find My Team  →', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Phase: loading ────────────────────────────────────────────────────────

  Widget _buildLoading() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: Color(0xFF6366F1)),
          SizedBox(height: 20),
          Text('Analyzing your challenge...', style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 15)),
        ],
      ),
    );
  }

  // ── Phase: ready ──────────────────────────────────────────────────────────

  Widget _buildReady() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Left panel: team info
        SizedBox(
          width: 350,
          child: Container(
            decoration: const BoxDecoration(
              color: Color(0xFF0F0F1E),
              border: Border(right: BorderSide(color: Color(0xFF1E1E35))),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('YOUR TEAM', style: TextStyle(color: Color(0xFF6366F1), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                      const SizedBox(height: 6),
                      Text(
                        _suggestion?['suggested_name'] as String? ?? 'Custom Squad',
                        style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _suggestion?['reasoning'] as String? ?? '',
                        style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13, height: 1.5),
                      ),
                    ],
                  ),
                ),
                const Divider(color: Color(0xFF1E1E35)),
                // Agent cards
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    itemCount: _teamAgents.length,
                    itemBuilder: (_, i) => _AgentMiniCard(
                      agent: _teamAgents[i],
                      selected: _selectedAgentIds.contains((_teamAgents[i]['id'] as num).toInt()),
                      onTap: () {
                        final id = (_teamAgents[i]['id'] as num).toInt();
                        setState(() {
                          if (_selectedAgentIds.contains(id)) {
                            _selectedAgentIds.remove(id);
                          } else {
                            _selectedAgentIds.add(id);
                          }
                        });
                      },
                    ),
                  ),
                ),
                // Reset button
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF9CA3AF),
                      side: const BorderSide(color: Color(0xFF1E1E35)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('New Problem'),
                    onPressed: _reset,
                  ),
                ),
              ],
            ),
          ),
        ),
        // Right panel: chat
        Expanded(
          child: Column(
            children: [
              // Chat header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0xFF1E1E35))),
                ),
                child: Row(children: [
                  const Icon(Icons.chat_bubble_outline, color: Color(0xFF6366F1), size: 18),
                  const SizedBox(width: 10),
                  const Text('GUILD MASTER CHAT', style: TextStyle(color: Color(0xFF6366F1), fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                  const Spacer(),
                  Text('${_selectedAgentIds.length} agent${_selectedAgentIds.length == 1 ? '' : 's'} active',
                    style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12)),
                ]),
              ),
              // Messages
              Expanded(
                child: _messages.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.forum_outlined, color: Color(0xFF374151), size: 48),
                          SizedBox(height: 12),
                          Text('Ask your team anything!', style: TextStyle(color: Color(0xFF6B7280), fontSize: 14)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollCtrl,
                      padding: const EdgeInsets.all(16),
                      itemCount: _messages.length + (_chatLoading ? 1 : 0),
                      itemBuilder: (_, i) {
                        if (i == _messages.length) {
                          return const Padding(
                            padding: EdgeInsets.only(top: 8),
                            child: Center(child: SizedBox(width: 20, height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF6366F1)))),
                          );
                        }
                        final msg = _messages[i];
                        return switch (msg) {
                          _UserMsg m => _UserBubble(text: m.text),
                          _TeamMsg m => _TeamResponseGroup(responses: m.responses),
                        };
                      },
                    ),
              ),
              // Input row
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: Color(0xFF1E1E35))),
                ),
                child: Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _chatCtrl,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Message your team...',
                        hintStyle: const TextStyle(color: Color(0xFF4B5563)),
                        filled: true,
                        fillColor: const Color(0xFF111827),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xFF1E1E35)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xFF1E1E35)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xFF6366F1)),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                      onSubmitted: (_) => _sendChat(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    height: 46,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                      ),
                      onPressed: _chatLoading ? null : _sendChat,
                      child: const Icon(Icons.send, size: 18),
                    ),
                  ),
                ]),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Glow text field ───────────────────────────────────────────────────────────

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
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: _focused
          ? [BoxShadow(color: const Color(0xFF6366F1).withValues(alpha: 0.3), blurRadius: 16, spreadRadius: 2)]
          : [],
      ),
      child: Focus(
        onFocusChange: (f) => setState(() => _focused = f),
        child: TextField(
          controller: widget.controller,
          maxLines: widget.maxLines,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: widget.hintText,
            hintStyle: const TextStyle(color: Color(0xFF4B5563), fontSize: 13),
            filled: true,
            fillColor: const Color(0xFF111827),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF1E1E35)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF1E1E35)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF6366F1), width: 1.5),
            ),
            contentPadding: const EdgeInsets.all(16),
          ),
        ),
      ),
    );
  }
}

// ── Agent mini card ───────────────────────────────────────────────────────────

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
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF111827),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? color : const Color(0xFF1E1E35),
            width: selected ? 1.5 : 1,
          ),
          boxShadow: selected
            ? [BoxShadow(color: color.withValues(alpha: 0.25), blurRadius: 10, spreadRadius: 1)]
            : [],
        ),
        child: Row(children: [
          // Avatar
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withValues(alpha: 0.4)),
              boxShadow: [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 8)],
            ),
            child: Icon(_charTypeIcon(charType), color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  agent['title'] as String? ?? 'Unknown Agent',
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(charType.displayName,
                      style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w500)),
                  ),
                ]),
              ],
            ),
          ),
          Icon(
            selected ? Icons.check_circle : Icons.circle_outlined,
            color: selected ? color : const Color(0xFF374151),
            size: 18,
          ),
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

// ── User bubble ───────────────────────────────────────────────────────────────

class _UserBubble extends StatelessWidget {
  final String text;
  const _UserBubble({required this.text});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12, left: 60),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF6366F1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 14)),
      ),
    );
  }
}

// ── Team response group ───────────────────────────────────────────────────────

class _TeamResponseGroup extends StatelessWidget {
  final List<Map<String, dynamic>> responses;
  const _TeamResponseGroup({required this.responses});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: responses.map((r) => _TeamResponseCard(response: r)).toList(),
    );
  }
}

class _TeamResponseCard extends StatefulWidget {
  final Map<String, dynamic> response;
  const _TeamResponseCard({required this.response});

  @override
  State<_TeamResponseCard> createState() => _TeamResponseCardState();
}

class _TeamResponseCardState extends State<_TeamResponseCard>
    with SingleTickerProviderStateMixin {
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

    return FadeTransition(
      opacity: _opacity,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF111827),
          borderRadius: BorderRadius.circular(10),
          border: Border(left: BorderSide(color: color, width: 3)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(_charTypeIcon(charType), color: color, size: 14),
                ),
                const SizedBox(width: 8),
                Text(title, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(role, style: TextStyle(color: color, fontSize: 10)),
                ),
              ]),
              const SizedBox(height: 10),
              Text(reply, style: const TextStyle(color: Color(0xFFD1D5DB), fontSize: 13, height: 1.55)),
            ],
          ),
        ),
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
