import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../../../shared/services/local_kv_store.dart';

class LegendOnboarding extends StatefulWidget {
  final VoidCallback onDismiss;
  const LegendOnboarding({super.key, required this.onDismiss});

  static const _seenKey = 'legend_onboarding_seen';

  static Future<bool> shouldShow() async {
    final seen = await LocalKvStore.instance.getString(_seenKey);
    return seen != 'true';
  }

  static Future<void> markSeen() async {
    await LocalKvStore.instance.setString(_seenKey, 'true');
  }

  static Future<void> reset() async {
    await LocalKvStore.instance.remove(_seenKey);
  }

  @override
  State<LegendOnboarding> createState() => _LegendOnboardingState();
}

class _LegendOnboardingState extends State<LegendOnboarding> {
  int _step = 0;

  static const _steps = [
    (
      icon: Icons.drag_indicator_rounded,
      title: 'Drag & Drop',
      desc: 'Drag agents, missions, or guilds from the left panel onto the canvas.',
    ),
    (
      icon: Icons.link_rounded,
      title: 'Connect Nodes',
      desc: 'Connect nodes by dragging from an output port to an input port.',
    ),
    (
      icon: Icons.cloud_upload_rounded,
      title: 'Save to Cloud',
      desc: 'Click Save in the toolbar to persist your workflow to the cloud.',
    ),
    (
      icon: Icons.play_circle_rounded,
      title: 'Execute',
      desc: 'Run your workflow with AI — each agent node is executed in order.',
    ),
  ];

  void _next() {
    if (_step < _steps.length - 1) {
      setState(() => _step++);
    } else {
      _dismiss();
    }
  }

  void _dismiss() {
    LegendOnboarding.markSeen();
    widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    final step = _steps[_step];
    return GestureDetector(
      onTap: _dismiss,
      child: Container(
        color: Colors.black.withValues(alpha: 0.6),
        child: Center(
          child: GestureDetector(
            onTap: () {}, // absorb tap
            child: Container(
              width: 380,
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: AppTheme.card,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                // Step indicator
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_steps.length, (i) => Container(
                    width: i == _step ? 24 : 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: i == _step ? AppTheme.gold : AppTheme.border,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  )),
                ),
                const SizedBox(height: 24),
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppTheme.gold.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(step.icon, color: AppTheme.gold, size: 32),
                ),
                const SizedBox(height: 20),
                Text(
                  step.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppTheme.textH, fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Text(
                  step.desc,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppTheme.textM, fontSize: 14, height: 1.5),
                ),
                const SizedBox(height: 28),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  TextButton(
                    onPressed: _dismiss,
                    child: const Text('Skip', style: TextStyle(color: AppTheme.textM)),
                  ),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.gold,
                      foregroundColor: const Color(0xFF1E1A14),
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _next,
                    child: Text(_step < _steps.length - 1 ? 'Next' : 'Get Started'),
                  ),
                ]),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
