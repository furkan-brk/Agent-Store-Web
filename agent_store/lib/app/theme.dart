import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Deep Vintage palette — a warm, moody system that ships in two variants:
///
///  - **darkTheme** (default): the original deep brown / amber surface used
///    across every existing screen. AppTheme.bg / card / textH constants
///    point at this palette so legacy screens keep rendering identically.
///
///  - **lightTheme** (v3.11.2): a parchment-tinted aydınlık variant used by
///    the new Settings/Appearance ekranı. Builds with the same color tokens
///    so chips/buttons stay readable under either ThemeMode.
///
/// Hard-coded `AppTheme.bg`, `AppTheme.card`, `AppTheme.textH` literals in
/// existing screens still resolve to the dark palette — that's intentional;
/// the v3.11.2 sprint scope is "toggle works for new shells", not "every
/// screen relit". Future sprints (v3.11.3+) will lift remaining literals
/// onto Theme.of(ctx).colorScheme.
class AppTheme {
  // ── Dark palette (default) ────────────────────────────────────────────────
  static const bg      = Color(0xFF1E1A14); // deep dark brown
  static const surface = Color(0xFF2A2318); // sidebar/drawer
  static const card    = Color(0xFF2E2820); // card surface
  static const card2   = Color(0xFF332D20); // slightly lighter card
  static const border  = Color(0xFF4A3D28); // warm dark border
  static const border2 = Color(0xFF5E4F32); // brighter border

  // Accent colours (shared across both themes)
  static const primary = Color(0xFFC1392B); // vivid crimson
  static const gold    = Color(0xFFD4A843); // warm gold
  static const olive   = Color(0xFF8A9A4A); // muted olive green

  // Semantic colours
  static const success = Color(0xFF5A8A48); // forest green
  static const error   = Color(0xFFC1392B); // same as primary — crimson
  static const warning = Color(0xFFD4A843); // gold
  static const info    = Color(0xFF4A6080); // steel blue

  // Text ramp (dark) — WCAG AA-friendly on dark bg
  static const textH  = Color(0xFFF0E8D4); // warm white headings
  static const textB  = Color(0xFFCCB48A); // warm tan body
  static const textM  = Color(0xFFB09E78); // muted text

  // ── Light palette (v3.11.2 — parchment) ───────────────────────────────────
  static const bgLight     = Color(0xFFF5F1E8); // parchment background
  static const surfaceLight= Color(0xFFEDE6D3); // sidebar / drawer
  static const cardLight   = Color(0xFFEDE6D3); // card surface
  static const card2Light  = Color(0xFFE3DABF); // alt card
  static const borderLight = Color(0xFFC9BC95); // warm tan border
  static const border2Light= Color(0xFFB7A87F); // emphasised border

  static const textHLight  = Color(0xFF2A1F0E); // near-black ink
  static const textBLight  = Color(0xFF40331C); // body
  static const textMLight  = Color(0xFF5C4A2E); // muted

  /// Backwards-compatible alias for the existing dark theme.
  /// Some legacy callers reference [AppTheme.dark] directly.
  static ThemeData get dark => darkTheme;

  static ThemeData get darkTheme => _build(
    brightness: Brightness.dark,
    bg: bg,
    surface: surface,
    card: card,
    card2: card2,
    border: border,
    border2: border2,
    textH: textH,
    textB: textB,
    textM: textM,
  );

  static ThemeData get lightTheme => _build(
    brightness: Brightness.light,
    bg: bgLight,
    surface: surfaceLight,
    card: cardLight,
    card2: card2Light,
    border: borderLight,
    border2: border2Light,
    textH: textHLight,
    textB: textBLight,
    textM: textMLight,
  );

