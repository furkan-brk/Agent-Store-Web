// lib/features/agent_detail/widgets/external_use_modal.dart
//
// Unified "Use Agent Externally" modal — replaces the previously separate
// `OpenClawInstallModal` (header `extension_outlined` icon) and
// `_TerminalModal` (chat-area `terminal` icon, since removed) with one
// 4-tab dialog wrapped in the project's warm vintage AppTheme palette
// (no indigo / no slate — gold + crimson + dark brown only).
//
//   ┌─ Header: extension icon + "Use <agent>" + close ─────────────────────┐
//   │                                                                      │
//   │  [ OpenClaw ]   cURL    Python    Node.js                            │
//   │  ──────────                                                          │
//   │                                                                      │
//   │  (selected tab body)                                                 │
//   │                                                                      │
//   └─ Footer: 💡 Authentication / ℹ️ How install works ───────────────────┘
//
// Tab 0 (OpenClaw):
//   - `openclaw://install-skill?url=<encoded SKILL.md URL>` deeplink button
//     with attached-anchor click recipe (works for custom protocols where
//     the detached form is silently dropped by Chrome/Edge).
//   - manual `mkdir + curl` install one-liner.
//   - "Get OpenClaw" link → openclaw.ai.
//   - When `hasAccess` is true: extra "Download Full SKILL.md" CTA.
//   - When `hasAccess` is false: "Purchase to unlock prompt" banner.
//
// Tabs 1–3 (cURL / Python / Node.js):
//   - Chat-endpoint code samples (verbatim from the legacy `_TerminalModal`).
//
// Single entry point: the Agent Detail header `extension_outlined` icon
// always opens at OpenClaw tab. There used to be a second entry from the
// MiniChatWidget terminal icon — removed at user request to avoid duplicate
// surfaces.

import 'dart:async';
import 'dart:js_interop';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:web/web.dart' as web;

import '../../../app/theme.dart';
import '../../../core/constants/api_constants.dart';
import '../../../shared/services/api_service.dart';
import '../../../shared/utils/app_snack_bar.dart';

class ExternalUseModal extends StatelessWidget {
  /// Agent ID — used for both the SKILL.md deeplink and the `/chat` examples.
  final int agentId;

  /// Title — shown in the header and used to derive the SKILL.md slug.
  final String agentTitle;

  /// Owner OR purchaser? Controls the OpenClaw tab's gating UI:
  ///   - `true`  → "Download Full SKILL.md" CTA visible, purchase banner hidden
  ///   - `false` → purchase banner visible, full download hidden
  /// The deeplink + curl install flows are unaffected; they always hit the
  /// public endpoint that serves a redacted body for non-owners.
  final bool hasAccess;

  /// 0 = OpenClaw, 1 = cURL, 2 = Python, 3 = Node.js. Out-of-range values
  /// clamp to 0 via `DefaultTabController` semantics.
  final int initialTab;

  const ExternalUseModal({
    super.key,
    required this.agentId,
    required this.agentTitle,
    required this.hasAccess,
    this.initialTab = 0,
  });

  // The OpenClaw deeplink "Open" button stays red — it's the brand-recognisable
  // OpenClaw accent and contrasts nicely with the warm dark theme. Everything
  // else (tabs, code blocks, links, callouts) uses AppTheme primitives so the
  // modal feels native to the rest of the app.
  static const _openclawRed = Color(0xFFEF4444);

