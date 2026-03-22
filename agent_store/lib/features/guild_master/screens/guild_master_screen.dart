// lib/features/guild_master/screens/guild_master_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../../app/theme.dart';
import '../../../controllers/guild_master_controller.dart';
import '../../../features/character/character_types.dart';
import '../../../shared/models/agent_model.dart';
import '../../../shared/models/mission_model.dart';
import '../../../shared/services/mission_service.dart';

class GuildMasterScreen extends StatelessWidget {
  final List<Map<String, dynamic>>? initialAgents;
  final String? initialGuildName;

  const GuildMasterScreen({super.key, this.initialAgents, this.initialGuildName});

  @override
  Widget build(BuildContext context) {
    // If opened with pre-loaded agents (from guild detail), create a fresh instance.
    // Delete stale tagged controller first to avoid returning outdated data.
    // Otherwise reuse the preloaded controller if available.
    late final GuildMasterController ctrl;
    if (initialAgents != null && initialAgents!.isNotEmpty) {
      if (Get.isRegistered<GuildMasterController>(tag: 'guild_from_detail')) {
        Get.delete<GuildMasterController>(tag: 'guild_from_detail');
      }
      ctrl = Get.put(
        GuildMasterController(
          initialAgents: initialAgents,
          initialGuildName: initialGuildName,
        ),
        tag: 'guild_from_detail',
      );
    } else if (Get.isRegistered<GuildMasterController>()) {
      ctrl = Get.find<GuildMasterController>();
    } else {
      ctrl = Get.put(GuildMasterController());
    }

    return Obx(() => switch (ctrl.phase.value) {
          GuildMasterPhase.input => _buildInput(context, ctrl),
          GuildMasterPhase.loading => _buildLoading(context),
          GuildMasterPhase.ready => _buildReady(context, ctrl),
        });
  }

