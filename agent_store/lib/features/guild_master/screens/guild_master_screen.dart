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
import '../../../shared/utils/app_snack_bar.dart';

// ── Shared utilities ──────────────────────────────────────────────────────────

IconData _charTypeIcon(CharacterType t) => switch (t) {
      CharacterType.wizard => Icons.auto_awesome,
      CharacterType.strategist => Icons.psychology,
      CharacterType.oracle => Icons.bar_chart,
      CharacterType.guardian => Icons.shield,
      CharacterType.artisan => Icons.brush,
      CharacterType.bard => Icons.edit,
      CharacterType.scholar => Icons.school,
      CharacterType.merchant => Icons.trending_up,
    };

// ── Mention autocomplete mixin ─────────────────────────────────────────────────
//
// Shared by _ChatPanelState and _ProblemPromptComposerState.
// Handles @agent and #mission inline autocomplete — state, keyboard nav, and dropdown UI.

mixin _MentionStateMixin<T extends StatefulWidget> on State<T> {
  List<AgentModel> _mentionAgents = const [];
  List<MissionModel> _mentionMissions = const [];
  String _mentionTrigger = '';
  bool _showMentions = false;
  int _mentionStart = -1;
  int _selectedMention = 0;

  int get _mentionCount =>
      _mentionTrigger == '@' ? _mentionAgents.length : _mentionMissions.length;

  void _onMentionChanged(TextEditingController ctrl, List<AgentModel> libraryAgents) {
    final selection = ctrl.selection;
    final cursor = selection.baseOffset >= 0 ? selection.baseOffset : ctrl.text.length;
    final text = ctrl.text;
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
      final suggestions = libraryAgents
          .where((a) => q.isEmpty || a.title.toLowerCase().contains(q))
          .take(8)
          .toList();
      setState(() {
        _mentionStart = triggerIndex;
        _mentionTrigger = '@';
        _mentionAgents = suggestions;
        _mentionMissions = const [];
        _showMentions = true;
        _selectedMention = 0;
      });
      return;
    }

    final missions = MissionService.instance.search(q);
    setState(() {
      _mentionStart = triggerIndex;
      _mentionTrigger = '#';
      _mentionAgents = const [];
      _mentionMissions = missions;
      _showMentions = true;
      _selectedMention = 0;
    });
  }

  KeyEventResult _onMentionKeyEvent(
      FocusNode node, KeyEvent event, TextEditingController ctrl) {
    if (event is! KeyDownEvent || !_showMentions) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final count = _mentionCount;

    if (key == LogicalKeyboardKey.escape) {
      _hideMentions();
      return KeyEventResult.handled;
    }
    if (count == 0) return KeyEventResult.ignored;

    if (key == LogicalKeyboardKey.arrowDown) {
      setState(() => _selectedMention = (_selectedMention + 1) % count);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      setState(() => _selectedMention = (_selectedMention - 1 + count) % count);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter) {
      if (_mentionTrigger == '@') {
        _insertAgentMention(_mentionAgents[_selectedMention], ctrl);
      } else {
        _insertMissionMention(_mentionMissions[_selectedMention], ctrl);
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _hideMentions() {
    if (!_showMentions && _mentionAgents.isEmpty && _mentionMissions.isEmpty) return;
    setState(() {
      _showMentions = false;
      _mentionTrigger = '';
      _mentionAgents = const [];
      _mentionMissions = const [];
      _mentionStart = -1;
      _selectedMention = 0;
    });
  }

  void _insertAgentMention(AgentModel agent, TextEditingController ctrl) {
    final text = ctrl.text;
    final selection = ctrl.selection;
    final cursor = selection.baseOffset >= 0 ? selection.baseOffset : text.length;
    if (_mentionStart < 0 || _mentionStart >= cursor || cursor > text.length) return;
    final before = text.substring(0, _mentionStart);
    final after = text.substring(cursor);
    final mention = '@${agent.title} ';
    ctrl.value = TextEditingValue(
      text: '$before$mention$after',
      selection: TextSelection.collapsed(offset: (before + mention).length),
    );
    _hideMentions();
  }

  void _insertMissionMention(MissionModel mission, TextEditingController ctrl) {
    final text = ctrl.text;
    final selection = ctrl.selection;
    final cursor = selection.baseOffset >= 0 ? selection.baseOffset : text.length;
    if (_mentionStart < 0 || _mentionStart >= cursor || cursor > text.length) return;
    final before = text.substring(0, _mentionStart);
    final after = text.substring(cursor);
    final mention = '#${mission.slug} ';
    ctrl.value = TextEditingValue(
      text: '$before$mention$after',
      selection: TextSelection.collapsed(offset: (before + mention).length),
    );
    _hideMentions();
  }

  Widget _buildMentionDropdown({
    required GuildMasterController gmCtrl,
    required TextEditingController textCtrl,
    EdgeInsetsGeometry margin = const EdgeInsets.only(bottom: 10),
  }) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 180),
      margin: margin,
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border),
      ),
      child: Obx(() {
        if (_mentionTrigger == '@' && gmCtrl.isLibraryLoading.value) {
          return const Padding(
            padding: EdgeInsets.all(AppSpacing.md),
            child: Text('Loading library agents...',
                style: TextStyle(color: AppTheme.textM, fontSize: 12)),
          );
        }
        final hasNoData =
            _mentionTrigger == '@' ? _mentionAgents.isEmpty : _mentionMissions.isEmpty;
        if (hasNoData) {
          return const Padding(
            padding: EdgeInsets.all(AppSpacing.md),
            child: Text('No matches found',
                style: TextStyle(color: AppTheme.textM, fontSize: 12)),
          );
        }
        if (_mentionTrigger == '#') {
          return ListView.builder(
            shrinkWrap: true,
            itemCount: _mentionMissions.length,
            itemBuilder: (_, i) {
              final mission = _mentionMissions[i];
              return ListTile(
                dense: true,
                visualDensity: VisualDensity.compact,
                selected: i == _selectedMention,
                selectedTileColor: AppTheme.gold.withValues(alpha: 0.12),
                title: Text('#${mission.slug}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: AppTheme.gold,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
                subtitle: Text(mission.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppTheme.textM, fontSize: 11)),
                onTap: () => _insertMissionMention(mission, textCtrl),
              );
            },
          );
        }
        return ListView.builder(
          shrinkWrap: true,
          itemCount: _mentionAgents.length,
          itemBuilder: (_, i) {
            final agent = _mentionAgents[i];
            return ListTile(
              dense: true,
              visualDensity: VisualDensity.compact,
              selected: i == _selectedMention,
              selectedTileColor: AppTheme.primary.withValues(alpha: 0.14),
              title: Text(agent.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppTheme.textH, fontSize: 13)),
              subtitle: Text(agent.characterType.displayName,
                  style: const TextStyle(color: AppTheme.textM, fontSize: 11)),
              onTap: () => _insertAgentMention(agent, textCtrl),
            );
          },
        );
      }),
    );
  }
}

