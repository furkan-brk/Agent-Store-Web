import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../features/character/character_types.dart';
import '../../features/character/pixel_art_painter.dart';

class PixelCharacterWidget extends StatefulWidget {
  final CharacterType characterType;
  final CharacterRarity rarity;
  final CharacterSubclass? subclass;
  final double size;
  final bool showName;
  final bool showRarity;
  final bool showSubclass;
  final bool showStats;
  final bool teamLink;
  final Map<String, int>? stats;
  final int agentId;
  /// Base64-encoded PNG from Gemini Imagen. When present, shown instead of pixel art.
  final String? generatedImage;

  const PixelCharacterWidget({
    super.key,
    required this.characterType,
    required this.rarity,
    this.subclass,
    this.size = 128,
    this.showName = false,
    this.showRarity = false,
    this.showSubclass = false,
    this.showStats = false,
    this.teamLink = false,
    this.stats,
    this.agentId = 0,
    this.generatedImage,
  });

  @override
  State<PixelCharacterWidget> createState() => _PixelCharacterWidgetState();
}

class _PixelCharacterWidgetState extends State<PixelCharacterWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;
  Uint8List? _imageBytes;

  // OPT-1: Choose animation duration based on rarity
  static Duration _animDuration(CharacterRarity r) {
    switch (r) {
      case CharacterRarity.legendary:
        return const Duration(seconds: 3);
      case CharacterRarity.epic:
        return const Duration(seconds: 4);
      case CharacterRarity.rare:
        return const Duration(seconds: 8);
      default:
        return const Duration(seconds: 3); // unused for static rarities
    }
  }

  // OPT-1: Only legendary, epic, rare get a running animation
  static bool _shouldAnimate(CharacterRarity r) =>
      r == CharacterRarity.legendary ||
      r == CharacterRarity.epic ||
      r == CharacterRarity.rare;

  @override
  void initState() {
    super.initState();
    // OPT-1: Set duration per rarity; only call repeat() when needed
    _ctrl = AnimationController(
      vsync: this,
      duration: _animDuration(widget.rarity),
    );
    _anim = Tween<double>(begin: 0, end: 1).animate(_ctrl);
    if (_shouldAnimate(widget.rarity)) {
      _ctrl.repeat();
    } else {
      _ctrl.value = 0; // static — show first frame, no loop
    }
    _decodeImage();
  }

  // OPT-2: React to rarity or image changes at runtime
  @override
  void didUpdateWidget(PixelCharacterWidget old) {
    super.didUpdateWidget(old);
    if (old.generatedImage != widget.generatedImage) {
      _decodeImage();
    }
    if (old.rarity != widget.rarity) {
      _ctrl.stop();
      _ctrl.duration = _animDuration(widget.rarity);
      if (_shouldAnimate(widget.rarity)) {
        _ctrl.repeat();
      } else {
        _ctrl.value = 0;
      }
    }
  }

  void _decodeImage() {
    if (widget.generatedImage != null && widget.generatedImage!.isNotEmpty) {
      try {
        _imageBytes = base64Decode(widget.generatedImage!);
      } catch (_) {
        _imageBytes = null;
      }
    } else {
      _imageBytes = null;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      _frame(),
      if (widget.showName) ...[
        const SizedBox(height: 8),
        Text(
          widget.characterType.displayName,
          style: TextStyle(
            color: widget.characterType.primaryColor,
            fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1,
          ),
        ),
      ],
      if (widget.showSubclass && widget.subclass != null) ...[
        const SizedBox(height: 3),
        _SubclassBadge(subclass: widget.subclass!, type: widget.characterType),
      ],
      if (widget.showRarity) ...[
        const SizedBox(height: 4),
        _RarityBadge(rarity: widget.rarity),
      ],
      if (widget.showStats && widget.stats != null) ...[
        const SizedBox(height: 8),
        SizedBox(width: widget.size + 16, child: _StatsPanel(stats: widget.stats!)),
      ],
    ]);
  }

  Widget _frame() {
    final fc = widget.rarity.color;
    // OPT-4: Skip AnimatedBuilder for static rarities with no generated image
    final isStatic = !_shouldAnimate(widget.rarity) && (_imageBytes == null);

    return Container(
      width: widget.size + 16,
      height: widget.size + 16,
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F1A),
        border: Border.all(color: fc, width: 2),
        boxShadow: [BoxShadow(color: fc.withValues(alpha: 0.35), blurRadius: 14, spreadRadius: 2)],
      ),
      child: Center(
        child: isStatic
            ? _pixelArtPainter(0) // static: fixed animation value
            : AnimatedBuilder(
                animation: _anim,
                builder: (_, __) {
                  if (_imageBytes != null) return _buildImageWithEffects(_anim.value);
                  return _pixelArtPainter(_anim.value);
                },
              ),
      ),
    );
  }

  // ── Generated image path ─────────────────────────────────────────────────

  Widget _buildImageWithEffects(double v) {
    double floatY = 0;
    if (widget.rarity == CharacterRarity.epic ||
        widget.rarity == CharacterRarity.legendary) {
      floatY = math.sin(v * 2 * math.pi) * 3;
    }

    Widget img = ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Image.memory(
        _imageBytes!,
        width: widget.size,
        height: widget.size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _placeholder(),
      ),
    );

    // Legendary shimmer overlay
    if (widget.rarity == CharacterRarity.legendary) {
      img = Stack(children: [
        img,
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    widget.rarity.color.withValues(alpha: 0.25),
                    Colors.transparent,
                  ],
                  begin: Alignment(-1.0 + v * 2, -0.5),
                  end: Alignment(v * 2, 0.5),
                ),
              ),
            ),
          ),
        ),
      ]);
    }

    // Team link pulse border
    if (widget.teamLink) {
      final pulse = (0.5 + math.sin(v * 4 * math.pi) * 0.5).clamp(0.2, 1.0);
      img = Stack(children: [
        img,
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(
                  color: widget.characterType.accentColor.withValues(alpha: pulse),
                  width: 2,
                ),
              ),
            ),
          ),
        ),
      ]);
    }

    return Transform.translate(offset: Offset(0, floatY), child: img);
  }

  Widget _placeholder() {
    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            widget.characterType.secondaryColor,
            widget.characterType.primaryColor,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Icon(
        Icons.auto_awesome,
        color: widget.characterType.accentColor,
        size: widget.size * 0.4,
      ),
    );
  }

  // ── Pixel art fallback path ──────────────────────────────────────────────

  // OPT-3: RepaintBoundary isolates repaints from parent widget tree
  Widget _pixelArtPainter(double v) => RepaintBoundary(
    child: CustomPaint(
      size: Size(widget.size, widget.size),
      painter: PixelArtPainter(
        characterType: widget.characterType,
        rarity: widget.rarity,
        subclass: widget.subclass,
        animationValue: v,
        agentId: widget.agentId,
        teamLink: widget.teamLink,
      ),
    ),
  );
}

