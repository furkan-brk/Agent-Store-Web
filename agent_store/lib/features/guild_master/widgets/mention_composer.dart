// lib/features/guild_master/widgets/mention_composer.dart
//
// Self-contained composer widget: Monaco editor + @/#  mention suggestion
// dropdown. All mention state lives inside this widget. Parents access the
// editor's text via a GlobalKey<MentionComposerState>.

import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../features/character/character_types.dart';
import '../../../shared/models/agent_model.dart';
import '../../../shared/models/mission_model.dart';
import '../../../shared/services/mission_service.dart';
import '../../../shared/widgets/monaco_editor_widget.dart';
import 'mention_filter.dart';

class MentionComposer extends StatefulWidget {
  final double height;
  final bool submitOnEnter;
  final ValueChanged<String>? onChange;
  final ValueChanged<String>? onSubmit;

  /// Called fresh on every keystroke with an `@`. Lets parents pass a reactive
  /// library list without coupling the composer to GetX.
  final List<AgentModel> Function() agentProvider;

  /// When `true`, the `@` dropdown shows "Loading library agents…" instead of
  /// "No matches".
  final bool libraryLoading;

  const MentionComposer({
    super.key,
    required this.height,
    required this.agentProvider,
    this.submitOnEnter = false,
    this.onChange,
    this.onSubmit,
    this.libraryLoading = false,
  });

  @override
  State<MentionComposer> createState() => MentionComposerState();
}

class MentionComposerState extends State<MentionComposer> {
  final _editorKey = GlobalKey<MonacoEditorWidgetState>();
  final _scrollCtrl = ScrollController();

  // Approximate rendered height of each _MentionItem (padding + 2 text lines).
  static const _kItemH = 50.0;

  List<AgentModel> _agentSugg = const [];
  List<MissionModel> _missionSugg = const [];
  String _trigger = ''; // '' | '@' | '#'
  bool _visible = false;
  int _selected = 0;

  // ── Public API ────────────────────────────────────────────────────────────

  String getValue() => _editorKey.currentState?.getValue() ?? '';

  void setValue(String text) => _editorKey.currentState?.setValue(text);

  void clear() {
    _editorKey.currentState?.clear();
    _hide();
  }

  void focus() => _editorKey.currentState?.focus();

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ── Trigger handling ──────────────────────────────────────────────────────

