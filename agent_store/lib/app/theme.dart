import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Deep Vintage Dark — a rich, moody dark mode with warm amber/crimson accents.
/// Background: #1E1A14  Surface: #2A2318  Card: #2E2820
/// Border: #4A3D28  Primary: #C1392B  Accent/Gold: #D4A843
class AppTheme {
  // Core dark palette
  static const bg      = Color(0xFF1E1A14); // deep dark brown
  static const surface = Color(0xFF2A2318); // sidebar/drawer
  static const card    = Color(0xFF2E2820); // card surface
  static const card2   = Color(0xFF332D20); // slightly lighter card
  static const border  = Color(0xFF4A3D28); // warm dark border
  static const border2 = Color(0xFF5E4F32); // brighter border

  // Accent colours
  static const primary = Color(0xFFC1392B); // vivid crimson
  static const gold    = Color(0xFFD4A843); // warm gold
  static const olive   = Color(0xFF8A9A4A); // muted olive green

  // Semantic colours
  static const success = Color(0xFF5A8A48); // forest green
  static const error   = Color(0xFFC1392B); // same as primary — crimson
  static const warning = Color(0xFFD4A843); // gold
  static const info    = Color(0xFF4A6080); // steel blue

  // Text ramp — WCAG AA-friendly on dark bg
  static const textH  = Color(0xFFF0E8D4); // warm white headings
  static const textB  = Color(0xFFCCB48A); // warm tan body  (was #A89070 — lifted for contrast)
  static const textM  = Color(0xFFB09E78); // muted text      (was #9E8B68 — lifted for WCAG AA 5:1+)

  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: bg,
    fontFamily: GoogleFonts.inter().fontFamily,
    colorScheme: const ColorScheme.dark(
      primary: primary,
      onPrimary: textH,
      secondary: gold,
      onSecondary: Color(0xFF1E1A14),
      surface: card,
      onSurface: textH,
      surfaceContainerHighest: card2,
      outline: border,
      error: error,
      onError: textH,
      tertiary: olive,
    ),
    appBarTheme: const AppBarTheme(
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
        side: const BorderSide(color: border),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: card,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: border)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: primary, width: 1.5)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: error)),
      focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: error, width: 1.5)),
      labelStyle: const TextStyle(color: textM),
      hintStyle: const TextStyle(color: textM),
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
        side: const BorderSide(color: border),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: gold),
    ),
    iconTheme: const IconThemeData(color: textB, size: 20),
    tabBarTheme: const TabBarThemeData(
      labelColor: textH,
      unselectedLabelColor: textM,
      dividerColor: border,
      indicatorColor: primary,
    ),
    dividerTheme: const DividerThemeData(color: border, thickness: 1),
    textTheme: GoogleFonts.interTextTheme(const TextTheme(
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
    chipTheme: const ChipThemeData(
      backgroundColor: card2,
      side: BorderSide(color: border),
      labelStyle: TextStyle(color: textB, fontSize: 11),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: card2,
      contentTextStyle: const TextStyle(color: textH),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      behavior: SnackBarBehavior.floating,
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: card2,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: border),
      ),
      textStyle: const TextStyle(color: textH, fontSize: 12),
      waitDuration: const Duration(milliseconds: 400),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: border),
      ),
      titleTextStyle: const TextStyle(color: textH, fontSize: 16, fontWeight: FontWeight.w600),
      contentTextStyle: const TextStyle(color: textB, fontSize: 13),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
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
  static const tablet = 1024.0;

  static bool isMobile(double w)  => w < mobile;
  static bool isTablet(double w)  => w >= mobile && w < tablet;
  static bool isDesktop(double w) => w >= tablet;
}
