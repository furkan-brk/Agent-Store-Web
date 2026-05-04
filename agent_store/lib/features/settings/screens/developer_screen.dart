// lib/features/settings/screens/developer_screen.dart
//
// Settings → Developer: API key management. Create modal shows the
// plaintext key ONCE (warning + clipboard). The list view is masked
// using the prefix from the server.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../app/theme.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../../shared/services/api_service.dart';
import '../../../shared/utils/app_snack_bar.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/page_header.dart';
import '../widgets/settings_sidebar.dart';

class DeveloperScreen extends StatefulWidget {
  const DeveloperScreen({super.key});

  @override
  State<DeveloperScreen> createState() => _DeveloperScreenState();
}

class _DeveloperScreenState extends State<DeveloperScreen> {
  final _keys = <Map<String, dynamic>>[].obs;
  final _isLoading = true.obs;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _isLoading.value = true;
    final keys = await ApiService.instance.listApiKeys();
    _keys.value = keys;
    _isLoading.value = false;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return SettingsLayout(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeader(
            icon: Icons.code_rounded,
            title: l.developerSection,
            subtitle: l.settingsSubtitle,
            trailing: _CreateButton(
              label: l.createApiKey,
              onTap: () => _openCreateDialog(context),
            ),
          ),
          const SizedBox(height: 24),

          Obx(() {
            if (_isLoading.value) {
              return Container(
                height: 160,
                decoration: BoxDecoration(
                  color: AppTheme.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.border),
                ),
                child: const Center(
                  child: CircularProgressIndicator(
                    color: AppTheme.gold,
                    strokeWidth: 2,
                  ),
                ),
              );
            }
            if (_keys.isEmpty) {
              return Container(
                padding: const EdgeInsets.symmetric(vertical: 40),
                decoration: BoxDecoration(
                  color: AppTheme.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.border),
                ),
                child: EmptyState(
                  icon: Icons.vpn_key_outlined,
                  title: l.noApiKeys,
                  subtitle: l.noApiKeysSubtitle,
                  actionLabel: l.createApiKey,
                  actionIcon: Icons.add_rounded,
                  onAction: () => _openCreateDialog(context),
                ),
              );
            }
            return Container(
              decoration: BoxDecoration(
                color: AppTheme.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.border),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _keys.length,
                separatorBuilder: (_, __) => const Divider(
                  height: 1,
                  color: AppTheme.border,
                  indent: 16,
                ),
                itemBuilder: (_, i) => _ApiKeyRow(
                  data: _keys[i],
                  onRevoked: _load,
                ),
              ),
            );
          }),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Future<void> _openCreateDialog(BuildContext context) async {
    final created = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _CreateApiKeyDialog(),
    );
    if (created == true) await _load();
  }
}

// ─── Create button ─────────────────────────────────────────────────────────

class _CreateButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  const _CreateButton({required this.label, required this.onTap});

  @override
  State<_CreateButton> createState() => _CreateButtonState();
}

class _CreateButtonState extends State<_CreateButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: _hovered
                ? AppTheme.primary
                : AppTheme.primary.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.add_rounded, color: Colors.white, size: 16),
            const SizedBox(width: 6),
            Text(
              widget.label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ─── API key list row ──────────────────────────────────────────────────────

class _ApiKeyRow extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onRevoked;

  const _ApiKeyRow({required this.data, required this.onRevoked});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final id = (data['id'] as num?)?.toInt() ?? 0;
    final name = (data['name'] as String?) ?? '(unnamed)';
    final prefix = (data['prefix'] as String?) ?? 'agst_';
    final scopes =
        ((data['scopes'] as List?) ?? const []).whereType<String>().toList();
    final lastUsed = data['last_used_at'] as String?;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(children: [
        // Masked prefix + name + scopes
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Icon(Icons.vpn_key_outlined, color: AppTheme.gold, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(
                      color: AppTheme.textH,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 4),
              SelectableText(
                '$prefix${'•' * 24}',
                style: const TextStyle(
                  color: AppTheme.textM,
                  fontSize: 11,
                  fontFamily: 'monospace',
                ),
              ),
              if (scopes.isNotEmpty) ...[
                const SizedBox(height: 6),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: scopes.map((s) => _ScopeChip(scope: s)).toList(),
                ),
              ],
              const SizedBox(height: 4),
              Text(
                lastUsed == null || lastUsed.isEmpty
                    ? l.neverUsed
                    : '${l.lastUsed}: ${_relative(lastUsed)}',
                style: const TextStyle(color: AppTheme.textM, fontSize: 11),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: l.revoke,
          icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.error),
          onPressed: () => _confirmRevoke(context, id),
        ),
      ]),
    );
  }

  Future<void> _confirmRevoke(BuildContext context, int id) async {
    final l = AppLocalizations.of(context);
    final confirmed = await ConfirmDialog.show(
      context,
      title: l.revokeApiKeyTitle,
      message: l.revokeApiKeyMessage,
      confirmLabel: l.revoke,
      isDestructive: true,
      icon: Icons.warning_amber_rounded,
    );
    if (!confirmed || !context.mounted) return;
    final ok = await ApiService.instance.revokeApiKey(id);
    if (!context.mounted) return;
    if (ok) {
      AppSnackBar.success(context, 'API key revoked');
      onRevoked();
    } else {
      AppSnackBar.error(context, 'Could not revoke key.');
    }
  }

  String _relative(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      final delta = DateTime.now().difference(dt);
      if (delta.inMinutes < 60) return '${delta.inMinutes}m ago';
      if (delta.inHours < 24) return '${delta.inHours}h ago';
      if (delta.inDays < 30) return '${delta.inDays}d ago';
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }
}

