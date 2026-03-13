// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme.dart';
import '../../../controllers/auth_controller.dart';
import '../../../shared/services/api_service.dart';

class WalletConnectScreen extends StatelessWidget {
  const WalletConnectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = AuthController.to;
    return Obx(() => Scaffold(
      backgroundColor: AppTheme.bg,
      body: Center(child: SingleChildScrollView(child: Container(
        width: 480,
        padding: const EdgeInsets.all(36),
        margin: const EdgeInsets.symmetric(vertical: 32),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.border2),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 40, spreadRadius: 4),
            BoxShadow(color: AppTheme.primary.withValues(alpha: 0.06), blurRadius: 60, spreadRadius: 8),
          ],
        ),
        child: ctrl.isConnected.value ? _ConnectedView(ctrl: ctrl) : _ConnectView(ctrl: ctrl),
      ))),
    ));
  }
}

// ── Not connected view ────────────────────────────────────────────────────────

class _ConnectView extends StatelessWidget {
  final AuthController ctrl;
  const _ConnectView({required this.ctrl});

  @override
  Widget build(BuildContext context) => Column(mainAxisSize: MainAxisSize.min, children: [
    _iconCircle(Icons.account_balance_wallet_outlined, AppTheme.primary),
    const SizedBox(height: 22),
    ShaderMask(
      shaderCallback: (b) => const LinearGradient(colors: [AppTheme.textH, AppTheme.gold]).createShader(b),
      child: const Text('Connect Wallet',
        style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
    ),
    const SizedBox(height: 8),
    const Text('Connect your MetaMask wallet to browse and create agents.',
      style: TextStyle(color: AppTheme.textM, height: 1.5), textAlign: TextAlign.center),
    const SizedBox(height: 16),
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(color: AppTheme.card, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppTheme.border2)),
      child: const Row(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(width: 8, height: 8, child: DecoratedBox(decoration: BoxDecoration(color: AppTheme.gold, shape: BoxShape.circle))),
        SizedBox(width: 8),
        Text('Monad Testnet · ChainID 10143', style: TextStyle(color: AppTheme.gold, fontSize: 11, fontWeight: FontWeight.w600)),
      ]),
    ),
    const SizedBox(height: 20),
    Container(
      width: double.infinity, padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppTheme.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('New users start with 100 free credits', style: TextStyle(color: AppTheme.textM, fontSize: 12)),
        const SizedBox(height: 10),
        _costRow(Icons.add_box_outlined, 'Create Agent', 10, AppTheme.primary),
        const SizedBox(height: 6),
        _costRow(Icons.fork_right, 'Fork Agent', 5, AppTheme.primary),
      ]),
    ),
    const SizedBox(height: 24),
    Obx(() {
      if (ctrl.error.value != null) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Container(
            width: double.infinity, padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.primary.withValues(alpha: 0.4))),
            child: Text(ctrl.error.value!, style: const TextStyle(color: AppTheme.textB, fontSize: 12)),
          ),
        );
      }
      return const SizedBox.shrink();
    }),
    Obx(() => SizedBox(
      width: double.infinity, height: 48,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [AppTheme.primary, Color(0xFF8B1A11)], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: AppTheme.primary.withValues(alpha: 0.35), blurRadius: 16, offset: const Offset(0, 4))],
        ),
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          onPressed: ctrl.isConnecting.value ? null : ctrl.connect,
          icon: ctrl.isConnecting.value
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.account_balance_wallet_rounded, size: 18),
          label: Text(ctrl.isConnecting.value ? 'Connecting...' : 'Connect MetaMask',
            style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5)),
        ),
      ),
    )),
  ]);
}

// ── Connected view ────────────────────────────────────────────────────────────