  Widget _buildInput(BuildContext context, GuildMasterController ctrl) {
    final cs = Theme.of(context).colorScheme;

    return Center(
        child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // -- Crown icon badge --
            Center(
                child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.primary, AppTheme.primary.withValues(alpha: 0.6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.border2, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primary.withValues(alpha: 0.35),
                    blurRadius: 24,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: const Icon(Icons.auto_awesome, color: AppTheme.textH, size: 32),
            )),
            const SizedBox(height: 24),

            // -- Title --
            const Text(
              'Guild Master',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.textH,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'AI-Powered Team Builder',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textB, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Text(
              'Describe your project or challenge and Guild Master will assemble the ideal team of AI agents to tackle it together.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.textM.withValues(alpha: 0.85),
                fontSize: 12,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),

            // -- Text field with glow --
            _ProblemPromptComposer(ctrl: ctrl),

            // -- Error message --
            Obx(() {
              if (ctrl.error.value != null) {
                return Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, size: 14, color: cs.error),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          ctrl.error.value!,
                          style: TextStyle(color: cs.error, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                );
              }
              return const SizedBox.shrink();
            }),
          ],
        ),
      ),
    ));
  }

  Widget _buildLoading(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(
              color: AppTheme.primary,
              strokeWidth: 3,
              backgroundColor: AppTheme.border.withValues(alpha: 0.3),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Analyzing your challenge...',
            style: TextStyle(color: AppTheme.textB, fontSize: 15, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          const Text(
            'Selecting the best agents for your team',
            style: TextStyle(color: AppTheme.textM, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildReady(BuildContext context, GuildMasterController ctrl) {
    return LayoutBuilder(builder: (context, constraints) {
      // Responsive: stack vertically on narrow screens
      final isNarrow = constraints.maxWidth < 768;

      if (isNarrow) {
        return Column(children: [
          SizedBox(
            height: 280,
            child: _LeftPanel(ctrl: ctrl),
          ),
          Expanded(child: _ChatPanel(ctrl: ctrl)),
        ]);
      }

      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(width: 350, child: _LeftPanel(ctrl: ctrl)),
          Expanded(child: _ChatPanel(ctrl: ctrl)),
        ],
      );
    });
  }
}

// ── Left Panel (team sidebar) ─────────────────────────────────────────────────

class _LeftPanel extends StatelessWidget {
  final GuildMasterController ctrl;
  const _LeftPanel({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(right: BorderSide(color: AppTheme.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // -- Team header --
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
            child: Obx(() => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(Icons.shield, color: AppTheme.primary, size: 14),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'YOUR TEAM',
                          style: TextStyle(
                            color: AppTheme.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      ctrl.suggestion.value?['suggested_name'] as String? ?? 'Custom Squad',
                      style: const TextStyle(
                        color: AppTheme.textH,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      ctrl.suggestion.value?['reasoning'] as String? ?? '',
                      style: const TextStyle(
                        color: AppTheme.textB,
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                  ],
                )),
          ),

          const Divider(color: AppTheme.border, height: 1),

          // -- Agent list --
          Expanded(
            child: Obx(() {
              if (ctrl.teamAgents.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.group_off_outlined,
                        color: AppTheme.textM.withValues(alpha: 0.5),
                        size: 40,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'No agents found',
                        style: TextStyle(color: AppTheme.textM, fontSize: 13),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Try a different challenge description',
                        style: TextStyle(color: AppTheme.textM, fontSize: 11),
                      ),
                    ],
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                itemCount: ctrl.teamAgents.length,
                itemBuilder: (_, i) => _AgentMiniCard(
                  agent: ctrl.teamAgents[i],
                  selected: ctrl.selectedAgentIds.contains(
                    (ctrl.teamAgents[i]['id'] as num).toInt(),
                  ),
                  onTap: () => ctrl.toggleAgent(
                    (ctrl.teamAgents[i]['id'] as num).toInt(),
                  ),
                ),
              );
            }),
          ),

          // -- Reset button --
          Padding(
            padding: const EdgeInsets.all(16),
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.textB,
                side: const BorderSide(color: AppTheme.border),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('New Problem'),
              onPressed: ctrl.reset,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Chat Panel ────────────────────────────────────────────────────────────────

class _ChatPanel extends StatefulWidget {
  final GuildMasterController ctrl;
  const _ChatPanel({required this.ctrl});

  @override
  State<_ChatPanel> createState() => _ChatPanelState();
}

class _ChatPanelState extends State<_ChatPanel> {
  final _chatCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  List<AgentModel> _agentSuggestions = const [];
  List<MissionModel> _missionSuggestions = const [];
  String _activeTrigger = '';
  bool _showMentions = false;
  int _mentionStart = -1;
  int _selectedSuggestionIndex = 0;

  @override
  void initState() {
    super.initState();
    _chatCtrl.addListener(_onChatChanged);
    widget.ctrl.ensureLibraryLoaded();
  }

  @override
  void dispose() {
    _chatCtrl.removeListener(_onChatChanged);
    _chatCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onChatChanged() {
    final selection = _chatCtrl.selection;
    final cursor = selection.baseOffset >= 0 ? selection.baseOffset : _chatCtrl.text.length;
    final text = _chatCtrl.text;
    if (cursor > text.length) return;

    final prefix = text.substring(0, cursor);
    final at = prefix.lastIndexOf('@');
    final hash = prefix.lastIndexOf('#');
    final trigger = at > hash ? '@' : '#';
    final triggerIndex = trigger == '@' ? at : hash;
    if (triggerIndex == -1) {
      _hideMentions();
      return;
    }

    if (triggerIndex > 0 && !RegExp(r'\s').hasMatch(prefix[triggerIndex - 1])) {
      _hideMentions();
      return;
    }

    final query = prefix.substring(triggerIndex + 1);
    if (query.contains(RegExp(r'\s'))) {
      _hideMentions();
      return;
    }

    final q = query.toLowerCase();
    if (trigger == '@') {
      final list = widget.ctrl.libraryAgents;
      final suggestions = list.where((a) => q.isEmpty || a.title.toLowerCase().contains(q)).take(8).toList();
      setState(() {
        _mentionStart = triggerIndex;
        _activeTrigger = '@';
        _agentSuggestions = suggestions;
        _missionSuggestions = const [];
        _showMentions = true;
        _selectedSuggestionIndex = 0;
      });
      return;
    }

    final missionSuggestions = MissionService.instance.search(q);

    setState(() {
      _mentionStart = triggerIndex;
      _activeTrigger = '#';
      _agentSuggestions = const [];
      _missionSuggestions = missionSuggestions;
      _showMentions = true;
      _selectedSuggestionIndex = 0;
    });
  }

  int get _suggestionCount => _activeTrigger == '@' ? _agentSuggestions.length : _missionSuggestions.length;

  KeyEventResult _onChatKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent || !_showMentions) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final count = _suggestionCount;

    if (key == LogicalKeyboardKey.escape) {
      _hideMentions();
      return KeyEventResult.handled;
    }

    if (count == 0) return KeyEventResult.ignored;

    if (key == LogicalKeyboardKey.arrowDown) {
      setState(() => _selectedSuggestionIndex = (_selectedSuggestionIndex + 1) % count);
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowUp) {
      setState(() => _selectedSuggestionIndex = (_selectedSuggestionIndex - 1 + count) % count);
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter) {
      if (_activeTrigger == '@') {
        _insertMention(_agentSuggestions[_selectedSuggestionIndex]);
      } else {
        _insertMission(_missionSuggestions[_selectedSuggestionIndex]);
      }
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  void _hideMentions() {
    if (!_showMentions && _agentSuggestions.isEmpty && _missionSuggestions.isEmpty) return;
    setState(() {
      _showMentions = false;
      _activeTrigger = '';
      _agentSuggestions = const [];
      _missionSuggestions = const [];
      _mentionStart = -1;
      _selectedSuggestionIndex = 0;
    });
  }

  void _insertMention(AgentModel agent) {
    final text = _chatCtrl.text;
    final selection = _chatCtrl.selection;
    final cursor = selection.baseOffset >= 0 ? selection.baseOffset : text.length;
    if (_mentionStart < 0 || _mentionStart >= cursor || cursor > text.length) return;

    final before = text.substring(0, _mentionStart);
    final after = text.substring(cursor);
    final mention = '@${agent.title} ';
    final next = '$before$mention$after';
    _chatCtrl.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: (before + mention).length),
    );
    _hideMentions();
  }

  void _insertMission(MissionModel mission) {
    final text = _chatCtrl.text;
    final selection = _chatCtrl.selection;
    final cursor = selection.baseOffset >= 0 ? selection.baseOffset : text.length;
    if (_mentionStart < 0 || _mentionStart >= cursor || cursor > text.length) return;

    final before = text.substring(0, _mentionStart);
    final after = text.substring(cursor);
    final mention = '#${mission.slug} ';
    final next = '$before$mention$after';
    _chatCtrl.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: (before + mention).length),
    );
    _hideMentions();
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

  Future<void> _sendMessage() async {
    final raw = _chatCtrl.text.trim();
    final text = await MissionService.instance.expandMissionTags(raw);
    if (text.isEmpty) return;
    _hideMentions();
    _chatCtrl.clear();
    await widget.ctrl.sendChat(text);
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // -- Chat header --
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: const BoxDecoration(
            color: AppTheme.surface,
            border: Border(bottom: BorderSide(color: AppTheme.border)),
          ),
          child: Obx(() => Row(
                children: [
                  const Icon(Icons.chat_bubble_outline, color: AppTheme.primary, size: 18),
                  const SizedBox(width: 10),
                  const Text(
                    'GUILD MASTER CHAT',
                    style: TextStyle(
                      color: AppTheme.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.gold.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.gold.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      '${widget.ctrl.selectedAgentIds.length} agent${widget.ctrl.selectedAgentIds.length == 1 ? '' : 's'} active',
                      style: const TextStyle(color: AppTheme.gold, fontSize: 11, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              )),
        ),

        // -- Messages area --
        Expanded(
          child: Obx(() {
            if (widget.ctrl.messages.isEmpty) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.forum_outlined,
                      color: AppTheme.textM.withValues(alpha: 0.4),
                      size: 48,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Ask your team anything!',
                      style: TextStyle(
                        color: AppTheme.textB,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Your selected agents will collaborate on an answer',
                      style: TextStyle(color: AppTheme.textM, fontSize: 12),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.all(16),
              itemCount: widget.ctrl.messages.length + (widget.ctrl.isChatLoading.value ? 1 : 0),
              itemBuilder: (_, i) {
                if (i == widget.ctrl.messages.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTheme.primary,
                          backgroundColor: AppTheme.border.withValues(alpha: 0.3),
                        ),
                      ),
                    ),
                  );
                }
                final msg = widget.ctrl.messages[i];
                if (msg.isUser) return _UserBubble(text: msg.userText!);
                return _TeamResponseGroup(responses: msg.teamResponses!);
              },
            );
          }),
        ),

        // -- Input bar --
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          decoration: const BoxDecoration(
            color: AppTheme.surface,
            border: Border(top: BorderSide(color: AppTheme.border)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_showMentions) ...[
                Container(
                  constraints: const BoxConstraints(maxHeight: 180),
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.card,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Obx(() {
                    if (_activeTrigger == '@' && widget.ctrl.isLibraryLoading.value) {
                      return const Padding(
                        padding: EdgeInsets.all(12),
                        child: Text(
                          'Loading library agents...',
                          style: TextStyle(color: AppTheme.textM, fontSize: 12),
                        ),
                      );
                    }
                    final hasNoData = _activeTrigger == '@' ? _agentSuggestions.isEmpty : _missionSuggestions.isEmpty;
                    if (hasNoData) {
                      return const Padding(
                        padding: EdgeInsets.all(12),
                        child: Text(
                          'No matches found',
                          style: TextStyle(color: AppTheme.textM, fontSize: 12),
                        ),
                      );
                    }
                    if (_activeTrigger == '#') {
                      return ListView.builder(
                        shrinkWrap: true,
                        itemCount: _missionSuggestions.length,
                        itemBuilder: (_, i) {
                          final mission = _missionSuggestions[i];
                          return ListTile(
                            dense: true,
                            visualDensity: VisualDensity.compact,
                            selected: i == _selectedSuggestionIndex,
                            selectedTileColor: AppTheme.gold.withValues(alpha: 0.12),
                            title: Text(
                              '#${mission.slug}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: AppTheme.gold, fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text(
                              mission.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: AppTheme.textM, fontSize: 11),
                            ),
                            onTap: () => _insertMission(mission),
                          );
                        },
                      );
                    }
                    return ListView.builder(
                      shrinkWrap: true,
                      itemCount: _agentSuggestions.length,
                      itemBuilder: (_, i) {
                        final agent = _agentSuggestions[i];
                        return ListTile(
                          dense: true,
                          visualDensity: VisualDensity.compact,
                          selected: i == _selectedSuggestionIndex,
                          selectedTileColor: AppTheme.primary.withValues(alpha: 0.14),
                          title: Text(
                            agent.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: AppTheme.textH, fontSize: 13),
                          ),
                          subtitle: Text(
                            agent.characterType.displayName,
                            style: const TextStyle(color: AppTheme.textM, fontSize: 11),
                          ),
                          onTap: () => _insertMention(agent),
                        );
                      },
                    );
                  }),
                ),
              ],
              Row(
                children: [
                  Expanded(
                    child: Focus(
                      onKeyEvent: _onChatKeyEvent,
                      child: TextField(
                        controller: _chatCtrl,
                        style: const TextStyle(color: AppTheme.textH, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Message your team... (Use @agent and #mission)',
                          hintStyle: const TextStyle(color: AppTheme.textM),
                          filled: true,
                          fillColor: AppTheme.card,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: AppTheme.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: AppTheme.border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Obx(() => SizedBox(
                        height: 46,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            foregroundColor: AppTheme.textH,
                            disabledBackgroundColor: AppTheme.primary.withValues(alpha: 0.4),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                          ),
                          onPressed: widget.ctrl.isChatLoading.value ? null : _sendMessage,
                          child: const Icon(Icons.send, size: 18),
                        ),
                      )),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _ProblemPromptComposer extends StatefulWidget {
  final GuildMasterController ctrl;
  const _ProblemPromptComposer({required this.ctrl});

  @override
  State<_ProblemPromptComposer> createState() => _ProblemPromptComposerState();
}

class _ProblemPromptComposerState extends State<_ProblemPromptComposer> {
  final _problemCtrl = TextEditingController();
  List<AgentModel> _agentSuggestions = const [];
  List<MissionModel> _missionSuggestions = const [];
  String _activeTrigger = '';
  bool _showMentions = false;
  int _mentionStart = -1;
  int _selectedSuggestionIndex = 0;

  @override
  void initState() {
    super.initState();
    _problemCtrl.addListener(_onProblemChanged);
    widget.ctrl.ensureLibraryLoaded();
  }

  @override
  void dispose() {
    _problemCtrl.removeListener(_onProblemChanged);
    _problemCtrl.dispose();
    super.dispose();
  }

  void _onProblemChanged() {
    final selection = _problemCtrl.selection;
    final cursor = selection.baseOffset >= 0 ? selection.baseOffset : _problemCtrl.text.length;
    final text = _problemCtrl.text;
    if (cursor > text.length) return;

    final prefix = text.substring(0, cursor);
    final at = prefix.lastIndexOf('@');
    final hash = prefix.lastIndexOf('#');
    final trigger = at > hash ? '@' : '#';
    final triggerIndex = trigger == '@' ? at : hash;
    if (triggerIndex == -1) {
      _hideMentions();
      return;
    }

    if (triggerIndex > 0 && !RegExp(r'\s').hasMatch(prefix[triggerIndex - 1])) {
      _hideMentions();
      return;
    }

    final query = prefix.substring(triggerIndex + 1);
    if (query.contains(RegExp(r'\s'))) {
      _hideMentions();
      return;
    }

    final q = query.toLowerCase();
    if (trigger == '@') {
      final suggestions =
          widget.ctrl.libraryAgents.where((a) => q.isEmpty || a.title.toLowerCase().contains(q)).take(8).toList();
      setState(() {
        _mentionStart = triggerIndex;
        _activeTrigger = '@';
        _agentSuggestions = suggestions;
        _missionSuggestions = const [];
        _showMentions = true;
        _selectedSuggestionIndex = 0;
      });
      return;
    }

    final missionSuggestions = MissionService.instance.search(q);
    setState(() {
      _mentionStart = triggerIndex;
      _activeTrigger = '#';
      _agentSuggestions = const [];
      _missionSuggestions = missionSuggestions;
      _showMentions = true;
      _selectedSuggestionIndex = 0;
    });
  }

  int get _suggestionCount => _activeTrigger == '@' ? _agentSuggestions.length : _missionSuggestions.length;

  KeyEventResult _onProblemKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent || !_showMentions) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final count = _suggestionCount;

    if (key == LogicalKeyboardKey.escape) {
      _hideMentions();
      return KeyEventResult.handled;
    }

    if (count == 0) return KeyEventResult.ignored;

    if (key == LogicalKeyboardKey.arrowDown) {
      setState(() => _selectedSuggestionIndex = (_selectedSuggestionIndex + 1) % count);
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowUp) {
      setState(() => _selectedSuggestionIndex = (_selectedSuggestionIndex - 1 + count) % count);
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter) {
      if (_activeTrigger == '@') {
        _insertMention(_agentSuggestions[_selectedSuggestionIndex]);
      } else {
        _insertMission(_missionSuggestions[_selectedSuggestionIndex]);
      }
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  void _hideMentions() {
    if (!_showMentions && _agentSuggestions.isEmpty && _missionSuggestions.isEmpty) return;
    setState(() {
      _showMentions = false;
      _activeTrigger = '';
      _agentSuggestions = const [];
      _missionSuggestions = const [];
      _mentionStart = -1;
      _selectedSuggestionIndex = 0;
    });
  }

  void _insertMention(AgentModel agent) {
    final text = _problemCtrl.text;
    final selection = _problemCtrl.selection;
    final cursor = selection.baseOffset >= 0 ? selection.baseOffset : text.length;
    if (_mentionStart < 0 || _mentionStart >= cursor || cursor > text.length) return;

    final before = text.substring(0, _mentionStart);
    final after = text.substring(cursor);
    final mention = '@${agent.title} ';
    final next = '$before$mention$after';
    _problemCtrl.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: (before + mention).length),
    );
    _hideMentions();
  }

  void _insertMission(MissionModel mission) {
    final text = _problemCtrl.text;
    final selection = _problemCtrl.selection;
    final cursor = selection.baseOffset >= 0 ? selection.baseOffset : text.length;
    if (_mentionStart < 0 || _mentionStart >= cursor || cursor > text.length) return;

    final before = text.substring(0, _mentionStart);
    final after = text.substring(cursor);
    final mention = '#${mission.slug} ';
    final next = '$before$mention$after';
    _problemCtrl.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: (before + mention).length),
    );
    _hideMentions();
  }

  Future<void> _submit() async {
    final expanded = await MissionService.instance.expandMissionTags(_problemCtrl.text);
    final trimmed = expanded.trim();
    if (trimmed.isEmpty) return;
    _hideMentions();
    await widget.ctrl.findTeam(trimmed);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _GlowTextField(
          controller: _problemCtrl,
          onKeyEvent: _onProblemKeyEvent,
          hintText:
              'Describe your challenge or project...\n\nTip: Type @ to mention agents, # to mention missions.\n\nExample: I need to build a secure REST API with a nice dashboard and marketing copy.',
          maxLines: 5,
        ),
        if (_showMentions) ...[
          const SizedBox(height: 10),
          Container(
            constraints: const BoxConstraints(maxHeight: 180),
            decoration: BoxDecoration(
              color: AppTheme.card,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.border),
            ),
            child: Obx(() {
              if (_activeTrigger == '@' && widget.ctrl.isLibraryLoading.value) {
                return const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    'Loading library agents...',
                    style: TextStyle(color: AppTheme.textM, fontSize: 12),
                  ),
                );
              }

              final hasNoData = _activeTrigger == '@' ? _agentSuggestions.isEmpty : _missionSuggestions.isEmpty;
              if (hasNoData) {
                return const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    'No matches found',
                    style: TextStyle(color: AppTheme.textM, fontSize: 12),
                  ),
                );
              }

              if (_activeTrigger == '#') {
                return ListView.builder(
                  shrinkWrap: true,
                  itemCount: _missionSuggestions.length,
                  itemBuilder: (_, i) {
                    final mission = _missionSuggestions[i];
                    return ListTile(
                      dense: true,
                      visualDensity: VisualDensity.compact,
                      selected: i == _selectedSuggestionIndex,
                      selectedTileColor: AppTheme.gold.withValues(alpha: 0.12),
                      title: Text(
                        '#${mission.slug}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppTheme.gold, fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        mission.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppTheme.textM, fontSize: 11),
                      ),
                      onTap: () => _insertMission(mission),
                    );
                  },
                );
              }

              return ListView.builder(
                shrinkWrap: true,
                itemCount: _agentSuggestions.length,
                itemBuilder: (_, i) {
                  final agent = _agentSuggestions[i];
                  return ListTile(
                    dense: true,
                    visualDensity: VisualDensity.compact,
                    selected: i == _selectedSuggestionIndex,
                    selectedTileColor: AppTheme.primary.withValues(alpha: 0.14),
                    title: Text(
                      agent.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppTheme.textH, fontSize: 13),
                    ),
                    subtitle: Text(
                      agent.characterType.displayName,
                      style: const TextStyle(color: AppTheme.textM, fontSize: 11),
                    ),
                    onTap: () => _insertMention(agent),
                  );
                },
              );
            }),
          ),
        ],
        const SizedBox(height: 20),
        SizedBox(
          height: 48,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: AppTheme.textH,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.groups, size: 18),
            label: const Text(
              'Find My Team',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            onPressed: _submit,
          ),
        ),
      ],
    );
  }
}

