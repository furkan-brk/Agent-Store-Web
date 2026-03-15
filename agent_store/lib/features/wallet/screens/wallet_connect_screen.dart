// lib/features/wallet/screens/wallet_connect_screen.dart
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

// ── Not connected view ──────────────────────────────────────────────────────

class _ConnectView extends StatelessWidget {
  final AuthController ctrl;
  const _ConnectView({required this.ctrl});

  @override
  Widget build(BuildContext context) => Column(mainAxisSize: MainAxisSize.min, children: [
    // MetaMask fox icon
    Container(
      width: 76,
      height: 76,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFF6851B).withValues(alpha: 0.15),
            const Color(0xFFE2761B).withValues(alpha: 0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
        border: Border.all(
          color: const Color(0xFFF6851B).withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: const Icon(Icons.account_balance_wallet_rounded, color: Color(0xFFF6851B), size: 36),
    ),
    const SizedBox(height: 22),
    ShaderMask(
      shaderCallback: (b) => const LinearGradient(
        colors: [AppTheme.textH, AppTheme.gold],
      ).createShader(b),
      child: const Text(
        'Connect Wallet',
        style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
      ),
    ),
    const SizedBox(height: 8),
    const Text(
      'Connect your MetaMask wallet to browse and create agents.',
      style: TextStyle(color: AppTheme.textM, height: 1.5),
      textAlign: TextAlign.center,
    ),
    const SizedBox(height: 16),
    // Network badge
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border2),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
            color: AppTheme.gold,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        const Text(
          'Monad Testnet',
          style: TextStyle(
            color: AppTheme.gold,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: AppTheme.gold.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Text(
            'Chain 10143',
            style: TextStyle(
              color: AppTheme.textM,
              fontSize: 10,
              fontFamily: 'monospace',
            ),
          ),
        ),
      ]),
    ),
    const SizedBox(height: 20),
    // How it works steps
    Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'How it works',
            style: TextStyle(
              color: AppTheme.textH,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 12),
          _StepRow(
            number: '1',
            text: 'Connect your MetaMask wallet',
            icon: Icons.account_balance_wallet_outlined,
          ),
          SizedBox(height: 8),
          _StepRow(
            number: '2',
            text: 'Sign a message to verify ownership',
            icon: Icons.draw_outlined,
          ),
          SizedBox(height: 8),
          _StepRow(
            number: '3',
            text: 'Get 100 free credits to start creating',
            icon: Icons.card_giftcard_outlined,
          ),
        ],
      ),
    ),
    const SizedBox(height: 14),
    // Credit costs
    Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Credit Costs',
            style: TextStyle(
              color: AppTheme.textM,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          _costRow(Icons.add_box_outlined, 'Create Agent', 10, AppTheme.primary),
          const SizedBox(height: 6),
          _costRow(Icons.fork_right, 'Fork Agent', 5, AppTheme.primary),
        ],
      ),
    ),
    const SizedBox(height: 24),
    // Error display
    Obx(() {
      if (ctrl.error.value != null) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.primary.withValues(alpha: 0.4)),
            ),
            child: Row(children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: AppTheme.primary,
                size: 16,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  ctrl.error.value!,
                  style: const TextStyle(color: AppTheme.textB, fontSize: 12),
                ),
              ),
            ]),
          ),
        );
      }
      return const SizedBox.shrink();
    }),
    // Connect button
    Obx(() => _ConnectButton(
      isConnecting: ctrl.isConnecting.value,
      onPressed: ctrl.isConnecting.value ? null : ctrl.connect,
    )),
  ]);
}

// ── Connected view ──────────────────────────────────────────────────────────

