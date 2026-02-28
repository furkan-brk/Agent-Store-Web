import 'package:flutter/material.dart';

/// Fairy Tales vintage palette
/// #CAB891 parchment · #70683B olive · #81231E crimson · #5F6A54 sage · #2B2C1E dark olive
class AppTheme {
  static const _bg       = Color(0xFF181910); // very dark olive-black
  static const _surface  = Color(0xFF22231A); // dark olive surface / sidebar
  static const _card     = Color(0xFF2A2B1E); // card background
  static const _border   = Color(0xFF3D3E2A); // olive border
  static const _primary  = Color(0xFF81231E); // crimson red

  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: _bg,
    colorScheme: const ColorScheme.dark(
      primary: _primary,
      onPrimary: Color(0xFFE8D9B8),
      secondary: Color(0xFFCAB891),   // parchment
      surface: _surface,
      onSurface: Color(0xFFE8D9B8),   // light parchment text
      outline: _border,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: _surface,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(color: Color(0xFFE8D9B8), fontSize: 20, fontWeight: FontWeight.bold),
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
      fillColor: _surface,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _border)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _primary)),
      labelStyle: const TextStyle(color: Color(0xFF9E8F72)),
      hintStyle: const TextStyle(color: Color(0xFF5A5038)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: _primary,
        foregroundColor: const Color(0xFFE8D9B8),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
      ),
    ),
    textTheme: const TextTheme(
      displayLarge:   TextStyle(color: Color(0xFFE8D9B8), fontWeight: FontWeight.bold),
      headlineLarge:  TextStyle(color: Color(0xFFE8D9B8), fontWeight: FontWeight.bold),
      headlineMedium: TextStyle(color: Color(0xFFE8D9B8), fontWeight: FontWeight.w600),
      titleLarge:     TextStyle(color: Color(0xFFE8D9B8), fontWeight: FontWeight.w600),
      titleMedium:    TextStyle(color: Color(0xFFCAB891)),  // parchment
      bodyLarge:      TextStyle(color: Color(0xFFB8A882)),  // warm body
      bodyMedium:     TextStyle(color: Color(0xFF9E8F72)),  // muted parchment
    ),
    dividerTheme: const DividerThemeData(color: _border, thickness: 1),
  );
}
