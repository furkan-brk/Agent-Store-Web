import 'package:flutter/material.dart';

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

  // Text ramp
  static const textH  = Color(0xFFF0E8D4); // warm white headings
  static const textB  = Color(0xFFA89070); // warm tan body
  static const textM  = Color(0xFF7A6A50); // muted text

  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: bg,
    colorScheme: const ColorScheme.dark(
      primary: primary,
      onPrimary: textH,
      secondary: gold,
      onSecondary: Color(0xFF1E1A14),
      surface: card,
      onSurface: textH,
      outline: border,
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
      labelStyle: const TextStyle(color: textM),
      hintStyle: const TextStyle(color: textM),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: gold),
    ),
    tabBarTheme: const TabBarThemeData(
      labelColor: textH,
      unselectedLabelColor: textM,
      dividerColor: border,
    ),
    dividerTheme: const DividerThemeData(color: border, thickness: 1),
    textTheme: const TextTheme(
      displayLarge:   TextStyle(color: textH, fontWeight: FontWeight.bold),
      headlineLarge:  TextStyle(color: textH, fontWeight: FontWeight.bold),
      headlineMedium: TextStyle(color: textH, fontWeight: FontWeight.w600),
      titleLarge:     TextStyle(color: textH, fontWeight: FontWeight.w600),
      titleMedium:    TextStyle(color: textB),
      bodyLarge:      TextStyle(color: textB),
      bodyMedium:     TextStyle(color: textM),
      bodySmall:      TextStyle(color: textM),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: card2,
      side: const BorderSide(color: border),
      labelStyle: const TextStyle(color: textB, fontSize: 11),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: card2,
      contentTextStyle: const TextStyle(color: textH),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      behavior: SnackBarBehavior.floating,
    ),
  );
}