  // ── Slug + URL builders ──────────────────────────────────────────────────
  String get _slug => agentTitle
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'-+$'), '');

  String get _skillMdUrl => '${ApiConstants.agents}/$agentId/skill.md';

  String get _chatUrl => '${ApiConstants.baseUrl}/api/v1/agents/$agentId/chat';

  String get _deeplink {
    final encoded = Uri.encodeComponent(_skillMdUrl);
    return 'openclaw://install-skill?url=$encoded';
  }

  String get _curlInstall =>
      'mkdir -p ~/.openclaw/workspace/skills/$_slug && \\\n'
      '  curl -fsSL -o ~/.openclaw/workspace/skills/$_slug/SKILL.md \\\n'
      '  $_skillMdUrl';

  // Code-sample builders for the chat-endpoint tabs. Strings are byte-for-byte
  // identical to the legacy `_TerminalModal` so any operator muscle-memory
  // (e.g. existing snippets in personal notes) keeps working.
  String _curlChatSample() => '''curl '$_chatUrl' \\
  -X POST \\
  -H 'Content-Type: application/json' \\
  -H 'Authorization: Bearer YOUR_JWT_TOKEN' \\
  --data-raw '{"message":"Hello, how are you?"}' ''';

  String _pythonChatSample() => '''import requests

url = "$_chatUrl"
headers = {
    "Content-Type": "application/json",
    "Authorization": "Bearer YOUR_JWT_TOKEN"
}
data = {"message": "Hello, how are you?"}

response = requests.post(url, headers=headers, json=data)
print(response.json())''';

  String _nodeChatSample() => '''const axios = require('axios');

async function chatWithAgent() {
  try {
    const response = await axios.post(
      '$_chatUrl',
      { message: 'Hello, how are you?' },
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

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppTheme.border2),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
          child: DefaultTabController(
            length: 4,
            initialIndex: initialTab.clamp(0, 3),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Header(agentTitle: agentTitle),
                const SizedBox(height: 14),
                const TabBar(
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  labelColor: AppTheme.gold,
                  unselectedLabelColor: AppTheme.textM,
                  indicatorColor: AppTheme.gold,
                  indicatorWeight: 2.5,
                  dividerColor: AppTheme.border,
                  tabs: [
                    Tab(text: 'OpenClaw'),
                    Tab(text: 'cURL'),
                    Tab(text: 'Python'),
                    Tab(text: 'Node.js'),
                  ],
                ),
                const SizedBox(height: 14),
                Flexible(
                  child: TabBarView(
                    children: [
                      _OpenClawTab(
                        agentId: agentId,
                        slug: _slug,
                        deeplink: _deeplink,
                        curlInstall: _curlInstall,
                        hasAccess: hasAccess,
                      ),
                      _CodeBlock(
                        language: 'Bash / Terminal',
                        code: _curlChatSample(),
                      ),
                      _CodeBlock(
                        language: 'Python',
                        code: _pythonChatSample(),
                      ),
                      _CodeBlock(
                        language: 'JavaScript',
                        code: _nodeChatSample(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                const _FooterCallouts(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Header ─────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final String agentTitle;
  const _Header({required this.agentTitle});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: ExternalUseModal._openclawRed.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.extension_outlined,
              color: ExternalUseModal._openclawRed, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            'Use $agentTitle',
            style: const TextStyle(
              color: AppTheme.textH,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close, color: AppTheme.textM, size: 20),
          tooltip: 'Close',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}

// ─── OpenClaw tab body ──────────────────────────────────────────────────────

class _OpenClawTab extends StatelessWidget {
  final int agentId;
  final String slug;
  final String deeplink;
  final String curlInstall;
  final bool hasAccess;

  const _OpenClawTab({
    required this.agentId,
    required this.slug,
    required this.deeplink,
    required this.curlInstall,
    required this.hasAccess,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!hasAccess) const _PurchaseBanner(),
          if (!hasAccess) const SizedBox(height: 14),

          // Section 1 — deeplink
          const _SectionLabel(step: '1', title: 'Open in OpenClaw (one click)'),
          const SizedBox(height: 8),
          _DeeplinkRow(
            deeplink: deeplink,
            onClipboard: () => _copyAndToast(context, deeplink,
                'Deeplink copied — paste into OpenClaw'),
          ),
          const SizedBox(height: 8),
          // Inline hint — explains the silent-failure case where OpenClaw
          // isn't installed. Custom protocols never throw a visible error
          // when the OS has no handler, so we surface that proactively.
          const Text(
            'Clicking Open asks your OS to launch OpenClaw. If nothing happens, '
            "OpenClaw isn't installed yet — get it from openclaw.ai, or use the "
            'manual install below.',
            style: TextStyle(
              color: AppTheme.textM,
              fontSize: 11.5,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => _openInBrowser('https://openclaw.ai'),
              icon: const Icon(Icons.open_in_new,
                  size: 13, color: AppTheme.gold),
              label: const Text(
                'Get OpenClaw',
                style: TextStyle(color: AppTheme.gold, fontSize: 11.5),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                visualDensity: VisualDensity.compact,
                minimumSize: const Size(0, 28),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Section 2 — manual curl install
          const _SectionLabel(step: '2', title: 'Manual install (curl)'),
          const SizedBox(height: 8),
          _CurlBlock(
            command: curlInstall,
            onClipboard: () =>
                _copyAndToast(context, curlInstall, 'Command copied'),
          ),

          // Section 3 — full SKILL.md download for owners/purchasers
          if (hasAccess) ...[
            const SizedBox(height: 18),
            const Divider(color: AppTheme.border, height: 1),
            const SizedBox(height: 14),
            Row(children: [
              const Expanded(
                child: Text(
                  'Or grab the full SKILL.md (with prompt) directly:',
                  style: TextStyle(color: AppTheme.textM, fontSize: 12),
                ),
              ),
              TextButton.icon(
                onPressed: () => _downloadFullSkillMd(context),
                icon: const Icon(Icons.download_rounded,
                    size: 16, color: AppTheme.gold),
                label: const Text(
                  'Download SKILL.md',
                  style: TextStyle(color: AppTheme.gold, fontSize: 12),
                ),
                style: TextButton.styleFrom(
                  backgroundColor: AppTheme.gold.withValues(alpha: 0.10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(
                        color: AppTheme.gold.withValues(alpha: 0.4)),
                  ),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                ),
              ),
            ]),
          ],
        ],
      ),
    );
  }

  Future<void> _copyAndToast(
      BuildContext context, String text, String message) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    AppSnackBar.success(context, message);
  }

  Future<void> _downloadFullSkillMd(BuildContext context) async {
    final content = await ApiService.instance.fetchAgentSkillMd(agentId);
    if (!context.mounted) return;
    if (content == null) {
      AppSnackBar.error(context, 'Could not download SKILL.md — try again.');
      return;
    }
    final blob = web.Blob(
      [content.toJS].toJS,
      web.BlobPropertyBag(type: 'text/markdown'),
    );
    final url = web.URL.createObjectURL(blob);
    final anchor = web.document.createElement('a') as web.HTMLAnchorElement
      ..href = url
      ..download = '$slug-SKILL.md';
    anchor.click();
    web.URL.revokeObjectURL(url);
    if (context.mounted) {
      AppSnackBar.success(context, 'SKILL.md downloaded');
    }
  }

  void _openInBrowser(String url) {
    web.window.open(url, '_blank');
  }
}

// ─── Code-block tab body (cURL / Python / Node.js) ─────────────────────────

class _CodeBlock extends StatelessWidget {
  final String language;
  final String code;
  const _CodeBlock({required this.language, required this.code});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppTheme.border)),
            ),
            child: Row(children: [
              Text(
                language,
                style: const TextStyle(
                  color: AppTheme.gold,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _copy(context),
                icon:
                    const Icon(Icons.copy, size: 14, color: AppTheme.textM),
                label: const Text(
                  'Copy',
                  style: TextStyle(color: AppTheme.textM, fontSize: 11),
                ),
                style: TextButton.styleFrom(
                  minimumSize: Size.zero,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                ),
              ),
            ]),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: SelectableText(
                code,
                style: const TextStyle(
                  color: AppTheme.textB,
                  fontFamily: 'monospace',
                  fontSize: 11.5,
                  height: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (!context.mounted) return;
    AppSnackBar.success(context, 'Copied to clipboard');
  }
}

// ─── Section primitives (OpenClaw tab only) ────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String step;
  final String title;
  const _SectionLabel({required this.step, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        width: 22,
        height: 22,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppTheme.gold.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppTheme.gold.withValues(alpha: 0.4)),
        ),
        child: Text(
          step,
          style: const TextStyle(
            color: AppTheme.gold,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      const SizedBox(width: 10),
      Text(
        title,
        style: const TextStyle(
          color: AppTheme.textH,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    ]);
  }
}

class _DeeplinkRow extends StatelessWidget {
  final String deeplink;
  final VoidCallback onClipboard;
  const _DeeplinkRow({required this.deeplink, required this.onClipboard});

  /// Attached-anchor recipe — the detached version Chrome/Edge sometimes
  /// drops because the click is not treated as a user-activated navigation
  /// for custom protocols. Append → click → remove after a short delay.
  void _launchDeeplink() {
    final body = web.document.body;
    if (body == null) return;
    final anchor = web.document.createElement('a') as web.HTMLAnchorElement
      ..href = deeplink
      ..rel = 'noopener'
      ..style.display = 'none';
    body.appendChild(anchor);
    anchor.click();
    // dart2js disallows tear-offs of external extension type interop members,
    // so wrap the removal in a closure rather than passing `anchor.remove`
    // directly.
    Timer(const Duration(milliseconds: 200), () => anchor.remove());
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(children: [
        Expanded(
          child: SelectableText(
            deeplink,
            style: const TextStyle(
              color: AppTheme.textB,
              fontSize: 11.5,
              fontFamily: 'monospace',
            ),
            maxLines: 1,
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton.icon(
          onPressed: _launchDeeplink,
          icon: const Icon(Icons.launch, size: 14),
          label: const Text('Open', style: TextStyle(fontSize: 12)),
          style: ElevatedButton.styleFrom(
            backgroundColor: ExternalUseModal._openclawRed,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6)),
          ),
        ),
        const SizedBox(width: 6),
        IconButton(
          icon: const Icon(Icons.copy_rounded,
              size: 16, color: AppTheme.textM),
          onPressed: onClipboard,
          tooltip: 'Copy deeplink',
          visualDensity: VisualDensity.compact,
        ),
      ]),
    );
  }
}

class _CurlBlock extends StatelessWidget {
  final String command;
  final VoidCallback onClipboard;
  const _CurlBlock({required this.command, required this.onClipboard});

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(12, 12, 44, 12),
        decoration: BoxDecoration(
          color: AppTheme.bg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.border),
        ),
        child: SelectableText(
          command,
          style: const TextStyle(
            color: AppTheme.textB,
            fontSize: 11.5,
            fontFamily: 'monospace',
            height: 1.5,
          ),
        ),
      ),
      Positioned(
        top: 4,
        right: 4,
        child: IconButton(
          icon: const Icon(Icons.copy_rounded,
              size: 16, color: AppTheme.textM),
          onPressed: onClipboard,
          tooltip: 'Copy command',
          visualDensity: VisualDensity.compact,
        ),
      ),
    ]);
  }
}

class _PurchaseBanner extends StatelessWidget {
  const _PurchaseBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.gold.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.gold.withValues(alpha: 0.30)),
      ),
      child: const Row(children: [
        Icon(Icons.lock_outline, color: AppTheme.gold, size: 16),
        SizedBox(width: 10),
        Expanded(
          child: Text(
            'OpenClaw will install the skill metadata. Purchase the agent to '
            'unlock the full prompt.',
            style: TextStyle(
              color: AppTheme.textB,
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ),
      ]),
    );
  }
}

// ─── Footer (visible on every tab) ─────────────────────────────────────────

class _FooterCallouts extends StatelessWidget {
  const _FooterCallouts();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Auth note — relevant to cURL/Python/Node.js tabs (Bearer JWT).
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.lightbulb_outline,
                  size: 13, color: AppTheme.gold),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Authentication — JWT required for /chat. After connecting '
                  "your wallet, copy the Authorization header from your browser's "
                  'developer tools.',
                  style: TextStyle(
                    color: AppTheme.textM,
                    fontSize: 11,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, size: 13, color: AppTheme.gold),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'OpenClaw install — anonymous visitors get the redacted '
                  'SKILL.md (metadata only); owners/purchasers receive the '
                  'full prompt.',
                  style: TextStyle(
                    color: AppTheme.textM,
                    fontSize: 11,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
