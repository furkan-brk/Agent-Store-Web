// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class OnboardingModal extends StatefulWidget {
  const OnboardingModal({super.key});

  /// Returns true if onboarding should be shown (first visit).
  static bool shouldShow() {
    return html.window.localStorage['onboarding_done'] != 'true';
  }

  static void markDone() {
    html.window.localStorage['onboarding_done'] = 'true';
  }

  @override
  State<OnboardingModal> createState() => _OnboardingModalState();
}

class _OnboardingModalState extends State<OnboardingModal> {
  int _step = 0;

  static const _steps = [
    _Step(
      icon: Icons.auto_awesome,
      color: Color(0xFF81231E),
      title: 'Welcome to AgentStore',
      body: 'Discover, create and trade AI agents powered by Monad blockchain. Each agent is a unique pixel-art character with special abilities.',
    ),
    _Step(
      icon: Icons.account_balance_wallet_outlined,
      color: Color(0xFF5A8A48),
      title: 'Connect Your Wallet',
      body: 'Use MetaMask with Monad Testnet (Chain ID: 10143) to sign in, earn credits and purchase agents.',
    ),
    _Step(
      icon: Icons.bolt,
      color: Color(0xFF9B7B1A),
      title: 'Credits System',
      body: 'You start with free credits. Create an agent costs ⚡10, fork costs ⚡5. Buy more credits with MON tokens.',
    ),
    _Step(
      icon: Icons.auto_fix_high,
      color: Color(0xFFCAB891),
      title: 'Create Your Agent',
      body: 'Write a prompt describing your AI agent. Our AI analyzes it, generates a unique pixel-art character and assigns traits.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final step = _steps[_step];
    final isLast = _step == _steps.length - 1;

    return Dialog(
      backgroundColor: const Color(0xFF1E1F14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        width: 400,
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Step indicator dots
            Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(
              _steps.length,
              (i) => AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: i == _step ? 20 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: i == _step ? const Color(0xFF81231E) : const Color(0xFF4A4A33),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            )),
            const SizedBox(height: 28),
            // Icon
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                color: step.color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(color: step.color.withValues(alpha: 0.4), width: 2),
              ),
              child: Icon(step.icon, color: step.color, size: 32),
            ),
            const SizedBox(height: 20),
            // Title
            Text(step.title,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            // Body
            Text(step.body,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF9E8F72), fontSize: 14, height: 1.5)),
            const SizedBox(height: 32),
            // Buttons
            Row(children: [
              if (_step > 0)
                TextButton(
                  onPressed: () => setState(() => _step--),
                  child: const Text('Back', style: TextStyle(color: Color(0xFF7A6E52))),
                ),
              const Spacer(),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF81231E),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                onPressed: () {
                  if (isLast) {
                    OnboardingModal.markDone();
                    Navigator.of(context).pop();
                    // Navigate to wallet to connect
                    context.go('/wallet');
                  } else {
                    setState(() => _step++);
                  }
                },
                child: Text(isLast ? 'Connect Wallet' : 'Next',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ]),
            const SizedBox(height: 8),
            // Skip
            TextButton(
              onPressed: () {
                OnboardingModal.markDone();
                Navigator.of(context).pop();
              },
              child: const Text('Skip', style: TextStyle(color: Color(0xFF5A5038), fontSize: 12)),
            ),
          ]),
        ),
      ),
    );
  }
}

class _Step {
  final IconData icon;
  final Color color;
  final String title;
  final String body;
  const _Step({required this.icon, required this.color, required this.title, required this.body});
}