class _ScopeChip extends StatelessWidget {
  final String scope;
  const _ScopeChip({required this.scope});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.card2,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppTheme.border),
      ),
      child: Text(
        scope,
        style: const TextStyle(
          color: AppTheme.textB,
          fontSize: 10,
          fontFamily: 'monospace',
        ),
      ),
    );
  }
}

// ─── Create dialog ─────────────────────────────────────────────────────────

class _CreateApiKeyDialog extends StatefulWidget {
  const _CreateApiKeyDialog();

  @override
  State<_CreateApiKeyDialog> createState() => _CreateApiKeyDialogState();
}

class _CreateApiKeyDialogState extends State<_CreateApiKeyDialog> {
  static const _allScopes = [
    'read:agents',
    'write:agents',
    'execute:legend',
  ];

  final _nameCtrl = TextEditingController();
  final _selected = <String>{'read:agents'};
  bool _submitting = false;
  Map<String, dynamic>? _created;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final created = _created;
    return AlertDialog(
      backgroundColor: AppTheme.surface,
      title: Text(
        created == null ? l.createApiKey : 'API Key Created',
        style: const TextStyle(color: AppTheme.textH),
      ),
      content: SizedBox(
        width: 420,
        child: created == null
            ? _buildForm(context, l)
            : _buildResult(context, l, created),
      ),
      actions: created == null
          ? [
              TextButton(
                onPressed: _submitting
                    ? null
                    : () => Navigator.of(context).pop(false),
                child: const Text('Cancel',
                    style: TextStyle(color: AppTheme.textM)),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                ),
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(l.createApiKey),
              ),
            ]
          : [
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.gold,
                  foregroundColor: const Color(0xFF1E1A14),
                ),
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(l.done),
              ),
            ],
    );
  }

  Widget _buildForm(BuildContext context, AppLocalizations l) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _nameCtrl,
          autofocus: true,
          decoration: InputDecoration(
            labelText: l.name,
            hintText: 'CLI laptop',
          ),
        ),
        const SizedBox(height: 16),
        Text(
          l.scopes,
          style: const TextStyle(
            color: AppTheme.textM,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 4),
        ..._allScopes.map((s) {
          final selected = _selected.contains(s);
          return CheckboxListTile(
            value: selected,
            activeColor: AppTheme.primary,
            title: Text(_scopeLabel(l, s)),
            subtitle: Text(
              s,
              style: const TextStyle(
                color: AppTheme.textM,
                fontFamily: 'monospace',
                fontSize: 11,
              ),
            ),
            controlAffinity: ListTileControlAffinity.leading,
            onChanged: (v) {
              setState(() {
                if (v == true) {
                  _selected.add(s);
                } else {
                  _selected.remove(s);
                }
              });
            },
          );
        }),
      ],
    );
  }

  String _scopeLabel(AppLocalizations l, String scope) {
    switch (scope) {
      case 'read:agents':
        return l.scopeReadAgents;
      case 'write:agents':
        return l.scopeWriteAgents;
      case 'execute:legend':
        return l.scopeExecuteLegend;
    }
    return scope;
  }

  Widget _buildResult(
    BuildContext context,
    AppLocalizations l,
    Map<String, dynamic> created,
  ) {
    final key = (created['key'] as String?) ?? '';
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.warning.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.warning.withValues(alpha: 0.4)),
          ),
          child: Row(children: [
            const Icon(Icons.warning_amber_rounded,
                color: AppTheme.warning, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                l.saveKeyWarning,
                style: const TextStyle(
                    color: AppTheme.textH, fontSize: 12, fontWeight: FontWeight.w500),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.border),
          ),
          child: SelectableText(
            key,
            style: const TextStyle(
              color: AppTheme.textH,
              fontFamily: 'monospace',
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: key));
              if (!context.mounted) return;
              AppSnackBar.success(context, 'Copied to clipboard');
            },
            icon: const Icon(Icons.copy_rounded, size: 16),
            label: Text(l.copy),
            style: TextButton.styleFrom(foregroundColor: AppTheme.gold),
          ),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      AppSnackBar.error(context, 'Please give the key a name.');
      return;
    }
    if (_selected.isEmpty) {
      AppSnackBar.error(context, 'Pick at least one scope.');
      return;
    }
    setState(() => _submitting = true);
    final result = await ApiService.instance.createApiKey(
      name,
      _selected.toList(),
    );
    if (!mounted) return;
    setState(() {
      _submitting = false;
      _created = result;
    });
    if (result == null) {
      AppSnackBar.error(context, 'Could not create key.');
    }
  }
}