class _GlowTextField extends StatefulWidget {
  final TextEditingController controller;
  final String hintText;
  final int maxLines;
  final KeyEventResult Function(FocusNode, KeyEvent)? onKeyEvent;
  const _GlowTextField({
    required this.controller,
    required this.hintText,
    this.maxLines = 1,
    this.onKeyEvent,
  });

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
            ? [BoxShadow(color: AppTheme.primary.withValues(alpha: 0.25), blurRadius: 16, spreadRadius: 2)]
            : [],
      ),
      child: Focus(
        onKeyEvent: widget.onKeyEvent,
        onFocusChange: (f) => setState(() => _focused = f),
        child: TextField(
          controller: widget.controller,
          maxLines: widget.maxLines,
          style: const TextStyle(color: AppTheme.textH, fontSize: 14),
          decoration: InputDecoration(
            hintText: widget.hintText,
            hintStyle: TextStyle(color: AppTheme.textM.withValues(alpha: 0.7), fontSize: 13),
            filled: true,
            fillColor: AppTheme.card,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
            ),
            contentPadding: const EdgeInsets.all(16),
          ),
        ),
      ),
    );
  }
}

class _AgentMiniCard extends StatefulWidget {
  final Map<String, dynamic> agent;
  final bool selected;
  final VoidCallback onTap;
  const _AgentMiniCard({required this.agent, required this.selected, required this.onTap});