class _ConnectedView extends StatelessWidget {
  final AuthController ctrl;
  const _ConnectedView({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isLow = ctrl.credits.value < 20;
      return Column(mainAxisSize: MainAxisSize.min, children: [
        // Connected icon
        Container(
          width: 68,
          height: 68,
          decoration: BoxDecoration(
            color: AppTheme.olive.withValues(alpha: 0.12),
            shape: BoxShape.circle,
            border: Border.all(
              color: AppTheme.olive.withValues(alpha: 0.3),
              width: 1.5,
            ),
          ),
          child: const Icon(Icons.check_circle_outline, color: AppTheme.olive, size: 32),
        ),
        const SizedBox(height: 16),
        const Text(
          'Connected',
          style: TextStyle(
            color: AppTheme.textH,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        // Wallet address
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.border),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: AppTheme.olive,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            SelectableText(
              ctrl.shortWallet,
              style: const TextStyle(
                color: AppTheme.textB,
                fontSize: 13,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.content_copy, size: 12, color: AppTheme.textM),
          ]),
        ),
        const SizedBox(height: 6),
        // Network indicator
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: AppTheme.gold,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          const Text(
            'Monad Testnet',
            style: TextStyle(color: AppTheme.textM, fontSize: 11),
          ),
        ]),
        const SizedBox(height: 24),
        // Credits card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isLow
                  ? [const Color(0xFF5A1008), AppTheme.card2]
                  : [const Color(0xFF3A2D10), AppTheme.card2],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isLow
                  ? AppTheme.primary.withValues(alpha: 0.5)
                  : AppTheme.gold.withValues(alpha: 0.3),
            ),
          ),
          child: Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text(
                'CREDITS BALANCE',
                style: TextStyle(
                  color: AppTheme.textM,
                  fontSize: 11,
                  letterSpacing: 1.5,
                ),
              ),
              _RefreshButton(
                isLoading: ctrl.isLoadingCredits.value,
                onPressed: ctrl.isLoadingCredits.value ? null : ctrl.loadCredits,
              ),
            ]),
            const SizedBox(height: 6),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.bolt_rounded, color: AppTheme.gold, size: 36),
              const SizedBox(width: 8),
              Text(
                '${ctrl.credits.value}',
                style: const TextStyle(
                  color: AppTheme.textH,
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -2,
                ),
              ),
            ]),
            if (isLow) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.warning_amber_rounded, color: AppTheme.primary, size: 14),
                  SizedBox(width: 5),
                  Text(
                    'Low credits -- some actions may be unavailable',
                    style: TextStyle(color: AppTheme.textB, fontSize: 11),
                  ),
                ]),
              ),
            ],
          ]),
        ),
        const SizedBox(height: 16),
        // Profile card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Icon(Icons.person_outline, size: 16, color: AppTheme.textM),
                const SizedBox(width: 8),
                const Text(
                  'Profile',
                  style: TextStyle(
                    color: AppTheme.textH,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                _EditProfileButton(
                  onTap: () => _showEditProfileDialog(context, ctrl),
                ),
              ]),
              const SizedBox(height: 10),
              if (ctrl.username.value.isNotEmpty) ...[
                Row(children: [
                  const Icon(Icons.badge_outlined, color: AppTheme.textM, size: 14),
                  const SizedBox(width: 6),
                  Text(
                    ctrl.username.value,
                    style: const TextStyle(color: AppTheme.textH, fontSize: 13),
                  ),
                ]),
                const SizedBox(height: 6),
              ],
              ctrl.bio.value.isNotEmpty
                  ? Text(
                      ctrl.bio.value,
                      style: const TextStyle(
                        color: AppTheme.textM,
                        fontSize: 12,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    )
                  : const Row(children: [
                      Icon(Icons.edit_note_outlined, size: 14, color: AppTheme.textM),
                      SizedBox(width: 6),
                      Text(
                        'No bio set. Tap edit to add one.',
                        style: TextStyle(color: AppTheme.textM, fontSize: 12),
                      ),
                    ]),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Credit costs
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.border),
          ),
          child: Column(children: [
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Credit Costs',
                style: TextStyle(
                  color: AppTheme.textM,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 10),
            _costRow(Icons.add_box_outlined, 'Create Agent', 10, AppTheme.primary),
            const SizedBox(height: 6),
            _costRow(Icons.fork_right, 'Fork Agent', 5, AppTheme.primary),
          ]),
        ),
        const SizedBox(height: 14),
        // Buy credits
        Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.card2,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.gold.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(children: [
                Icon(Icons.add_card_rounded, color: AppTheme.gold, size: 16),
                SizedBox(width: 8),
                Text(
                  'Buy Credits',
                  style: TextStyle(
                    color: AppTheme.textH,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ]),
              const SizedBox(height: 4),
              const Text(
                '1 MON = 100 credits',
                style: TextStyle(color: AppTheme.textM, fontSize: 12),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [0.1, 0.5, 1.0, 5.0].map((amt) => _BuyButton(
                  amount: amt,
                  isBuying: ctrl.isBuyingCredits.value,
                  onPressed: ctrl.isBuyingCredits.value ? null : () => ctrl.topUp(amt),
                )).toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        // History button
        SizedBox(
          width: double.infinity,
          child: _HoverOutlinedButton(
            icon: Icons.history_rounded,
            label: 'View Credit History',
            onPressed: () => context.go('/credits/history'),
            foregroundColor: AppTheme.textB,
            borderColor: AppTheme.border2,
          ),
        ),
        const SizedBox(height: 8),
        // Disconnect button
        SizedBox(
          width: double.infinity,
          child: _HoverOutlinedButton(
            icon: Icons.power_settings_new_rounded,
            label: 'Disconnect',
            onPressed: ctrl.disconnect,
            foregroundColor: AppTheme.primary,
            borderColor: AppTheme.primary,
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
      builder: (_) => _EditProfileDialog(
        usernameCtrl: usernameCtrl,
        bioCtrl: bioCtrl,
        onSave: ctrl.updateProfile,
      ),
    );
  }
}

// ── Step row for "How it works" ─────────────────────────────────────────────

class _StepRow extends StatelessWidget {
  final String number;
  final String text;
  final IconData icon;
  const _StepRow({required this.number, required this.text, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: AppTheme.primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Center(
          child: Text(
            number,
            style: const TextStyle(
              color: AppTheme.primary,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
      const SizedBox(width: 10),
      Icon(icon, size: 14, color: AppTheme.textM),
      const SizedBox(width: 6),
      Expanded(
        child: Text(
          text,
          style: const TextStyle(color: AppTheme.textB, fontSize: 12),
        ),
      ),
    ]);
  }
}

// ── Connect button with hover ───────────────────────────────────────────────

class _ConnectButton extends StatefulWidget {
  final bool isConnecting;
  final VoidCallback? onPressed;
  const _ConnectButton({required this.isConnecting, this.onPressed});

  @override
  State<_ConnectButton> createState() => _ConnectButtonState();
}

class _ConnectButtonState extends State<_ConnectButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: _hovered
                  ? [const Color(0xFFD4432F), const Color(0xFFA01D12)]
                  : [AppTheme.primary, const Color(0xFF8B1A11)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primary.withValues(alpha: _hovered ? 0.5 : 0.35),
                blurRadius: _hovered ? 20 : 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: widget.onPressed,
            icon: widget.isConnecting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.account_balance_wallet_rounded, size: 18),
            label: Text(
              widget.isConnecting ? 'Connecting...' : 'Connect MetaMask',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Buy button with hover ───────────────────────────────────────────────────

class _BuyButton extends StatefulWidget {
  final double amount;
  final bool isBuying;
  final VoidCallback? onPressed;
  const _BuyButton({
    required this.amount,
    required this.isBuying,
    this.onPressed,
  });

  @override
  State<_BuyButton> createState() => _BuyButtonState();
}

class _BuyButtonState extends State<_BuyButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: _hovered
                ? AppTheme.gold
                : AppTheme.gold.withValues(alpha: 0.6),
          ),
          color: _hovered
              ? AppTheme.gold.withValues(alpha: 0.15)
              : AppTheme.gold.withValues(alpha: 0.08),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onPressed,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: widget.isBuying
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.gold,
                      ),
                    )
                  : Text(
                      '${widget.amount} MON\n${(widget.amount * 100).toInt()} cr',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppTheme.gold,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Hover outlined button ───────────────────────────────────────────────────

class _HoverOutlinedButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final Color foregroundColor;
  final Color borderColor;
  const _HoverOutlinedButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    required this.foregroundColor,
    required this.borderColor,
  });

  @override
  State<_HoverOutlinedButton> createState() => _HoverOutlinedButtonState();
}