// ── Subwidgets ──────────────────────────────────────────────────────────────

class _SubclassBadge extends StatelessWidget {
  final CharacterSubclass subclass;
  final CharacterType type;
  const _SubclassBadge({required this.subclass, required this.type});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: type.accentColor.withValues(alpha: 0.18),
      border: Border.all(color: type.accentColor.withValues(alpha: 0.5)),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      subclass.displayName.toUpperCase(),
      style: TextStyle(
        color: type.accentColor,
        fontSize: 8,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
      ),
    ),
  );
}

class _RarityBadge extends StatelessWidget {
  final CharacterRarity rarity;
  const _RarityBadge({required this.rarity});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
    decoration: BoxDecoration(
      gradient: LinearGradient(colors: rarity.gradientColors),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(rarity.displayName.toUpperCase(),
      style: const TextStyle(color: Colors.white, fontSize: 9,
        fontWeight: FontWeight.bold, letterSpacing: 1.5)),
  );
}

class _StatsPanel extends StatelessWidget {
  final Map<String, int> stats;
  const _StatsPanel({required this.stats});

  @override
  Widget build(BuildContext context) => Column(
    children: stats.entries.map((e) => _StatRow(name: e.key, value: e.value)).toList(),
  );
}

class _StatRow extends StatelessWidget {
  final String name;
  final int value;
  const _StatRow({required this.name, required this.value});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(children: [
      SizedBox(width: 78, child: Text(name.toUpperCase(),
        style: const TextStyle(color: Color(0xFF6B7280), fontSize: 9, letterSpacing: 0.8))),
      Expanded(child: ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: LinearProgressIndicator(
          value: value / 100,
          backgroundColor: const Color(0xFF1F2937),
          valueColor: const AlwaysStoppedAnimation(Color(0xFF6366F1)),
          minHeight: 5,
        ),
      )),
      const SizedBox(width: 6),
      Text('$value', style: const TextStyle(color: Color(0xFFD1D5DB), fontSize: 9)),
    ]),
  );
}
