// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

import 'package:flutter/material.dart';
import '../../../shared/services/api_service.dart';

class MiniChatWidget extends StatefulWidget {
  final int agentId;
  final String agentTitle;

  const MiniChatWidget({
    super.key,
    required this.agentId,
    required this.agentTitle,
  });

  @override
  State<MiniChatWidget> createState() => _MiniChatWidgetState();
}

class _MiniChatWidgetState extends State<MiniChatWidget> {
  List<({String role, String text})> _messages = [];
  final TextEditingController _ctrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  bool _sending = false;

  // ── Storage helpers ────────────────────────────────────────────────────────

  String get _storageKey => 'chat_history_${widget.agentId}';

  /// Serialises the message list and writes it to localStorage.
  void _saveHistory(List<({String role, String text})> messages) {
    final encoded =
        messages.map((m) => '${m.role}|||${m.text}').join(';;;');
    html.window.localStorage[_storageKey] = encoded;
  }

  /// Reads and deserialises the message list from localStorage.
  List<({String role, String text})> _loadHistory() {
    final raw = html.window.localStorage[_storageKey];
    if (raw == null || raw.isEmpty) return [];
    return raw
        .split(';;;')
        .map((entry) {
          final parts = entry.split('|||');
          if (parts.length != 2) return null;
          return (role: parts[0], text: parts[1]);
        })
        .whereType<({String role, String text})>()
        .toList();
  }

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _messages = _loadHistory();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _sending) return;

    _ctrl.clear();
    setState(() {
      _messages.add((role: 'user', text: text));
      _sending = true;
    });
    _scrollToBottom();

    final reply =
        await ApiService.instance.chatWithAgent(widget.agentId, text);

    if (mounted) {
      setState(() {
        _messages.add((
          role: 'assistant',
          text: reply ?? 'Bir hata olustu. Lutfen tekrar deneyin.',
        ));
        _sending = false;

        // Keep at most 50 messages to avoid storage bloat.
        if (_messages.length > 50) {
          _messages = _messages.sublist(_messages.length - 50);
        }
      });
      _saveHistory(_messages);
      _scrollToBottom();
    }
  }

  void _clearHistory() {
    setState(() => _messages = []);
    html.window.localStorage.remove(_storageKey);
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

  // ── UI ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 320,
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1E1E35)),
      ),
      child: Column(
        children: [
          // ── Header ─────────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFF1E1E35))),
            ),
            child: Row(
              children: [
                const Text(
                  '\u{1F4AC} Test Agent',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.agentTitle,
                    style: const TextStyle(
                        color: Color(0xFF6B7280), fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (_sending)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Color(0xFF6366F1)),
                  ),
                if (_messages.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.delete_outline,
                        size: 16, color: Color(0xFF6B7280)),
                    tooltip: 'Clear chat history',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: _clearHistory,
                  ),
              ],
            ),
          ),

          // ── Messages list ───────────────────────────────────────────────────
          Expanded(
            child: _messages.isEmpty
                ? const Center(
                    child: Text(
                      'Send a message to test this agent...',
                      style: TextStyle(
                          color: Color(0xFF4B5563), fontSize: 13),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.all(12),
                    itemCount: _messages.length,
                    itemBuilder: (_, i) {
                      final msg = _messages[i];
                      final isUser = msg.role == 'user';
                      return Align(
                        alignment: isUser
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          margin:
                              const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          constraints: BoxConstraints(
                            maxWidth:
                                MediaQuery.of(context).size.width * 0.6,
                          ),
                          decoration: BoxDecoration(
                            color: isUser
                                ? const Color(0xFF6366F1)
                                    .withValues(alpha: 0.8)
                                : const Color(0xFF1F2937),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            msg.text,
                            style: TextStyle(
                              color: isUser
                                  ? Colors.white
                                  : const Color(0xFFD1D5DB),
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // ── Input row ───────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFF1E1E35))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    style:
                        const TextStyle(color: Colors.white, fontSize: 13),
                    onSubmitted: (_) => _send(),
                    decoration: const InputDecoration(
                      hintText: 'Type a message...',
                      hintStyle: TextStyle(
                          color: Color(0xFF4B5563), fontSize: 13),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      filled: true,
                      fillColor: Color(0xFF111827),
                      enabledBorder: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.all(Radius.circular(8)),
                        borderSide:
                            BorderSide(color: Color(0xFF1E1E35)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.all(Radius.circular(8)),
                        borderSide:
                            BorderSide(color: Color(0xFF6366F1)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _sending ? null : _send,
                  icon: const Icon(Icons.send_rounded),
                  color: const Color(0xFF6366F1),
                  disabledColor: const Color(0xFF374151),
                  style: IconButton.styleFrom(
                    backgroundColor:
                        const Color(0xFF6366F1).withValues(alpha: 0.1),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
