// lib/features/settings/screens/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../app/theme.dart';
import '../../../shared/utils/app_snack_bar.dart';
import '../../../controllers/auth_controller.dart';
import '../../../shared/services/local_kv_store.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/page_header.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = AuthController.to;
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        children: [
          const PageHeader(
            icon: Icons.settings_rounded,
            title: 'Settings',
            subtitle: 'Customize your experience',
          ),
          const SizedBox(height: 28),

          // ── Profile ────────────────────────────────────────────────────
          const _SectionHeader(icon: Icons.person_outline, title: 'PROFILE'),
          const SizedBox(height: 8),
          _SettingsCard(children: [
            Obx(() => _InfoTile(
              icon: Icons.account_balance_wallet_outlined,
              title: 'Wallet',
              trailing: auth.isConnected.value
                  ? Row(mainAxisSize: MainAxisSize.min, children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: AppTheme.olive,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      SelectableText(
                        auth.shortWallet,
                        style: const TextStyle(
                          color: AppTheme.textB,
                          fontSize: 13,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ])
                  : const Text(
                      'Not connected',
                      style: TextStyle(color: AppTheme.textM, fontSize: 13),
                    ),
            )),
            const _TileDivider(),
            Obx(() => _InfoTile(
              icon: Icons.bolt_rounded,
              title: 'Credits',
              trailing: Text(
                '${auth.credits.value}',
                style: const TextStyle(
                  color: AppTheme.gold,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )),
            const _TileDivider(),
            Obx(() => _InfoTile(
              icon: Icons.person_outline,
              title: 'Username',
              trailing: Text(
                auth.username.value.isNotEmpty ? auth.username.value : 'Not set',
                style: TextStyle(
                  color: auth.username.value.isNotEmpty
                      ? AppTheme.textB
                      : AppTheme.textM,
                  fontSize: 13,
                ),
              ),
            )),
          ]),

          const SizedBox(height: 24),

          // ── Network ────────────────────────────────────────────────────
          const _SectionHeader(icon: Icons.lan_outlined, title: 'NETWORK'),
          const SizedBox(height: 8),
          _SettingsCard(children: [
            _InfoTile(
              icon: Icons.wifi_outlined,
              title: 'Network',
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: AppTheme.gold,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                const Text(
                  'Monad Testnet',
                  style: TextStyle(color: AppTheme.textB, fontSize: 13),
                ),
              ]),
            ),
            const _TileDivider(),
            const _InfoTile(
              icon: Icons.tag,
              title: 'Chain ID',
              trailing: Text(
                '10143',
                style: TextStyle(
                  color: AppTheme.textB,
                  fontSize: 13,
                  fontFamily: 'monospace',
                ),
              ),
            ),
            const _TileDivider(),
            const _InfoTile(
              icon: Icons.dns_outlined,
              title: 'RPC',
              trailing: SelectableText(
                'testnet-rpc.monad.xyz',
                style: TextStyle(
                  color: AppTheme.textM,
                  fontSize: 12,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ]),

          const SizedBox(height: 24),

          // ── Appearance ─────────────────────────────────────────────────
          const _SectionHeader(icon: Icons.palette_outlined, title: 'APPEARANCE'),
          const SizedBox(height: 8),
          const _SettingsCard(children: [
            _ToggleTile(
              icon: Icons.dark_mode_outlined,
              title: 'Dark Mode',
              subtitle: 'Always on',
              value: true,
              onChanged: null,
            ),
          ]),

          const SizedBox(height: 24),

          // ── Notifications ──────────────────────────────────────────────
          const _SectionHeader(icon: Icons.notifications_outlined, title: 'NOTIFICATIONS'),
          const SizedBox(height: 8),
          const _NotificationToggles(),

          const SizedBox(height: 24),

          // ── Privacy ───────────────────────────────────────────────────
          // Sprint v3.7-14.1 stub: profile visibility skeleton. Full
          // permission matrix lands in v3.11-14.2.
          const _SectionHeader(icon: Icons.lock_outline, title: 'PRIVACY'),
          const SizedBox(height: 8),
          const _SettingsCard(children: [
            _ToggleTile(
              icon: Icons.visibility_outlined,
              title: 'Public Profile',
              subtitle: 'Coming soon — others can find you by username',
              value: true,
              onChanged: null,
            ),
          ]),

          const SizedBox(height: 24),

          // ── Developer ─────────────────────────────────────────────────
          // Sprint v3.7-14.1 stub: developer surface placeholder. API
          // tokens + dev mode toggles land in v3.11.
          const _SectionHeader(icon: Icons.code_rounded, title: 'DEVELOPER'),
          const SizedBox(height: 8),
          const _SettingsCard(children: [
            _InfoTile(
              icon: Icons.api_rounded,
              title: 'API Tokens',
              trailing: Text(
                'Coming soon',
                style: TextStyle(color: AppTheme.textM, fontSize: 13),
              ),
            ),
          ]),

          const SizedBox(height: 24),

          // ── About ──────────────────────────────────────────────────────
          const _SectionHeader(icon: Icons.info_outline, title: 'ABOUT'),
          const SizedBox(height: 8),
          const _SettingsCard(children: [
            _InfoTile(
              icon: Icons.apps_rounded,
              title: 'App Name',
              trailing: Text(
                'Agent Store',
                style: TextStyle(color: AppTheme.textB, fontSize: 13),
              ),
            ),
            _TileDivider(),
            _InfoTile(
              icon: Icons.new_releases_outlined,
              title: 'Version',
              trailing: Text(
                '1.0.0',
                style: TextStyle(color: AppTheme.textB, fontSize: 13),
              ),
            ),
            _TileDivider(),
            _InfoTile(
              icon: Icons.code_rounded,
              title: 'Stack',
              trailing: Text(
                'Flutter + Go',
                style: TextStyle(color: AppTheme.textB, fontSize: 13),
              ),
            ),
            _TileDivider(),
            _InfoTile(
              icon: Icons.auto_awesome_rounded,
              title: 'AI Engine',
              trailing: Text(
                'Claude + Gemini',
                style: TextStyle(color: AppTheme.textB, fontSize: 13),
              ),
            ),
          ]),

          const SizedBox(height: 24),

          // ── Danger Zone ────────────────────────────────────────────────
          const _SectionHeader(
            icon: Icons.warning_amber_rounded,
            title: 'DANGER ZONE',
            color: AppTheme.primary,
          ),
          const SizedBox(height: 8),
          _DangerCard(
            onClear: () => _clearAllData(context),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Future<void> _clearAllData(BuildContext context) async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Clear All Data',
      message: 'This will clear all locally stored preferences and cached data. '
          'Your on-chain data will not be affected.',
      confirmLabel: 'Clear Data',
      isDestructive: true,
      icon: Icons.warning_amber_rounded,
    );

    if (!confirmed) return;
    if (!context.mounted) return;

    await LocalKvStore.instance.clear();
    // Disconnect auth to keep UI in sync after clearing local data
    AuthController.to.disconnect();

    if (!context.mounted) return;
    AppSnackBar.success(context, 'All local data cleared');
  }
}

// ── Notification toggles with LocalKvStore persistence ──────────────────────

class _NotificationToggles extends StatefulWidget {
  const _NotificationToggles();

  @override
  State<_NotificationToggles> createState() => _NotificationTogglesState();
}

class _NotificationTogglesState extends State<_NotificationToggles> {
  static const _kCreditAlerts = 'settings.credit_alerts';
  static const _kAgentUpdates = 'settings.agent_updates';

  bool _creditAlerts = true;
  bool _agentUpdates = true;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final kv = LocalKvStore.instance;
    final ca = await kv.getString(_kCreditAlerts);
    final au = await kv.getString(_kAgentUpdates);
    if (!mounted) return;
    setState(() {
      _creditAlerts = ca != 'false';
      _agentUpdates = au != 'false';
    });
  }

  Future<void> _setCreditAlerts(bool v) async {
    setState(() => _creditAlerts = v);
    await LocalKvStore.instance.setString(_kCreditAlerts, v.toString());
  }

  Future<void> _setAgentUpdates(bool v) async {
    setState(() => _agentUpdates = v);
    await LocalKvStore.instance.setString(_kAgentUpdates, v.toString());
  }

  @override
  Widget build(BuildContext context) {
    return _SettingsCard(children: [
      _ToggleTile(
        icon: Icons.credit_card_outlined,
        title: 'Credit Alerts',
        subtitle: 'Show notification when credits change',
        value: _creditAlerts,
        onChanged: _setCreditAlerts,
      ),
      const _TileDivider(),
      _ToggleTile(
        icon: Icons.auto_awesome_outlined,
        title: 'Agent Updates',
        subtitle: 'Notify when saved agents are updated',
        value: _agentUpdates,
        onChanged: _setAgentUpdates,
      ),
    ]);
  }
}

// ── Section Header ──────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  const _SectionHeader({
    required this.icon,
    required this.title,
    this.color = AppTheme.textM,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Row(children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Text(
          title,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
      ]),
    );
  }
}