  void _onTrigger(String trig, String query) {
    if (trig.isEmpty) {
      _hide();
      return;
    }
    final q = query.toLowerCase();
    setState(() {
      _trigger = trig;
      _selected = 0;
      _visible = true;
      if (trig == '@') {
        // Split library (owned) and store entries so each section gets its
        // own quota — store hits never push library entries out of view.
        _agentSugg = filterAgentSuggestions(widget.agentProvider(), query);
        _missionSugg = const [];
      } else {
        _missionSugg = MissionService.instance.search(q);
        _agentSugg = const [];
      }
    });
    // Reset scroll to top whenever suggestions refresh.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) _scrollCtrl.jumpTo(0);
    });
    _editorKey.currentState?.setMentionsVisible(true);
  }

  void _onMentionKey(String key) {
    if (!_visible) return;
    final count = _trigger == '@' ? _agentSugg.length : _missionSugg.length;
    switch (key) {
      case 'escape':
        _hide();
      case 'up':
        if (count > 0) {
          setState(() => _selected = (_selected - 1 + count) % count);
          _ensureSelectedVisible(count);
        }
      case 'down':
        if (count > 0) {
          setState(() => _selected = (_selected + 1) % count);
          _ensureSelectedVisible(count);
        }
      case 'enter':
        if (count > 0) {
          if (_trigger == '@') {
            _pickAgent(_agentSugg[_selected]);
          } else {
            _pickMission(_missionSugg[_selected]);
          }
        }
    }
  }

  void _ensureSelectedVisible(int count) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollCtrl.hasClients) return;
      if (_selected == 0) {
        _scrollCtrl.jumpTo(0);
        return;
      }
      if (_selected == count - 1) {
        _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
        return;
      }

      // Account for section headers (~28px each) that appear above items.
      const headerH = 28.0;
      final ownedCount = _agentSugg.where((a) => a.owned).length;
      final storeCount = _agentSugg.where((a) => !a.owned).length;

      double itemTop;
      if (ownedCount > 0 && _selected < ownedCount) {
        // In My Library section: 1 header above
        itemTop = headerH + _selected * _kItemH;
      } else {
        // In Store section: library header + library items + store header above
        final storeIdx = _selected - ownedCount;
        itemTop =
            (ownedCount > 0 ? headerH + ownedCount * _kItemH : 0) + (storeCount > 0 ? headerH : 0) + storeIdx * _kItemH;
      }

      final itemBottom = itemTop + _kItemH;
      final viewH = _scrollCtrl.position.viewportDimension;
      final currentTop = _scrollCtrl.offset;
      final currentBottom = currentTop + viewH;

      if (itemTop < currentTop) {
        _scrollCtrl.jumpTo(itemTop);
      } else if (itemBottom > currentBottom) {
        _scrollCtrl.jumpTo(itemBottom - viewH);
      }
    });
  }

  void _pickAgent(AgentModel a) {
    _editorKey.currentState?.insertMention(a.title, isAgent: true);
    _hide();
  }

  void _pickMission(MissionModel m) {
    _editorKey.currentState?.insertMention(m.slug, isAgent: false);
    _hide();
  }

  void _hide() {
    if (!_visible && _trigger.isEmpty) return;
    setState(() {
      _visible = false;
      _trigger = '';
      _agentSugg = const [];
      _missionSugg = const [];
      _selected = 0;
    });
    _editorKey.currentState?.setMentionsVisible(false);
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_visible) _buildDropdown(),
        MonacoEditorWidget(
          key: _editorKey,
          height: widget.height,
          submitOnEnter: widget.submitOnEnter,
          onChange: widget.onChange,
          onSubmit: (val) {
            _hide();
            widget.onSubmit?.call(val);
          },
          onTrigger: _onTrigger,
          onMentionKey: _onMentionKey,
        ),
      ],
    );
  }

  Widget _buildDropdown() {
    return Container(
      constraints: const BoxConstraints(maxHeight: 200),
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border),
        boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 8, offset: Offset(0, -2))],
      ),
      child: _buildDropdownBody(),
    );
  }

  Widget _buildDropdownBody() {
    if (_trigger == '@' && widget.libraryLoading && _agentSugg.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.md),
        child: Text('Loading library agents…', style: TextStyle(color: AppTheme.textM, fontSize: 12)),
      );
    }
    final isEmpty = _trigger == '@' ? _agentSugg.isEmpty : _missionSugg.isEmpty;
    if (isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.md),
        child: Text('No matches found', style: TextStyle(color: AppTheme.textM, fontSize: 12)),
      );
    }

    if (_trigger == '#') {
      return Scrollbar(
        controller: _scrollCtrl,
        thumbVisibility: true,
        child: ListView.builder(
          controller: _scrollCtrl,
          shrinkWrap: true,
          itemCount: _missionSugg.length,
          itemBuilder: (_, i) {
            final m = _missionSugg[i];
            return _MentionItem(
              isSelected: i == _selected,
              accent: AppTheme.gold,
              onTap: () => _pickMission(m),
              title: Text('#${m.slug}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppTheme.gold, fontSize: 13, fontWeight: FontWeight.w600)),
              subtitle: Text(m.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppTheme.textM, fontSize: 11)),
            );
          },
        ),
      );
    }

    final owned = _agentSugg.where((a) => a.owned).toList();
    final store = _agentSugg.where((a) => !a.owned).toList();
    final children = <Widget>[];

    if (owned.isNotEmpty) {
      children.add(const _SectionLabel(
        icon: Icons.bookmark_rounded,
        label: 'My Library',
        color: AppTheme.primary,
      ));
      for (int i = 0; i < owned.length; i++) {
        final idx = i;
        final a = owned[i];
        children.add(_MentionItem(
          isSelected: idx == _selected,
          accent: AppTheme.primary,
          isOwned: true,
          onTap: () => _pickAgent(a),
          title: Text('@${a.title}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: AppTheme.primary,
                  fontSize: 13,
                  fontWeight: idx == _selected ? FontWeight.w700 : FontWeight.w500)),
          subtitle: Text(a.characterType.displayName, style: const TextStyle(color: AppTheme.textM, fontSize: 11)),
        ));
      }
    }

    if (store.isNotEmpty) {
      children.add(const _SectionLabel(
        icon: Icons.storefront_rounded,
        label: 'Store',
        color: AppTheme.textM,
      ));
      for (int i = 0; i < store.length; i++) {
        final idx = owned.length + i;
        final a = store[i];
        children.add(_MentionItem(
          isSelected: idx == _selected,
          accent: AppTheme.textM,
          isOwned: false,
          onTap: () => _pickAgent(a),
          title: Text('@${a.title}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: AppTheme.textH,
                  fontSize: 13,
                  fontWeight: idx == _selected ? FontWeight.w600 : FontWeight.w400)),
          subtitle: Text(a.characterType.displayName, style: const TextStyle(color: AppTheme.textM, fontSize: 11)),
        ));
      }
    }

    return Scrollbar(
      controller: _scrollCtrl,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: _scrollCtrl,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );
  }
}

// ── Section label ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _SectionLabel({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 2),
      child: Row(children: [
        Icon(icon, size: 11, color: color.withValues(alpha: 0.7)),
        const SizedBox(width: 5),
        Text(label,
            style: TextStyle(
                color: color.withValues(alpha: 0.7), fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.6)),
      ]),
    );
  }
}

// ── Mention dropdown item ─────────────────────────────────────────────────────

class _MentionItem extends StatelessWidget {
  final bool isSelected;
  final bool isOwned;
  final Color accent;
  final VoidCallback onTap;
  final Widget title;
  final Widget? subtitle;

  const _MentionItem({
    required this.isSelected,
    required this.accent,
    required this.onTap,
    required this.title,
    this.isOwned = false,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          color: isSelected ? accent.withValues(alpha: 0.18) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border(
            left: BorderSide(
              color: isSelected ? accent : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
        child: Row(children: [
          if (isOwned) ...[
            Icon(Icons.bookmark_rounded, size: 12, color: AppTheme.primary.withValues(alpha: isSelected ? 1.0 : 0.6)),
            const SizedBox(width: 5),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                title,
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  subtitle!,
                ],
              ],
            ),
          ),
        ]),
      ),
    );
  }
}
