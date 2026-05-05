// v3.11.4: Trial→Purchase CTA banner.
//
// Renders an amber/gold banner under the Agent Detail header once the user
// has consumed their free-trial token (controller.trialUsed.value == true).
// Two CTAs: "Buy now" (primary action) and "Top up credits" (only when the
// user can't afford the agent's price).
//
// Pure presentational — caller wires the buy + top-up callbacks so this
// widget stays test-friendly and free of router / GetX coupling.

import 'package:flutter/material.dart';

import '../../../app/theme.dart';

class TrialEndCta extends StatelessWidget {
  /// Agent's purchase price in credits (used in the "for X credits" copy).
  final int priceCredits;

  /// Buyer's current credit balance — drives whether to surface the Top Up
  /// CTA prominently or as a subtle secondary action.
  final int userCredits;

  /// Tap handler for the primary "Buy now" CTA.
  final VoidCallback onBuy;

  /// Tap handler for the "Top up credits" CTA (route push to /wallet).
  final VoidCallback onTopUp;

  const TrialEndCta({
    super.key,
    required this.priceCredits,
    required this.userCredits,
    required this.onBuy,
    required this.onTopUp,
  });

  bool get hasEnoughCredits => userCredits >= priceCredits;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.gold.withValues(alpha: 0.10),
        border: Border.all(color: AppTheme.gold, width: 1.2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(Icons.shopping_cart_outlined, color: AppTheme.gold, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Trial complete',
                  style: TextStyle(
                    color: AppTheme.gold,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  hasEnoughCredits
                      ? 'Buy this agent for $priceCredits credits to unlock the prompt.'
                      : 'Costs $priceCredits credits — you have $userCredits. Top up to continue.',
                  style: const TextStyle(color: AppTheme.textM, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (hasEnoughCredits) ...[
            FilledButton(
              onPressed: onBuy,
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.gold,
                foregroundColor: AppTheme.bg,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              child: const Text('Buy now'),
            ),
            const SizedBox(width: 6),
            TextButton(
              onPressed: onTopUp,
              child: const Text('Top up'),
            ),
          ] else ...[
            FilledButton.icon(
              onPressed: onTopUp,
              icon: const Icon(Icons.add_circle_outline, size: 16),
              label: const Text('Top up credits'),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.gold,
                foregroundColor: AppTheme.bg,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