class _ConnectedView extends StatelessWidget {
  final AuthController ctrl;
  const _ConnectedView({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isLow = ctrl.credits.value < 20;
      return Column(mainAxisSize: MainAxisSize.min, children: [
        _iconCircle(Icons.check_circle_outline, AppTheme.olive),
        const SizedBox(height: 16),
        const Text('Connected', style: TextStyle(color: AppTheme.textH, fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppTheme.olive, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(ctrl.shortWallet, style: const TextStyle(color: AppTheme.textM, fontSize: 13, fontFamily: 'monospace')),
        ]),
        const SizedBox(height: 24),
        // Credits card
        Container(
          width: double.infinity, padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isLow ? [const Color(0xFF5A1008), AppTheme.card2] : [const Color(0xFF3A2D10), AppTheme.card2],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: isLow ? AppTheme.primary.withValues(alpha: 0.5) : AppTheme.gold.withValues(alpha: 0.3)),
          ),
          child: Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('CREDITS BALANCE', style: TextStyle(color: AppTheme.textM, fontSize: 11, letterSpacing: 1.5)),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                icon: ctrl.isLoadingCredits.value
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.gold))
                    : const Icon(Icons.refresh_rounded, color: AppTheme.textM, size: 18),
                onPressed: ctrl.isLoadingCredits.value ? null : ctrl.loadCredits,
              ),
            ]),
            const SizedBox(height: 6),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.bolt_rounded, color: AppTheme.gold, size: 36),
              const SizedBox(width: 8),
              Text('${ctrl.credits.value}', style: const TextStyle(color: AppTheme.textH, fontSize: 48, fontWeight: FontWeight.bold, letterSpacing: -2)),
            ]),
            if (isLow) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.warning_amber_rounded, color: AppTheme.primary, size: 14),
                  SizedBox(width: 5),
                  Text('Low credits — some actions may be unavailable', style: TextStyle(color: AppTheme.textB, fontSize: 11)),
                ]),
              ),
            ],
          ]),
        ),
        const SizedBox(height: 16),
        // Profile card
        Container(
          width: double.infinity, padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: AppTheme.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.border)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Text('Profile', style: TextStyle(color: AppTheme.textH, fontSize: 14, fontWeight: FontWeight.bold)),
              const Spacer(),
              GestureDetector(
                onTap: () => _showEditProfileDialog(context, ctrl),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6), border: Border.all(color: AppTheme.primary.withValues(alpha: 0.4))),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.edit_outlined, color: AppTheme.primary, size: 13),
                    SizedBox(width: 4),
                    Text('Edit', style: TextStyle(color: AppTheme.primary, fontSize: 11, fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),
            ]),
            const SizedBox(height: 10),
            if (ctrl.username.value.isNotEmpty) ...[
              Row(children: [
                const Icon(Icons.person_outline, color: AppTheme.textM, size: 14),
                const SizedBox(width: 6),
                Text(ctrl.username.value, style: const TextStyle(color: AppTheme.textH, fontSize: 13)),
              ]),
              const SizedBox(height: 6),
            ],
            ctrl.bio.value.isNotEmpty
                ? Text(ctrl.bio.value, style: const TextStyle(color: AppTheme.textM, fontSize: 12, height: 1.4), maxLines: 2, overflow: TextOverflow.ellipsis)
                : const Text('No bio set.', style: TextStyle(color: AppTheme.textM, fontSize: 12)),
          ]),
        ),
        const SizedBox(height: 16),
        // Credit costs
        Container(
          width: double.infinity, padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: AppTheme.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.border)),
          child: Column(children: [
            const Align(alignment: Alignment.centerLeft, child: Text('Credit Costs', style: TextStyle(color: AppTheme.textM, fontSize: 12, fontWeight: FontWeight.w600))),
            const SizedBox(height: 10),
            _costRow(Icons.add_box_outlined, 'Create Agent', 10, AppTheme.primary),
            const SizedBox(height: 6),
            _costRow(Icons.fork_right, 'Fork Agent', 5, AppTheme.primary),
          ]),
        ),
        const SizedBox(height: 14),
        // Buy credits
        Container(
          margin: const EdgeInsets.symmetric(vertical: 4), padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: AppTheme.card2, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.gold.withValues(alpha: 0.3))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Row(children: [
              Icon(Icons.add_card_rounded, color: AppTheme.gold, size: 16),
              SizedBox(width: 8),
              Text('Buy Credits', style: TextStyle(color: AppTheme.textH, fontSize: 14, fontWeight: FontWeight.bold)),
            ]),
            const SizedBox(height: 4),
            const Text('1 MON = 100 credits', style: TextStyle(color: AppTheme.textM, fontSize: 12)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: [0.1, 0.5, 1.0, 5.0].map((amt) => OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.gold, side: const BorderSide(color: AppTheme.gold),
                  backgroundColor: AppTheme.gold.withValues(alpha: 0.08),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: ctrl.isBuyingCredits.value ? null : () => ctrl.topUp(amt),
                child: ctrl.isBuyingCredits.value
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.gold))
                    : Text('$amt MON\n${(amt * 100).toInt()} cr', textAlign: TextAlign.center, style: const TextStyle(fontSize: 11)),
              )).toList(),
            ),
          ]),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => context.go('/credits/history'),
            icon: const Icon(Icons.history_rounded, size: 16),
            label: const Text('View Credit History'),
            style: OutlinedButton.styleFrom(foregroundColor: AppTheme.textB, side: const BorderSide(color: AppTheme.border2), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: ctrl.disconnect,
            style: OutlinedButton.styleFrom(foregroundColor: AppTheme.primary, side: const BorderSide(color: AppTheme.primary), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: const Text('Disconnect'),
          ),
        ),
      ]);
    });
  }

  void _showEditProfileDialog(BuildContext context, AuthController ctrl) {
    final usernameCtrl = TextEditingController(text: ctrl.username.value);
    final bioCtrl = TextEditingController(text: ctrl.bio.value);
    showDialog<void>(
      context: context,
      builder: (_) => _EditProfileDialog(usernameCtrl: usernameCtrl, bioCtrl: bioCtrl, onSave: ctrl.updateProfile),
    );
  }
}