  @override
  State<_AgentMiniCard> createState() => _AgentMiniCardState();
}

class _AgentMiniCardState extends State<_AgentMiniCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final charType = characterTypeFromString(widget.agent['character_type'] as String? ?? '');
    final color = charType.primaryColor;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: widget.selected
                ? color.withValues(alpha: 0.12)
                : _hovered
                    ? AppTheme.card2
                    : AppTheme.card,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: widget.selected
                  ? color
                  : _hovered
                      ? AppTheme.border2
                      : AppTheme.border,
              width: widget.selected ? 1.5 : 1,
            ),
            boxShadow: widget.selected
                ? [BoxShadow(color: color.withValues(alpha: 0.2), blurRadius: 10, spreadRadius: 1)]
                : [],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: color.withValues(alpha: 0.4)),
                  boxShadow: [BoxShadow(color: color.withValues(alpha: 0.2), blurRadius: 8)],
                ),
                child: Icon(_charTypeIcon(charType), color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.agent['title'] as String? ?? 'Unknown Agent',
                      style: const TextStyle(
                        color: AppTheme.textH,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        charType.displayName,
                        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                widget.selected ? Icons.check_circle : Icons.circle_outlined,
                color: widget.selected ? color : AppTheme.textM.withValues(alpha: 0.5),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _charTypeIcon(CharacterType t) => switch (t) {
        CharacterType.wizard => Icons.code,
        CharacterType.strategist => Icons.flag,
        CharacterType.oracle => Icons.bar_chart,
        CharacterType.guardian => Icons.shield,
        CharacterType.artisan => Icons.brush,
        CharacterType.bard => Icons.edit,
        CharacterType.scholar => Icons.school,
        CharacterType.merchant => Icons.trending_up,
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
          decoration: BoxDecoration(
            color: AppTheme.primary,
            borderRadius: BorderRadius.circular(12),
          ),
          child: SelectableText(
            text,
            style: const TextStyle(color: AppTheme.textH, fontSize: 14, height: 1.4),
          ),
        ),
      );
}

