import 'package:flutter/material.dart';

/// Fairy Tales vintage palette — light parchment edition
/// #DDD1BB main page · #CAB891 parchment · #70683B olive · #81231E crimson · #2B2C1E dark olive
class AppTheme {
  static const _bg       = Color(0xFFDDD1BB); // main parchment page
  static const _surface  = Color(0xFFC8BA9A); // sidebar / deeper parchment
  static const _card     = Color(0xFFE8DEC9); // card background (lighter)
  static const _border   = Color(0xFFADA07A); // parchment border
  static const _primary  = Color(0xFF81231E); // crimson red

  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: _bg,
    colorScheme: const ColorScheme.light(
      primary: _primary,
      onPrimary: Color(0xFFDDD1BB),
      secondary: Color(0xFF70683B),   // olive green
      surface: _card,
      onSurface: Color(0xFF2B2C1E),   // dark olive text
      outline: _border,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: _surface,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(color: Color(0xFF2B2C1E), fontSize: 20, fontWeight: FontWeight.bold),
    ),
    cardTheme: CardThemeData(
      color: _card,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: _border),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: _card,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _border)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _primary)),
      labelStyle: const TextStyle(color: Color(0xFF6B5A40)),
      hintStyle: const TextStyle(color: Color(0xFF9E8F72)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: _primary,
        foregroundColor: const Color(0xFFDDD1BB),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
      ),
    ),
    textTheme: const TextTheme(
      displayLarge:   TextStyle(color: Color(0xFF2B2C1E), fontWeight: FontWeight.bold),
      headlineLarge:  TextStyle(color: Color(0xFF2B2C1E), fontWeight: FontWeight.bold),
      headlineMedium: TextStyle(color: Color(0xFF2B2C1E), fontWeight: FontWeight.w600),
      titleLarge:     TextStyle(color: Color(0xFF2B2C1E), fontWeight: FontWeight.w600),
      titleMedium:    TextStyle(color: Color(0xFF4A4033)),  // medium dark
      bodyLarge:      TextStyle(color: Color(0xFF5A4A30)),  // warm body
      bodyMedium:     TextStyle(color: Color(0xFF6B5A40)),  // muted dark
    ),
    dividerTheme: const DividerThemeData(color: _border, thickness: 1),
  );
}
