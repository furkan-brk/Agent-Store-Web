// lib/shared/widgets/wallet_guard.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../app/theme.dart';
import '../services/api_service.dart';

/// Reusable guard that checks wallet auth state before allowing an action.
///
/// Usage:
/// ```dart
/// onPressed: () {
///   if (!WalletGuard.check(context)) return;
///   // proceed with authenticated action...
/// }
/// ```
class WalletGuard {
  WalletGuard._();

  /// Returns `true` if the user is authenticated (JWT token present).
  /// If not authenticated, shows a themed dialog prompting wallet connection
  /// and returns `false`.
  static bool check(BuildContext context, {String? actionLabel}) {
    if (ApiService.instance.isAuthenticated) return true;
    _showConnectDialog(context, actionLabel: actionLabel);
    return false;
  }

  /// Same as [check] but shows a SnackBar instead of a dialog.
  /// Useful for less prominent actions (e.g. bookmark on a card).
  static bool checkWithSnackBar(BuildContext context, {String? actionLabel}) {
    if (ApiService.instance.isAuthenticated) return true;
    _showConnectSnackBar(context, actionLabel: actionLabel);
    return false;
  }

  /// Shows the full "Connect Wallet" dialog with explanation and CTA.
  static void _showConnectDialog(BuildContext context, {String? actionLabel}) {
    final description = actionLabel != null
        ? 'You need to connect your MetaMask wallet to $actionLabel.'
        : 'You need to connect your MetaMask wallet to perform this action.';

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppTheme.border2),
        ),
        title: const Row(children: [
          Icon(
            Icons.account_balance_wallet_outlined,
            color: AppTheme.gold,
            size: 22,
          ),
          SizedBox(width: 12),
          Text(
            'Connect Wallet',
            style: TextStyle(
              color: AppTheme.textH,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              description,
              style: const TextStyle(color: AppTheme.textB, fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 16),
            // "How it works" mini info
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.card,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Quick sign-in:',
                    style: TextStyle(
                      color: AppTheme.textM,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _infoRow(Icons.account_balance_wallet_outlined, 'Connect MetaMask'),
                  const SizedBox(height: 4),
                  _infoRow(Icons.draw_outlined, 'Sign a verification message'),
                  const SizedBox(height: 4),
                  _infoRow(Icons.card_giftcard_outlined, 'Get 100 free credits'),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          _ConnectWalletButton(
            onPressed: () {
              Navigator.pop(ctx);
              GoRouter.of(context).go('/wallet');
            },
          ),
        ],
      ),
    );
  }

  /// Shows a brief SnackBar with "Connect" action button.
  static void _showConnectSnackBar(BuildContext context, {String? actionLabel}) {
    final message = actionLabel != null
        ? 'Connect your wallet to $actionLabel'
        : 'Connect your wallet to perform this action';

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.account_balance_wallet_outlined, color: AppTheme.gold, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text(message, style: const TextStyle(color: AppTheme.textH)),
        ),
      ]),
      action: SnackBarAction(
        label: 'Connect',
        textColor: AppTheme.gold,
        onPressed: () => GoRouter.of(context).go('/wallet'),
      ),
      duration: const Duration(seconds: 4),
    ));
  }

  static Widget _infoRow(IconData icon, String text) => Row(children: [
    Icon(icon, size: 13, color: AppTheme.textM),
    const SizedBox(width: 8),
    Text(
      text,
      style: const TextStyle(color: AppTheme.textB, fontSize: 11),
    ),
  ]);
}

/// Small hover-aware "Connect Wallet" button for the dialog.
class _ConnectWalletButton extends StatefulWidget {
  final VoidCallback onPressed;
  const _ConnectWalletButton({required this.onPressed});

  @override
  State<_ConnectWalletButton> createState() => _ConnectWalletButtonState();
}

class _ConnectWalletButtonState extends State<_ConnectWalletButton> {
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
          boxShadow: _hovered
              ? [BoxShadow(color: AppTheme.primary.withValues(alpha: 0.3), blurRadius: 12)]
              : [],
        ),
        child: ElevatedButton.icon(
          onPressed: widget.onPressed,
          icon: const Icon(Icons.account_balance_wallet_rounded, size: 16),
          label: const Text('Connect Wallet'),
          style: ElevatedButton.styleFrom(
            backgroundColor: _hovered
                ? const Color(0xFFD4432F)
                : AppTheme.primary,
            foregroundColor: AppTheme.textH,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ),
    );
  }
}
