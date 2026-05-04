// lib/features/agent_detail/widgets/openclaw_install_modal.dart
//
// "Install in OpenClaw" UX surface — replaces the legacy single-action
// "Download SKILL.md" button on the Agent Detail screen.
//
// Two flows are supported in one dialog:
//
//   1. **Deeplink flow** (works for everyone, no purchase required):
//      `openclaw://install-skill?url=<encoded SKILL.md URL>`. The OpenClaw
//      desktop client receives the URL and fetches the *redacted* SKILL.md
//      that the public endpoint serves to anonymous callers — that is enough
//      metadata for skill discovery + a "purchase to unlock" notice. Once
//      the user owns the agent, OpenClaw can re-fetch with a JWT to pull
//      the full prompt.
//
//   2. **Manual install** (curl one-liner): for power users who want to
//      drop the SKILL.md into `~/.openclaw/workspace/skills/<slug>/` by
//      hand. Same redaction rules apply if the user is unauthenticated.
//
//   3. **Download Full SKILL.md** (only when [hasAccess] is true): the
//      historical owner/purchaser flow, kept as a tertiary action so the
//      modal is the single OpenClaw entry-point regardless of access state.

import 'dart:js_interop';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:web/web.dart' as web;

import '../../../app/theme.dart';
import '../../../core/constants/api_constants.dart';
import '../../../shared/services/api_service.dart';
import '../../../shared/utils/app_snack_bar.dart';

class OpenClawInstallModal extends StatelessWidget {
  /// Agent ID for the deeplink + curl URL.
  final int agentId;

  /// Title used to derive the slug shown in the curl one-liner.
  final String agentTitle;

  /// Owner OR purchaser? Controls whether the "Download Full SKILL.md" CTA
  /// is offered. The deeplink + curl flows are *always* available — they
  /// hit the public endpoint that serves a redacted SKILL.md.
  final bool hasAccess;

  /// Optional override so callers don't re-derive the slug; defaults to
  /// the same lower-kebab logic the backend uses.
  final String? slugOverride;

  const OpenClawInstallModal({
    super.key,
    required this.agentId,
    required this.agentTitle,
    required this.hasAccess,
    this.slugOverride,
  });

  String get _slug =>
      slugOverride ??
      agentTitle
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
          .replaceAll(RegExp(r'-+$'), '');

  /// Public, browser-reachable SKILL.md URL — same as what OpenClaw will fetch.
  String get _skillMdUrl => '${ApiConstants.agents}/$agentId/skill.md';

  /// `openclaw://install-skill?url=<encoded SKILL.md URL>` deeplink.
  String get _deeplink {
    final encoded = Uri.encodeComponent(_skillMdUrl);
    return 'openclaw://install-skill?url=$encoded';
  }

  /// Multi-line curl command for manual install.
  String get _curlCommand =>
      'mkdir -p ~/.openclaw/workspace/skills/$_slug && \\\n'
      '  curl -fsSL -o ~/.openclaw/workspace/skills/$_slug/SKILL.md \\\n'
      '  $_skillMdUrl';

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppTheme.border2),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.extension_outlined,
                      color: Color(0xFFEF4444), size: 22),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text('Install in OpenClaw',
                      style: TextStyle(
                          color: AppTheme.textH,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: AppTheme.textM, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: 'Close',
                ),
              ]),
              const SizedBox(height: 6),
              if (!hasAccess)
                _PurchaseHintBanner(),
              const SizedBox(height: 14),

              // Section 1: Deeplink
              const _SectionLabel(
                step: '1',
                title: 'Open in OpenClaw (one click)',
              ),
              const SizedBox(height: 8),
              _DeeplinkRow(
                deeplink: _deeplink,
                onClipboard: () => _copyAndToast(context, _deeplink,
                    'Deeplink copied — paste into OpenClaw'),
              ),
              const SizedBox(height: 18),

              // Section 2: Manual curl install
              const _SectionLabel(
                step: '2',
                title: 'Manual install (curl)',
              ),
              const SizedBox(height: 8),
              _CurlBlock(
                command: _curlCommand,
                onClipboard: () => _copyAndToast(
                    context, _curlCommand, 'Command copied'),
              ),
              const SizedBox(height: 18),

              // Section 3: Download full (owner/purchaser only)
              if (hasAccess) ...[
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
                    label: const Text('Download SKILL.md',
                        style: TextStyle(color: AppTheme.gold, fontSize: 12)),
                    style: TextButton.styleFrom(
                      backgroundColor: AppTheme.gold.withValues(alpha: 0.08),
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
                const SizedBox(height: 6),
              ],

              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () =>
                      _openInBrowser('https://openclaw.ai'),
                  icon: const Icon(Icons.help_outline,
                      size: 14, color: AppTheme.textM),
                  label: const Text('What is OpenClaw?',
                      style: TextStyle(color: AppTheme.textM, fontSize: 11)),
                ),
              ),
            ],
          ),
        ),
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
      AppSnackBar.error(
          context, 'Could not download SKILL.md — try again.');
      return;
    }
    final blob = web.Blob(
      [content.toJS].toJS,
      web.BlobPropertyBag(type: 'text/markdown'),
    );
    final url = web.URL.createObjectURL(blob);
    final anchor = web.document.createElement('a') as web.HTMLAnchorElement;
    anchor.href = url;
    anchor.download = '$_slug-SKILL.md';
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

// ─── Section primitives ─────────────────────────────────────────────────────

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
        child: Text(step,
            style: const TextStyle(
                color: AppTheme.gold,
                fontSize: 12,
                fontWeight: FontWeight.bold)),
      ),
      const SizedBox(width: 10),
      Text(title,
          style: const TextStyle(
              color: AppTheme.textH,
              fontSize: 13,
              fontWeight: FontWeight.w600)),
    ]);
  }
}

class _DeeplinkRow extends StatelessWidget {
  final String deeplink;
  final VoidCallback onClipboard;
  const _DeeplinkRow({required this.deeplink, required this.onClipboard});

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
                fontFamily: 'monospace'),
            maxLines: 1,
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton.icon(
          onPressed: () {
            // Navigating to a custom protocol from JS often requires an
            // anchor element rather than location.href to avoid Firefox's
            // "external app" prompt being suppressed.
            final anchor =
                web.document.createElement('a') as web.HTMLAnchorElement;
            anchor.href = deeplink;
            anchor.click();
          },
          icon: const Icon(Icons.launch, size: 14),
          label: const Text('Open', style: TextStyle(fontSize: 12)),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFEF4444),
            foregroundColor: Colors.white,
            elevation: 0,
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
              height: 1.5),
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

class _PurchaseHintBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
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
            'OpenClaw will install the skill metadata. Purchase the agent '
            'to unlock the full prompt.',
            style: TextStyle(color: AppTheme.textB, fontSize: 12, height: 1.4),
          ),
        ),
      ]),
    );
  }
}
