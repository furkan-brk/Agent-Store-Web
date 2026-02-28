import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'character_types.dart';
import 'character_data.dart';

class PixelArtPainter extends CustomPainter {
  final CharacterType characterType;
  final CharacterRarity rarity;
  final CharacterSubclass? subclass;
  final double animationValue;
  final int agentId;
  /// true = draw team link pulse border (used in guild formation widget)
  final bool teamLink;
  /// AI-generated 16×16 pixel matrix. If provided, overrides the static character art.
  final List<List<int>>? pixelMatrix;

  const PixelArtPainter({
    required this.characterType,
    required this.rarity,
    this.subclass,
    this.animationValue = 0.0,
    this.agentId = 0,
    this.teamLink = false,
    this.pixelMatrix,
  });

  double get _hueShift => ((agentId * 137) % 60 - 30).toDouble();

  Color _tint(Color base) {
    if (agentId == 0) return base;
    final hsv = HSVColor.fromColor(base);
    final shifted = (hsv.hue + _hueShift) % 360;
    return hsv.withHue(shifted < 0 ? shifted + 360 : shifted).toColor();
  }

  List<Color> _palette() {
    final p = _tint(characterType.primaryColor);
    final s = _tint(characterType.secondaryColor);
    final a = _tint(characterType.accentColor);
    return [
      Colors.transparent,          // 0
      p,                           // 1 primary
      s,                           // 2 secondary
      const Color(0xFFF5CBA7),     // 3 skin
      a,                           // 4 accent
      const Color(0xFFB8AA88),     // 5 dark outline
      const Color(0xFFFFFFFF),     // 6 highlight
      const Color(0xFF8B7340),     // 7 book/gold detail
      const Color(0xFF2D2D2D),     // 8 eyes
      rarity.color,                // 9 rarity special
    ];
  }

  @override
  void paint(Canvas canvas, Size size) {
    // Use AI-generated matrix if available, otherwise fall back to static data
    final pixels = pixelMatrix ?? characterPixelData[characterType.name];
    if (pixels == null) return;

    final palette = _palette();
    final paint = Paint()..style = PaintingStyle.fill;

    // Derive grid size from actual pixel data (32 for static 32×32, 16 for AI-generated)
    final gridSize = pixels.length;
    final ps = size.width / gridSize;
    // Scale factor for overlay placement (1 for 16-grid, 2 for 32-grid)
    final os = gridSize ~/ 16;

    // ── Layer −1: Checkered background — only for transparent pixels ──
    final checkerDark  = Paint()..style = PaintingStyle.fill..color = const Color(0xFF141508);
    final checkerLight = Paint()..style = PaintingStyle.fill..color = const Color(0xFFDDD1BB);
    for (int row = 0; row < pixels.length; row++) {
      final rowData = pixels[row];
      for (int col = 0; col < rowData.length; col++) {
        if (rowData[col] != 0) continue; // opaque pixel covers this cell, skip
        canvas.drawRect(
          Rect.fromLTWH(col * ps, row * ps, ps, ps),
          (row + col) % 2 == 0 ? checkerDark : checkerLight,
        );
      }
    }

    // ── Layer 4: Legendary shimmer ──
    if (rarity == CharacterRarity.legendary) {
      final shimmer = Paint()
        ..shader = LinearGradient(
          colors: [Colors.transparent, rarity.color.withValues(alpha: 0.25), Colors.transparent],
          begin: Alignment(-1 + animationValue * 2, -0.5),
          end:   Alignment(animationValue * 2, 0.5),
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), shimmer);
    }

    // ── Static characters: skip expensive trig calculations ──
    final bool hasAnimation = rarity == CharacterRarity.epic || rarity == CharacterRarity.legendary;
    final breathScale = hasAnimation ? 1.0 + math.sin(animationValue * 2 * math.pi) * 0.01 : 1.0;

    // ── Float offset (epic+) ──
    double floatY = 0;
    if (hasAnimation) {
      floatY = math.sin(animationValue * 2 * math.pi) * ps * 0.6;
    }

    final cx = size.width / 2;
    final cy = size.height / 2;
    final bool needsTransform = breathScale != 1.0 || floatY != 0;
    if (needsTransform) {
      canvas.save();
      canvas.translate(cx, cy + floatY);
      canvas.scale(breathScale);
      canvas.translate(-cx, -cy);
    }

    // ── Layer 0: Base body ──
    for (int row = 0; row < pixels.length; row++) {
      for (int col = 0; col < pixels[row].length; col++) {
        final idx = pixels[row][col];
        if (idx == 0) continue;
        final color = idx < palette.length ? palette[idx] : Colors.transparent;
        if (color == Colors.transparent) continue;
        paint.color = color;
        canvas.drawRect(Rect.fromLTWH(col * ps, row * ps, ps, ps), paint);
      }
    }