// ── Settings Card ───────────────────────────────────────────────────────────

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(children: children),
    );
  }
}

// ── Tile divider ────────────────────────────────────────────────────────────

class _TileDivider extends StatelessWidget {
  const _TileDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(
      color: AppTheme.border,
      height: 1,
      indent: 48,
    );
  }
}

// ── Info tile ───────────────────────────────────────────────────────────────

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget trailing;
  const _InfoTile({
    required this.icon,
    required this.title,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(children: [
        Icon(icon, color: AppTheme.textM, size: 18),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(color: AppTheme.textH, fontSize: 14),
        ),
        const Spacer(),
        trailing,
      ]),
    );
  }
}

// ── Toggle tile ─────────────────────────────────────────────────────────────

class _ToggleTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  const _ToggleTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(children: [
        Icon(icon, color: AppTheme.textM, size: 18),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(color: AppTheme.textH, fontSize: 14),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(color: AppTheme.textM, fontSize: 11),
              ),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: AppTheme.primary,
          inactiveThumbColor: AppTheme.textM,
          inactiveTrackColor: AppTheme.card2,
        ),
      ]),
    );
  }
}

// ── Danger card ─────────────────────────────────────────────────────────────

class _DangerCard extends StatefulWidget {
  final VoidCallback onClear;
  const _DangerCard({required this.onClear});

  @override
  State<_DangerCard> createState() => _DangerCardState();
}

class _DangerCardState extends State<_DangerCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onClear,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: _hovered
                ? AppTheme.primary.withValues(alpha: 0.08)
                : AppTheme.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _hovered
                  ? AppTheme.primary.withValues(alpha: 0.4)
                  : AppTheme.primary.withValues(alpha: 0.2),
            ),
          ),
          child: Row(children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.delete_outline_rounded, color: AppTheme.primary, size: 18),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Clear All Data',
                    style: TextStyle(
                      color: AppTheme.primary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Clear local preferences and cache. On-chain data is unaffected.',
                    style: TextStyle(color: AppTheme.textM, fontSize: 11),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppTheme.primary,
              size: 20,
            ),
          ]),
        ),
      ),
    );
  }
}