class _HoverOutlinedButtonState extends State<_HoverOutlinedButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: _hovered
              ? widget.foregroundColor.withValues(alpha: 0.06)
              : Colors.transparent,
        ),
        child: OutlinedButton.icon(
          onPressed: widget.onPressed,
          icon: Icon(widget.icon, size: 16),
          label: Text(widget.label),
          style: OutlinedButton.styleFrom(
            foregroundColor: widget.foregroundColor,
            side: BorderSide(color: widget.borderColor),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Refresh button with hover ───────────────────────────────────────────────

class _RefreshButton extends StatefulWidget {
  final bool isLoading;
  final VoidCallback? onPressed;
  const _RefreshButton({required this.isLoading, this.onPressed});

  @override
  State<_RefreshButton> createState() => _RefreshButtonState();
}

class _RefreshButtonState extends State<_RefreshButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: _hovered ? AppTheme.card : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: widget.isLoading
              ? const Center(
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.gold,
                    ),
                  ),
                )
              : const Icon(Icons.refresh_rounded, color: AppTheme.textM, size: 18),
        ),
      ),
    );
  }
}

// ── Edit profile button with hover ──────────────────────────────────────────

class _EditProfileButton extends StatefulWidget {
  final VoidCallback onTap;
  const _EditProfileButton({required this.onTap});

