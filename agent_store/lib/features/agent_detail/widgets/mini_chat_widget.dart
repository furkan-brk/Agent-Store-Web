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
  static const _panelBg = Color(0xFFD4C6A7);
  static const _panelBorder = Color(0xFF9B8B66);
  static const _assistantBubbleBg = Color(0xFF2F3522);
  static const _assistantText = Color(0xFFF2E8D2);
  static const _userBubbleBg = Color(0xFF8E2C24);
  static const _inputBg = Color(0xFFE5D6B5);
  static const _inputText = Color(0xFF2B2C1E);

  List<({String role, String text})> _messages = [];
  final TextEditingController _ctrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  bool _sending = false;

  // ── Storage helpers ────────────────────────────────────────────────────────

  String get _storageKey => 'chat_history_${widget.agentId}';

  /// Serialises the message list and writes it to localStorage.
  void _saveHistory(List<({String role, String text})> messages) {
    final encoded = messages.map((m) => '${m.role}|||${m.text}').join(';;;');
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

    final reply = await ApiService.instance.chatWithAgent(widget.agentId, text);

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

  void _showTerminalModal(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _TerminalModal(
        agentId: widget.agentId,
        agentTitle: widget.agentTitle,
      ),
    );
  }

  // ── UI ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 320,
      decoration: BoxDecoration(
        color: _panelBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _panelBorder),
      ),
      child: Column(
        children: [
          // ── Header ─────────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: _panelBorder)),
            ),
            child: Row(
              children: [
                const Text(
                  '\u{1F4AC} Test Agent',
                  style: TextStyle(
                    color: Color(0xFF2B2C1E),
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.agentTitle,
                    style: const TextStyle(color: Color(0xFF5A4D34), fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (_sending)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF81231E)),
                  ),
                IconButton(
                  icon: const Icon(Icons.terminal, size: 16, color: Color(0xFF6366F1)),
                  tooltip: 'Terminal\'den çalıştır',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => _showTerminalModal(context),
                ),
                const SizedBox(width: 8),
                if (_messages.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 16, color: Color(0xFF7A6E52)),
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
                      style: TextStyle(color: Color(0xFF4A4030), fontSize: 13),
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
                        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.6,
                          ),
                          decoration: BoxDecoration(
                            color: isUser ? _userBubbleBg.withValues(alpha: 0.8) : _assistantBubbleBg,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            msg.text,
                            style: TextStyle(
                              color: isUser ? Colors.white : _assistantText,
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
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: _panelBorder)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    style: const TextStyle(color: _inputText, fontSize: 13),
                    onSubmitted: (_) => _send(),
                    decoration: const InputDecoration(
                      hintText: 'Type a message...',
                      hintStyle: TextStyle(color: Color(0xFF6A5C42), fontSize: 13),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      filled: true,
                      fillColor: _inputBg,
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(8)),
                        borderSide: BorderSide(color: _panelBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(8)),
                        borderSide: BorderSide(color: Color(0xFF81231E)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _sending ? null : _send,
                  icon: const Icon(Icons.send_rounded),
                  color: const Color(0xFF81231E),
                  disabledColor: const Color(0xFFC0B490),
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFF81231E).withValues(alpha: 0.1),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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

class _TerminalModal extends StatelessWidget {
  final int agentId;
  final String agentTitle;

  const _TerminalModal({
    required this.agentId,
    required this.agentTitle,
  });

  @override
  Widget build(BuildContext context) {
    final curlCommand = '''curl 'http://localhost:8080/api/v1/agents/$agentId/chat' \\
  -X POST \\
  -H 'Content-Type: application/json' \\
  -H 'Authorization: Bearer YOUR_JWT_TOKEN' \\
  --data-raw '{"message":"Merhaba, nasılsın?"}' ''';

    final pythonExample = '''import requests

url = "http://localhost:8080/api/v1/agents/$agentId/chat"
headers = {
    "Content-Type": "application/json",
    "Authorization": "Bearer YOUR_JWT_TOKEN"
}
data = {"message": "Merhaba, nasılsın?"}

response = requests.post(url, headers=headers, json=data)
print(response.json())''';

    final nodeExample = '''const axios = require('axios');

async function chatWithAgent() {
  try {
    const response = await axios.post(
      'http://localhost:8080/api/v1/agents/$agentId/chat',
      { message: 'Merhaba, nasılsın?' },
      {
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer YOUR_JWT_TOKEN'
        }
      }
    );
    console.log(response.data);
  } catch (error) {
    console.error(error.response.data);
  }
}

chatWithAgent();''';

    return Dialog(
      backgroundColor: const Color(0xFF1F2937),
      child: Container(
        width: 700,
        height: 600,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.terminal, color: Color(0xFF6366F1), size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Terminal\'den $agentTitle Agent\'ı Kullan',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: Color(0xFF6B7280)),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: DefaultTabController(
                length: 3,
                child: Column(
                  children: [
                    const TabBar(
                      labelColor: Color(0xFF6366F1),
                      unselectedLabelColor: Color(0xFF6B7280),
                      indicatorColor: Color(0xFF6366F1),
                      tabs: [
                        Tab(text: 'cURL'),
                        Tab(text: 'Python'),
                        Tab(text: 'Node.js'),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: TabBarView(
                        children: [
                          _buildCodeSection('Bash/Terminal', curlCommand),
                          _buildCodeSection('Python', pythonExample),
                          _buildCodeSection('JavaScript', nodeExample),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0F1419),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF374151)),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '💡 Authentication',
                    style: TextStyle(
                      color: Color(0xFFFBBF24),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'JWT token almanız gerekiyor. Wallet bağlandıktan sonra browser developer tools\'tan Authorization header\'ını kopyalayın.',
                    style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCodeSection(String language, String code) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F1419),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF374151)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFF374151))),
            ),
            child: Row(
              children: [
                Text(
                  language,
                  style: const TextStyle(
                    color: Color(0xFF6366F1),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => _copyToClipboard(code),
                  icon: const Icon(Icons.copy, size: 14, color: Color(0xFF6B7280)),
                  label: const Text(
                    'Kopyala',
                    style: TextStyle(color: Color(0xFF6B7280), fontSize: 11),
                  ),
                  style: TextButton.styleFrom(
                    minimumSize: Size.zero,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: SelectableText(
                code,
                style: const TextStyle(
                  color: Color(0xFFD1D5DB),
                  fontFamily: 'monospace',
                  fontSize: 11,
                  height: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _copyToClipboard(String text) {
    html.window.navigator.clipboard?.writeText(text);
  }
}