// ── Screen root ───────────────────────────────────────────────────────────────

class GuildMasterScreen extends StatelessWidget {
  final List<Map<String, dynamic>>? initialAgents;
  final String? initialGuildName;

  const GuildMasterScreen({super.key, this.initialAgents, this.initialGuildName});

  @override
  Widget build(BuildContext context) {
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
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
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
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Describe your project or challenge and Guild Master will assemble the ideal team of AI agents to tackle it together.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppTheme.textM.withValues(alpha: 0.85),
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              _ProblemPromptComposer(ctrl: ctrl),
              Obx(() {
                if (ctrl.error.value != null) {
                  return Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.md),
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
      ),
    );
  }

  Widget _buildLoading(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(
              color: AppTheme.primary,
              strokeWidth: 3,
              backgroundColor: Color(0x4D3D3020),
            ),
          ),
          SizedBox(height: AppSpacing.xl),
          Text(
            'Analyzing your challenge...',
            style: TextStyle(color: AppTheme.textB, fontSize: 15, fontWeight: FontWeight.w500),
          ),
          SizedBox(height: AppSpacing.sm),
          Text(
            'Selecting the best agents for your team',
            style: TextStyle(color: AppTheme.textM, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildReady(BuildContext context, GuildMasterController ctrl) {
    return LayoutBuilder(builder: (context, constraints) {
      final isNarrow = AppBreakpoints.isMobile(constraints.maxWidth);

      if (isNarrow) {
        final panelH = (constraints.maxHeight * 0.32).clamp(220.0, 320.0);
        return Column(children: [
          SizedBox(height: panelH, child: _LeftPanel(ctrl: ctrl)),
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
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl, AppSpacing.xl, AppSpacing.xl, AppSpacing.md),
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
                        const SizedBox(width: AppSpacing.sm),
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
                    const SizedBox(height: AppSpacing.sm + 2),
                    Text(
                      ctrl.suggestion.value?['suggested_name'] as String? ?? 'Custom Squad',
                      style: const TextStyle(
                        color: AppTheme.textH,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
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
          Expanded(
            child: Obx(() {
              if (ctrl.teamAgents.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.group_off_outlined,
                          color: AppTheme.textM.withValues(alpha: 0.5), size: 40),
                      const SizedBox(height: AppSpacing.md),
                      const Text('No agents found',
                          style: TextStyle(color: AppTheme.textM, fontSize: 13)),
                      const SizedBox(height: AppSpacing.xs),
                      const Text('Try a different challenge description',
                          style: TextStyle(color: AppTheme.textM, fontSize: 11)),
                    ],
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md, vertical: AppSpacing.sm),
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
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
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

class _ChatPanelState extends State<_ChatPanel> with _MentionStateMixin<_ChatPanel> {
  final _chatCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _chatCtrl.addListener(
        () => _onMentionChanged(_chatCtrl, widget.ctrl.libraryAgents));
    widget.ctrl.ensureLibraryLoaded();
  }

  @override
  void dispose() {
    _chatCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
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
    if (widget.ctrl.selectedAgentIds.isEmpty) {
      if (mounted) AppSnackBar.info(context, 'Select at least one agent from the team panel');
      return;
    }
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
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl, vertical: AppSpacing.lg),
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
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.gold.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.gold.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      '${widget.ctrl.selectedAgentIds.length} agent${widget.ctrl.selectedAgentIds.length == 1 ? '' : 's'} active',
                      style: const TextStyle(
                          color: AppTheme.gold, fontSize: 11, fontWeight: FontWeight.w500),
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
                    Icon(Icons.forum_outlined,
                        color: AppTheme.textM.withValues(alpha: 0.4), size: 48),
                    const SizedBox(height: AppSpacing.md),
                    const Text(
                      'Ask your team anything!',
                      style: TextStyle(
                          color: AppTheme.textB,
                          fontSize: 15,
                          fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: AppSpacing.xs),
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
              padding: const EdgeInsets.all(AppSpacing.lg),
              itemCount:
                  widget.ctrl.messages.length + (widget.ctrl.isChatLoading.value ? 1 : 0),
              itemBuilder: (_, i) {
                if (i == widget.ctrl.messages.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.sm),
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
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: msg.teamResponses!
                      .map((r) => _TeamResponseCard(response: r))
                      .toList(),
                );
              },
            );
          }),
        ),

        // -- Input bar --
        Container(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.lg),
          decoration: const BoxDecoration(
            color: AppTheme.surface,
            border: Border(top: BorderSide(color: AppTheme.border)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_showMentions)
                _buildMentionDropdown(gmCtrl: widget.ctrl, textCtrl: _chatCtrl),
              Row(
                children: [
                  Expanded(
                    child: Focus(
                      onKeyEvent: (node, event) =>
                          _onMentionKeyEvent(node, event, _chatCtrl),
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
                            borderSide:
                                const BorderSide(color: AppTheme.primary, width: 1.5),
                          ),
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 14, vertical: AppSpacing.md),
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
                            disabledBackgroundColor:
                                AppTheme.primary.withValues(alpha: 0.4),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                            padding:
                                const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                          ),
                          onPressed: widget.ctrl.isChatLoading.value ||
                                  widget.ctrl.selectedAgentIds.isEmpty
                              ? null
                              : _sendMessage,
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

// ── Problem prompt composer ───────────────────────────────────────────────────

class _ProblemPromptComposer extends StatefulWidget {
  final GuildMasterController ctrl;
  const _ProblemPromptComposer({required this.ctrl});

  @override
  State<_ProblemPromptComposer> createState() => _ProblemPromptComposerState();
}

class _ProblemPromptComposerState extends State<_ProblemPromptComposer>
    with _MentionStateMixin<_ProblemPromptComposer> {
  final _problemCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _problemCtrl.addListener(
        () => _onMentionChanged(_problemCtrl, widget.ctrl.libraryAgents));
    // Restore text when returning from a failed submit (phase reset to input)
    if (widget.ctrl.lastProblem.isNotEmpty) {
      _problemCtrl.text = widget.ctrl.lastProblem;
    }
    widget.ctrl.ensureLibraryLoaded();
  }

  @override
  void dispose() {
    _problemCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final expanded =
        await MissionService.instance.expandMissionTags(_problemCtrl.text);
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
          onKeyEvent: (node, event) => _onMentionKeyEvent(node, event, _problemCtrl),
          hintText:
              'Describe your challenge or project...\n\nTip: Type @ to mention agents, # to mention missions.\n\nExample: I need to build a secure REST API with a nice dashboard and marketing copy.',
          maxLines: 5,
        ),
        if (_showMentions) ...[
          const SizedBox(height: 10),
          _buildMentionDropdown(
            gmCtrl: widget.ctrl,
            textCtrl: _problemCtrl,
            margin: EdgeInsets.zero,
          ),
        ],
        const SizedBox(height: AppSpacing.xl - 4),
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

// ── Glow text field ───────────────────────────────────────────────────────────

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
        borderRadius: BorderRadius.circular(AppSizing.cardRadius - 2),
        boxShadow: _focused
            ? [
                BoxShadow(
                    color: AppTheme.primary.withValues(alpha: 0.25),
                    blurRadius: 16,
                    spreadRadius: 2)
              ]
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
              borderRadius: BorderRadius.circular(AppSizing.cardRadius - 2),
              borderSide: const BorderSide(color: AppTheme.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSizing.cardRadius - 2),
              borderSide: const BorderSide(color: AppTheme.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSizing.cardRadius - 2),
              borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
            ),
            contentPadding: const EdgeInsets.all(AppSpacing.lg),
          ),
        ),
      ),
    );
  }
}

// ── Agent mini card ───────────────────────────────────────────────────────────

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
          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
          padding: const EdgeInsets.all(AppSpacing.md),
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
                width: AppSizing.minTapTarget,
                height: AppSizing.minTapTarget,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: color.withValues(alpha: 0.4)),
                  boxShadow: [BoxShadow(color: color.withValues(alpha: 0.2), blurRadius: 8)],
                ),
                child: Icon(_charTypeIcon(charType), color: color, size: 22),
              ),
              const SizedBox(width: AppSpacing.md),
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
                    const SizedBox(height: AppSpacing.xs),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        charType.displayName,
                        style: TextStyle(
                            color: color, fontSize: 10, fontWeight: FontWeight.w500),
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
}

// ── Chat bubbles ──────────────────────────────────────────────────────────────

class _UserBubble extends StatelessWidget {
  final String text;
  const _UserBubble({required this.text});

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.md, left: 60),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppTheme.primary,
            borderRadius: BorderRadius.circular(AppSpacing.md),
          ),
          child: SelectableText(
            text,
            style: const TextStyle(color: AppTheme.textH, fontSize: 14, height: 1.4),
          ),
        ),
      );
}

// ── Team response card ────────────────────────────────────────────────────────

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
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 350))
      ..forward();
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
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(10),
          border: Border(left: BorderSide(color: color, width: 3)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md + 2),
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
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            color: color,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          role,
                          style: const TextStyle(color: AppTheme.textM, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm + 2),
              SelectableText(
                reply,
                style: const TextStyle(
                    color: AppTheme.textB, fontSize: 13, height: 1.6),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