  static ThemeData _build({
    required Brightness brightness,
    required Color bg,
    required Color surface,
    required Color card,
    required Color card2,
    required Color border,
    required Color border2,
    required Color textH,
    required Color textB,
    required Color textM,
  }) {
    final isDark = brightness == Brightness.dark;
    final colorScheme = isDark
        ? ColorScheme.dark(
            primary: primary,
            onPrimary: textH,
            secondary: gold,
            onSecondary: const Color(0xFF1E1A14),
            surface: card,
            onSurface: textH,
            surfaceContainerHighest: card2,
            outline: border,
            error: error,
            onError: textH,
            tertiary: olive,
          )
        : ColorScheme.light(
            primary: primary,
            onPrimary: const Color(0xFFFFFFFF),
            secondary: gold,
            onSecondary: const Color(0xFF1E1A14),
            surface: card,
            onSurface: textH,
            surfaceContainerHighest: card2,
            outline: border,
            error: error,
            onError: const Color(0xFFFFFFFF),
            tertiary: olive,
          );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: bg,
      fontFamily: GoogleFonts.inter().fontFamily,
      colorScheme: colorScheme,
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(color: textH, fontSize: 20, fontWeight: FontWeight.bold),
        iconTheme: IconThemeData(color: textB),
      ),
      cardTheme: CardThemeData(
        color: card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: card,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: primary, width: 1.5)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: error)),
        focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: error, width: 1.5)),
        labelStyle: TextStyle(color: textM),
        hintStyle: TextStyle(color: textM),
        errorStyle: const TextStyle(color: error, fontSize: 12),
        prefixIconColor: textM,
        suffixIconColor: textM,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: textH,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textB,
          side: BorderSide(color: border),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: gold),
      ),
      iconTheme: IconThemeData(color: textB, size: 20),
      tabBarTheme: TabBarThemeData(
        labelColor: textH,
        unselectedLabelColor: textM,
        dividerColor: border,
        indicatorColor: primary,
      ),
      dividerTheme: DividerThemeData(color: border, thickness: 1),
      textTheme: GoogleFonts.interTextTheme(TextTheme(
        displayLarge:   TextStyle(color: textH, fontWeight: FontWeight.bold),
        headlineLarge:  TextStyle(color: textH, fontWeight: FontWeight.bold),
        headlineMedium: TextStyle(color: textH, fontWeight: FontWeight.w600),
        titleLarge:     TextStyle(color: textH, fontWeight: FontWeight.w600),
        titleMedium:    TextStyle(color: textB),
        titleSmall:     TextStyle(color: textM, fontWeight: FontWeight.w500),
        labelLarge:     TextStyle(color: textH, fontWeight: FontWeight.bold, letterSpacing: 0.5),
        bodyLarge:      TextStyle(color: textB),
        bodyMedium:     TextStyle(color: textM),
        bodySmall:      TextStyle(color: textM),
      )),
      chipTheme: ChipThemeData(
        backgroundColor: card2,
        side: BorderSide(color: border),
        labelStyle: TextStyle(color: textB, fontSize: 11),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: card2,
        contentTextStyle: TextStyle(color: textH),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        behavior: SnackBarBehavior.floating,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: card2,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: border),
        ),
        textStyle: TextStyle(color: textH, fontSize: 12),
        waitDuration: const Duration(milliseconds: 400),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: border),
        ),
        titleTextStyle: TextStyle(color: textH, fontSize: 16, fontWeight: FontWeight.w600),
        contentTextStyle: TextStyle(color: textB, fontSize: 13),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: primary,
        linearTrackColor: card2,
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.hovered) ||
              states.contains(WidgetState.dragged)) {
            return border2;
          }
          return border;
        }),
        trackColor: WidgetStateProperty.all(Colors.transparent),
        thickness: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.hovered)) return 8.0;
          return 4.0;
        }),
        radius: const Radius.circular(4),
        thumbVisibility: WidgetStateProperty.all(false),
        interactive: true,
      ),
    );
  }
}

class AppSpacing {
  static const xs   = 4.0;
  static const sm   = 8.0;
  static const md   = 12.0;
  static const lg   = 16.0;
  static const xl   = 24.0;
  static const xxl  = 32.0;
  static const xxxl = 48.0;

  static double screenH(double width) =>
      width < AppBreakpoints.mobile ? lg : xl;
}

class AppSizing {
  static const navSidebar    = 220.0;
  static const catSidebar    = 200.0;
  static const filterSidebar = 260.0;
  static const cardRadius    = 14.0;
  static const inputRadius   = 10.0;
  static const minTapTarget  = 44.0;
}

class AppBreakpoints {
  static const mobile = 600.0;
  /// "Narrow" — the cutoff AppShell already uses to swap drawer / bottom-nav
  /// (also returned by `isNarrow(context)` in `responsive_layout.dart`).
  /// Used by responsive widgets to switch from multi-column to single-column.
  static const narrow = 768.0;
  static const tablet = 1024.0;

  static bool isMobile(double w)  => w < mobile;
  static bool isTablet(double w)  => w >= mobile && w < tablet;
  static bool isDesktop(double w) => w >= tablet;
}
