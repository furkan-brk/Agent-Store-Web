import 'package:flutter/material.dart';
import '../../app/theme.dart';

// ══════════════════════════════════════════════════════════════════════════════
// ShimmerScope — single AnimationController shared via InheritedWidget.
// Wrap a grid of skeleton cards with this so all cards animate in sync.
// ══════════════════════════════════════════════════════════════════════════════

class ShimmerScope extends StatefulWidget {
  final Widget child;
  const ShimmerScope({super.key, required this.child});

  /// Returns the shared animation, or null if not inside a ShimmerScope.
  static Animation<double>? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_ShimmerInherited>()?.animation;

  @override
  State<ShimmerScope> createState() => _ShimmerScopeState();
}

class _ShimmerScopeState extends State<ShimmerScope>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _ShimmerInherited(animation: _ctrl, child: widget.child);
}

class _ShimmerInherited extends InheritedWidget {
  final Animation<double> animation;
  const _ShimmerInherited({required this.animation, required super.child});

  @override
  bool updateShouldNotify(_ShimmerInherited old) => false; // animation ref never changes
}

// ══════════════════════════════════════════════════════════════════════════════
// ShimmerBox — a single rectangle with a sweeping sheen.
// Uses ShimmerScope's shared animation if available.
// ══════════════════════════════════════════════════════════════════════════════

class ShimmerBox extends StatelessWidget {
  final double width;
  final double height;
  final double radius;
  final Color color;
  const ShimmerBox({
    super.key,
    required this.width,
    required this.height,
    this.radius = 6,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final anim = ShimmerScope.of(context);
    if (anim == null) {
      // No scope: static placeholder
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: AppTheme.card2,
          borderRadius: BorderRadius.circular(radius),
        ),
      );
    }
    return AnimatedBuilder(
      animation: anim,
      builder: (_, __) {
        final v = anim.value; // 0.0 → 1.0
        return ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: SizedBox(
            width: width,
            height: height,
            child: Stack(children: [
              // Base colour
              Container(color: AppTheme.card2),
              // Sweeping sheen — translates from left (-150%) to right (+150%)
              Positioned.fill(
                child: FractionalTranslation(
                  translation: Offset(-1.5 + v * 3.0, 0),
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          Color(0x14F0E8D4),
                          Color(0x2CF0E8D4),
                          Color(0x14F0E8D4),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ]),
          ),
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// AgentCardSkeleton — mirrors the real AgentCard layout exactly.
// ══════════════════════════════════════════════════════════════════════════════

class AgentCardSkeleton extends StatelessWidget {
  const AgentCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Banner (pixel art area) ──
        Container(
          height: 118,
          decoration: const BoxDecoration(
            color: AppTheme.bg,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(13),
              topRight: Radius.circular(13),
            ),
          ),
          child: const Center(
            child: ShimmerBox(width: 72, height: 72, radius: 36, color: AppTheme.card2),
          ),
        ),
        // ── Card body ──
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Type · Subclass row + rarity dot
            const Row(children: [
              ShimmerBox(width: 100, height: 10, radius: 4, color: AppTheme.card2),
              Spacer(),
              ShimmerBox(width: 8, height: 8, radius: 4, color: AppTheme.card2),
            ]),
            const SizedBox(height: 8),
            // Title
            const ShimmerBox(width: double.infinity, height: 13, radius: 4, color: AppTheme.card2),
            const SizedBox(height: 6),
            // Description line 1
            const ShimmerBox(width: double.infinity, height: 10, radius: 4, color: AppTheme.card2),
            const SizedBox(height: 4),
            // Description line 2 (shorter)
            const ShimmerBox(width: 130, height: 10, radius: 4, color: AppTheme.card2),
            const SizedBox(height: 10),
            // Mini stat bars (3 rows)
            ...List.generate(3, (_) => const Padding(
              padding: EdgeInsets.only(bottom: 5),
              child: ShimmerBox(width: double.infinity, height: 6, radius: 3, color: AppTheme.card2),
            )),
            const SizedBox(height: 6),
            // Footer: save count · use count · price
            const Row(children: [
              ShimmerBox(width: 36, height: 10, radius: 4, color: AppTheme.card2),
              SizedBox(width: 12),
              ShimmerBox(width: 36, height: 10, radius: 4, color: AppTheme.card2),
              Spacer(),
              ShimmerBox(width: 40, height: 10, radius: 4, color: AppTheme.card2),
            ]),
          ]),
        ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// GuildCardSkeleton — mirrors the real GuildCard layout.
// Uses a parchment-toned base to match the guild UI's light theme.
// ══════════════════════════════════════════════════════════════════════════════

class GuildCardSkeleton extends StatelessWidget {
  const GuildCardSkeleton({super.key});

  // Slightly darker than the parchment card bg (0xFFE8DEC9)
  static const _shimmerBase = Color(0xFFCFC7B0);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFE8DEC9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFC0B490).withValues(alpha: 0.35),
        ),
      ),
      child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Icon + name row
        Row(children: [
          ShimmerBox(width: 30, height: 30, radius: 6, color: _shimmerBase),
          SizedBox(width: 8),
          Expanded(child: ShimmerBox(width: double.infinity, height: 13, radius: 4, color: _shimmerBase)),
        ]),
        SizedBox(height: 10),
        // Tag chips row
        Row(children: [
          ShimmerBox(width: 62, height: 20, radius: 6, color: _shimmerBase),
          SizedBox(width: 8),
          ShimmerBox(width: 72, height: 20, radius: 6, color: _shimmerBase),
        ]),
        Spacer(),
        // Footer: members count + status badge
        Row(children: [
          ShimmerBox(width: 90, height: 10, radius: 4, color: _shimmerBase),
          Spacer(),
          ShimmerBox(width: 50, height: 10, radius: 4, color: _shimmerBase),
        ]),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Convenience: SkeletonAgentGrid — a non-scrollable shimmer grid for loading states.
// Wrap in a scrollable parent (e.g., CustomScrollView) when needed.
// ══════════════════════════════════════════════════════════════════════════════

class SkeletonAgentGrid extends StatelessWidget {
  final int count;
  final EdgeInsets padding;
  const SkeletonAgentGrid({
    super.key,
    this.count = 12,
    this.padding = const EdgeInsets.fromLTRB(20, 8, 20, 20),
  });

  @override
  Widget build(BuildContext context) {
    return ShimmerScope(
      child: Padding(
        padding: padding,
        child: Wrap(
          spacing: 16,
          runSpacing: 16,
          children: List.generate(count, (_) => const SizedBox(
            width: 300,
            height: 416, // 300 / 0.72
            child: AgentCardSkeleton(),
          )),
        ),
      ),
    );
  }
}