    // ── Layer 1+2: Subclass accessory overlay ──
    final subKey = subclass?.key ?? _defaultSubclassKey();
    final overlay = subclassOverlays[subKey];
    if (overlay != null) {
      // Head overlay: placed at row 0, col 2 (in 16-grid units → scaled by os)
      final headData = overlay['head'];
      if (headData != null) {
        for (int r = 0; r < headData.length; r++) {
          for (int c = 0; c < headData[r].length; c++) {
            final idx = headData[r][c];
            if (idx == 0) continue;
            final color = idx < palette.length ? palette[idx] : Colors.transparent;
            if (color == Colors.transparent) continue;
            paint.color = color;
            canvas.drawRect(
              Rect.fromLTWH((c + 2 * os) * ps, r * ps, ps, ps),
              paint,
            );
          }
        }
      }
      // Weapon overlay: placed at row 8, col 11 (in 16-grid units → scaled by os)
      final weaponData = overlay['weapon'];
      if (weaponData != null) {
        for (int r = 0; r < weaponData.length; r++) {
          for (int c = 0; c < weaponData[r].length; c++) {
            final idx = weaponData[r][c];
            if (idx == 0) continue;
            final color = idx < palette.length ? palette[idx] : Colors.transparent;
            if (color == Colors.transparent) continue;
            paint.color = color;
            canvas.drawRect(
              Rect.fromLTWH((c + 11 * os) * ps, (r + 8 * os) * ps, ps, ps),
              paint,
            );
          }
        }
      }
    }

    if (needsTransform) canvas.restore();

    // ── Layer 3: Rarity aura border pixels ──
    if (rarity != CharacterRarity.common && rarity != CharacterRarity.uncommon) {
      // Subclass glow for rare+
      final glowAlpha = rarity == CharacterRarity.legendary
          ? 0.5 + math.sin(animationValue * 2 * math.pi) * 0.25
          : 0.4;
      final glow = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = rarity == CharacterRarity.legendary ? 2.5 : 1.5
        ..color = rarity.color.withValues(alpha: glowAlpha.clamp(0.1, 0.8))
        ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 8);
      canvas.drawRect(Rect.fromLTWH(1, 1, size.width - 2, size.height - 2), glow);
    }

    // ── Layer 4b: Legendary particle aura ──
    if (rarity == CharacterRarity.legendary) {
      _drawParticles(canvas, size, palette[9]);
    }

    // ── Team link pulse border ──
    if (teamLink) {
      final pulse = (0.5 + math.sin(animationValue * 4 * math.pi) * 0.5).clamp(0.2, 1.0);
      final teamPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = characterType.accentColor.withValues(alpha: pulse);
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height),
        teamPaint,
      );
    }
  }

  /// 6 small particles orbiting the character
  void _drawParticles(Canvas canvas, Size size, Color color) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width * 0.55;
    final particlePaint = Paint()..color = color.withValues(alpha: 0.7);
    for (int i = 0; i < 6; i++) {
      final angle = (i / 6) * 2 * math.pi + animationValue * 2 * math.pi;
      final px = cx + r * math.cos(angle);
      final py = cy + r * math.sin(angle);
      canvas.drawCircle(Offset(px, py), 2.0, particlePaint);
    }
  }

  String _defaultSubclassKey() {
    const defaults = {
      'wizard': 'archmage', 'strategist': 'war_commander', 'oracle': 'prophet',
      'guardian': 'sentinel', 'artisan': 'sculptor', 'bard': 'storyteller',
      'scholar': 'sage', 'merchant': 'entrepreneur',
    };
    return defaults[characterType.name] ?? 'archmage';
  }

  @override
  bool shouldRepaint(PixelArtPainter old) {
    // Static characters (common/uncommon/rare): animationValue changes don't
    // require a repaint because breathScale = 1.0 and floatY = 0 for these rarities.
    if (rarity == CharacterRarity.common ||
        rarity == CharacterRarity.uncommon ||
        rarity == CharacterRarity.rare) {
      // Repaint only when character properties actually change
      return characterType != old.characterType ||
             rarity != old.rarity ||
             subclass != old.subclass ||
             agentId != old.agentId ||
             teamLink != old.teamLink ||
             pixelMatrix != old.pixelMatrix;
    }
    // epic/legendary: animation drives visual changes, repaint on every tick
    return animationValue != old.animationValue ||
           characterType != old.characterType ||
           rarity != old.rarity ||
           subclass != old.subclass ||
           agentId != old.agentId ||
           teamLink != old.teamLink ||
           pixelMatrix != old.pixelMatrix;
  }
}