// ── Shared helpers ────────────────────────────────────────────────────────────

Widget _costRow(IconData icon, String label, int cost, Color color) => Row(children: [
  Icon(icon, size: 15, color: color), const SizedBox(width: 8),
  Expanded(child: Text(label, style: const TextStyle(color: AppTheme.textB, fontSize: 12))),
  Row(children: [
    const Icon(Icons.bolt_rounded, color: AppTheme.gold, size: 13), const SizedBox(width: 2),
    Text('$cost', style: const TextStyle(color: AppTheme.gold, fontSize: 12, fontWeight: FontWeight.bold)),
  ]),
]);

Widget _iconCircle(IconData icon, Color color) => Container(
  width: 68, height: 68,
  decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle, border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5)),
  child: Icon(icon, color: color, size: 32),
);

// ── Edit profile dialog ───────────────────────────────────────────────────────

class _EditProfileDialog extends StatefulWidget {
  final TextEditingController usernameCtrl;
  final TextEditingController bioCtrl;
  final Future<bool> Function(String, String) onSave;
  const _EditProfileDialog({required this.usernameCtrl, required this.bioCtrl, required this.onSave});

  @override
  State<_EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<_EditProfileDialog> {
  bool _saving = false;

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: AppTheme.surface, surfaceTintColor: Colors.transparent,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: AppTheme.border2)),
    title: const Text('Edit Profile', style: TextStyle(color: AppTheme.textH)),
    content: Column(mainAxisSize: MainAxisSize.min, children: [
      TextField(controller: widget.usernameCtrl, style: const TextStyle(color: AppTheme.textH), decoration: const InputDecoration(labelText: 'Username')),
      const SizedBox(height: 12),
      TextField(controller: widget.bioCtrl, style: const TextStyle(color: AppTheme.textH), maxLines: 3, decoration: const InputDecoration(labelText: 'Bio')),
    ]),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
      FilledButton(
        style: FilledButton.styleFrom(backgroundColor: AppTheme.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
        onPressed: _saving ? null : () async {
          setState(() => _saving = true);
          final ok = await widget.onSave(widget.usernameCtrl.text.trim(), widget.bioCtrl.text.trim());
          if (context.mounted) {
            Navigator.pop(context);
            if (ok) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Profile updated!'), backgroundColor: AppTheme.olive, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));
          }
        },
        child: _saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Save'),
      ),
    ],
  );
}

// ── Compatibility shim — screens that check ApiService.isAuthenticated ──────
// Keep this so other screens that import wallet_connect_screen.dart still compile
extension WalletScreenCompat on WalletConnectScreen {
  static bool get isAuthenticated => ApiService.instance.isAuthenticated;
}
