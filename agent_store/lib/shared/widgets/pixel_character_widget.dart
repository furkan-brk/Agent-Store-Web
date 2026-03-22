import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../core/constants/api_constants.dart';
import '../../features/character/character_types.dart';

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
  /// Base64-encoded PNG from Gemini Imagen. When present, shown as the agent's avatar.
  /// When null, a shimmer loading skeleton is displayed instead.
  final String? generatedImage;
  /// Relative URL to the server-hosted image (e.g. "/api/v1/images/agents/123.webp").
  /// Preferred over [generatedImage] when available.
  final String? imageUrl;

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
    this.imageUrl,
  });

  @override
  State<PixelCharacterWidget> createState() => _PixelCharacterWidgetState();
}

class _PixelCharacterWidgetState extends State<PixelCharacterWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;
  Uint8List? _imageBytes;
  /// Full URL resolved from the relative [PixelCharacterWidget.imageUrl].
  String? _resolvedImageUrl;

  static Duration _animDuration(CharacterRarity r) {
    switch (r) {
      case CharacterRarity.legendary:
        return const Duration(seconds: 3);
      case CharacterRarity.epic:
        return const Duration(seconds: 4);
      case CharacterRarity.rare:
        return const Duration(seconds: 8);
      default:
        return const Duration(seconds: 3);
    }
  }

  static bool _shouldAnimate(CharacterRarity r) =>
      r == CharacterRarity.legendary ||
      r == CharacterRarity.epic ||
      r == CharacterRarity.rare;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _anim = Tween<double>(begin: 0, end: 1).animate(_ctrl);
    _decodeImage();
    _refreshAnimation();
  }

  @override
  void didUpdateWidget(PixelCharacterWidget old) {
    super.didUpdateWidget(old);
    if (old.generatedImage != widget.generatedImage ||
        old.imageUrl != widget.imageUrl) {
      _decodeImage();
      _refreshAnimation();
    }
    if (old.rarity != widget.rarity) {
      _refreshAnimation();
    }
  }

  void _decodeImage() {
    // Prefer URL-based loading when available
    if (widget.imageUrl != null && widget.imageUrl!.isNotEmpty) {
      _resolvedImageUrl = '${ApiConstants.baseUrl}${widget.imageUrl}';
      _imageBytes = null; // not needed when URL is available
    } else if (widget.generatedImage != null && widget.generatedImage!.isNotEmpty) {
      _resolvedImageUrl = null;
      try {
        _imageBytes = base64Decode(widget.generatedImage!);
      } catch (_) {
        _imageBytes = null;
      }
    } else {
      _resolvedImageUrl = null;
      _imageBytes = null;
    }
  }

  /// Whether the widget has a resolved image source (URL or base64 bytes).
  bool get _hasImage => _resolvedImageUrl != null || _imageBytes != null;

  /// Whether the caller explicitly requested an image (even if it hasn't loaded yet).
  /// When true but _hasImage is false, we show a shimmer loader.
  /// When false, we show the character-type placeholder instead.
  bool get _expectsImage =>
      (widget.imageUrl != null && widget.imageUrl!.isNotEmpty) ||
      (widget.generatedImage != null && widget.generatedImage!.isNotEmpty);

  /// Manages the animation controller lifecycle:
  /// - Expects image but not loaded: always loop (drives shimmer skeleton).
  /// - No image expected: gentle loop for floating effect on placeholder.
  /// - Image loaded + rare+: loop with rarity-specific duration (drives effects).
  /// - Image loaded + common/uncommon: stop (static, no wasted CPU).
  void _refreshAnimation() {
    if (!_hasImage && _expectsImage) {
      // Shimmer mode — fast loop regardless of rarity
      _ctrl.duration = const Duration(milliseconds: 1200);
      if (!_ctrl.isAnimating) _ctrl.repeat();
    } else if (!_hasImage && !_expectsImage) {
      // Placeholder mode — gentle floating animation
      _ctrl.duration = const Duration(seconds: 3);
      if (!_ctrl.isAnimating) _ctrl.repeat();
    } else if (_shouldAnimate(widget.rarity)) {
      // Image + animated rarity — switch to rarity timing
      _ctrl.duration = _animDuration(widget.rarity);
      _ctrl.repeat();
    } else {
      // Image + static rarity — freeze at 0
      _ctrl.stop();
      _ctrl.value = 0;
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
      RepaintBoundary(child: _frame(context)),
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

  Widget _frame(BuildContext context) {
    final fc = widget.rarity.color;
    final theme = Theme.of(context);

    return Container(
      width: widget.size + 16,
      height: widget.size + 16,
      decoration: BoxDecoration(
        // Use a dark background that matches the app theme
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: fc, width: 2),
        boxShadow: [BoxShadow(color: fc.withValues(alpha: 0.35), blurRadius: 14, spreadRadius: 2)],
      ),
      child: Center(
        child: AnimatedBuilder(
          animation: _anim,
          builder: (_, __) {
            if (_hasImage) return _buildImageWithEffects(_anim.value);
            if (_expectsImage) return _loadingShimmer(_anim.value);
            return _characterPlaceholder(_anim.value);
          },
        ),
      ),
    );
  }

  // -- Generated image path ---------------------------------------------------

  Widget _buildImageWithEffects(double v) {
    double floatY = 0;
    if (widget.rarity == CharacterRarity.epic ||
        widget.rarity == CharacterRarity.legendary) {
      floatY = math.sin(v * 2 * math.pi) * 3;
    }

    Widget img = ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: _resolvedImageUrl != null
          ? Image.network(
              _resolvedImageUrl!,
              width: widget.size,
              height: widget.size,
              fit: BoxFit.cover,
              loadingBuilder: (_, child, progress) {
                if (progress == null) return child;
                return _loadingShimmer(v);
              },
              errorBuilder: (_, __, ___) {
                // Fall back to base64 if URL fails and base64 is available
                if (widget.generatedImage != null && widget.generatedImage!.isNotEmpty) {
                  try {
                    final bytes = base64Decode(widget.generatedImage!);
                    return Image.memory(
                      bytes,
                      width: widget.size,
                      height: widget.size,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _errorPlaceholder(),
                    );
                  } catch (_) {
                    return _errorPlaceholder();
                  }
                }
                return _errorPlaceholder();
              },
            )
          : Image.memory(
              _imageBytes!,
              width: widget.size,
              height: widget.size,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _errorPlaceholder(),
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
                borderRadius: BorderRadius.circular(4),
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
                borderRadius: BorderRadius.circular(4),
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

  // -- Character placeholder (shown when no image is expected) -----------------

  Widget _characterPlaceholder(double v) {
    final type = widget.characterType;
    final floatY = math.sin(v * 2 * math.pi) * 2;

    // Icon mapping per character type
    const typeIcons = {
      CharacterType.wizard: Icons.auto_fix_high_rounded,
      CharacterType.strategist: Icons.psychology_rounded,
      CharacterType.oracle: Icons.visibility_rounded,
      CharacterType.guardian: Icons.shield_rounded,
      CharacterType.artisan: Icons.palette_rounded,
      CharacterType.bard: Icons.edit_note_rounded,
      CharacterType.scholar: Icons.menu_book_rounded,
      CharacterType.merchant: Icons.storefront_rounded,
    };

    return Transform.translate(
      offset: Offset(0, floatY),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                type.secondaryColor,
                type.primaryColor.withValues(alpha: 0.4),
              ],
            ),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  typeIcons[type] ?? Icons.auto_fix_high_rounded,
                  color: type.accentColor.withValues(alpha: 0.7),
                  size: widget.size * 0.35,
                ),
                SizedBox(height: widget.size > 48 ? 6 : 2),
                if (widget.size > 40)
                  Text(
                    type.displayName.toUpperCase(),
                    style: TextStyle(
                      color: type.accentColor.withValues(alpha: 0.5),
                      fontSize: (widget.size * 0.07).clamp(8, 11),
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // -- Shimmer skeleton (shown when generatedImage is null/pending) ------------

  Widget _loadingShimmer(double v) {
    final rarityColor = widget.rarity.color;
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: Stack(children: [
          // Dark base matching app background
          Container(color: const Color(0xFF1E1A14)),
          // Sweeping shimmer gradient driven by animation value
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    rarityColor.withValues(alpha: 0.13),
                    Colors.transparent,
                  ],
                  begin: Alignment(-2.0 + v * 4, 0),
                  end: Alignment(-1.0 + v * 4, 0),
                ),
              ),
            ),
          ),
          // Centered spinner
          Center(
            child: SizedBox(
              width: widget.size * 0.30,
              height: widget.size * 0.30,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: rarityColor.withValues(alpha: 0.55),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  // -- Error placeholder (image bytes invalid after decode) --------------------

  Widget _errorPlaceholder() => Container(
    width: widget.size,
    height: widget.size,
    color: const Color(0xFF1E1A14),
    child: Icon(
      Icons.broken_image_outlined,
      color: widget.characterType.accentColor.withValues(alpha: 0.4),
      size: widget.size * 0.35,
    ),
  );
}

// -- Subwidgets ---------------------------------------------------------------

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
      // Subtle border to ensure visibility on dark backgrounds
      border: Border.all(color: rarity.color.withValues(alpha: 0.4)),
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(children: [
        SizedBox(
          width: 78,
          child: Text(
            name.toUpperCase(),
            style: TextStyle(
              color: colorScheme.onSurface.withValues(alpha: 0.45),
              fontSize: 9,
              letterSpacing: 0.8,
            ),
          ),
        ),
        Expanded(child: ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: value / 100,
            backgroundColor: colorScheme.surface,
            valueColor: AlwaysStoppedAnimation(colorScheme.primary),
            minHeight: 5,
          ),
        )),
        const SizedBox(width: 6),
        SizedBox(
          width: 20,
          child: Text(
            '$value',
            textAlign: TextAlign.right,
            style: TextStyle(
              color: colorScheme.onSurface.withValues(alpha: 0.6),
              fontSize: 9,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ]),
    );
  }
}