class _TeamResponseGroup extends StatelessWidget {
  final List<Map<String, dynamic>> responses;
  const _TeamResponseGroup({required this.responses});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: responses.map((r) => _TeamResponseCard(response: r)).toList(),
      );
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
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final charType = characterTypeFromString(
      widget.response['character_type'] as String? ?? '',
    );
    final color = charType.primaryColor;
    final title = widget.response['agent_title'] as String? ?? 'Agent';
    final role = widget.response['role'] as String? ?? 'Specialist';
    final reply = widget.response['reply'] as String? ?? '';

    return FadeTransition(
      opacity: _opacity,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(10),
          border: Border(left: BorderSide(color: color, width: 3)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(_charTypeIcon(charType), color: color, size: 14),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppTheme.textH,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      role,
                      style: TextStyle(color: color, fontSize: 10),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SelectableText(
                reply,
                style: const TextStyle(color: AppTheme.textB, fontSize: 13, height: 1.55),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _charTypeIcon(CharacterType t) => switch (t) {
        CharacterType.wizard => Icons.code,
        CharacterType.strategist => Icons.flag,
        CharacterType.oracle => Icons.bar_chart,
        CharacterType.guardian => Icons.shield,
        CharacterType.artisan => Icons.brush,
        CharacterType.bard => Icons.edit,
        CharacterType.scholar => Icons.school,
        CharacterType.merchant => Icons.trending_up,
      };
}