  @override
  State<_EditProfileButton> createState() => _EditProfileButtonState();
}

class _EditProfileButtonState extends State<_EditProfileButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: _hovered
                ? AppTheme.primary.withValues(alpha: 0.15)
                : AppTheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: _hovered
                  ? AppTheme.primary.withValues(alpha: 0.6)
                  : AppTheme.primary.withValues(alpha: 0.4),
            ),
          ),
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.edit_outlined, color: AppTheme.primary, size: 13),
            SizedBox(width: 4),
            Text(
              'Edit',
              style: TextStyle(
                color: AppTheme.primary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ── Shared helpers ──────────────────────────────────────────────────────────

Widget _costRow(IconData icon, String label, int cost, Color color) =>
    Row(children: [
      Icon(icon, size: 15, color: color),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          label,
          style: const TextStyle(color: AppTheme.textB, fontSize: 12),
        ),
      ),
      Row(children: [
        const Icon(Icons.bolt_rounded, color: AppTheme.gold, size: 13),
        const SizedBox(width: 2),
        Text(
          '$cost',
          style: const TextStyle(
            color: AppTheme.gold,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ]),
    ]);

// ── Edit profile dialog ─────────────────────────────────────────────────────

class _EditProfileDialog extends StatefulWidget {
  final TextEditingController usernameCtrl;
  final TextEditingController bioCtrl;
  final Future<bool> Function(String, String) onSave;
  const _EditProfileDialog({
    required this.usernameCtrl,
    required this.bioCtrl,
    required this.onSave,
  });

  @override
  State<_EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<_EditProfileDialog> {
  bool _saving = false;

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: AppTheme.surface,
    surfaceTintColor: Colors.transparent,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: const BorderSide(color: AppTheme.border2),
    ),
    title: const Row(children: [
      Icon(Icons.person_outline, color: AppTheme.textM, size: 20),
      SizedBox(width: 8),
      Text('Edit Profile', style: TextStyle(color: AppTheme.textH)),
    ]),
    content: Column(mainAxisSize: MainAxisSize.min, children: [
      TextField(
        controller: widget.usernameCtrl,
        style: const TextStyle(color: AppTheme.textH),
        decoration: const InputDecoration(
          labelText: 'Username',
          prefixIcon: Icon(Icons.badge_outlined, size: 18),
        ),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: widget.bioCtrl,
        style: const TextStyle(color: AppTheme.textH),
        maxLines: 3,
        decoration: const InputDecoration(
          labelText: 'Bio',
          prefixIcon: Padding(
            padding: EdgeInsets.only(bottom: 40),
            child: Icon(Icons.notes_outlined, size: 18),
          ),
        ),
      ),
    ]),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: AppTheme.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        onPressed: _saving
            ? null
            : () async {
                setState(() => _saving = true);
                final ok = await widget.onSave(
                  widget.usernameCtrl.text.trim(),
                  widget.bioCtrl.text.trim(),
                );
                if (context.mounted) {
                  Navigator.pop(context);
                  if (ok) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Row(children: [
                          Icon(Icons.check_circle_outline, color: AppTheme.textH, size: 16),
                          SizedBox(width: 8),
                          Text('Profile updated!'),
                        ]),
                        backgroundColor: AppTheme.olive,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    );
                  }
                }
              },
        child: _saving
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Text('Save'),
      ),
    ],
  );
}

// ── Compatibility shim ──────────────────────────────────────────────────────
extension WalletScreenCompat on WalletConnectScreen {
  static bool get isAuthenticated => ApiService.instance.isAuthenticated;
}
