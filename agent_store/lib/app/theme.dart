import 'package:flutter/material.dart';

class AppTheme {
  static const _bg       = Color(0xFF0A0A14);
  static const _surface  = Color(0xFF0F0F1E);
  static const _card     = Color(0xFF13131F);
  static const _border   = Color(0xFF1E1E35);
  static const _primary  = Color(0xFF6366F1);

  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: _bg,
    colorScheme: const ColorScheme.dark(
      primary: _primary,
      onPrimary: Colors.white,
      secondary: Color(0xFFA78BFA),
      surface: _surface,
      onSurface: Color(0xFFE5E7EB),
      outline: _border,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: _surface,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
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
      labelStyle: const TextStyle(color: Color(0xFF9CA3AF)),
      hintStyle: const TextStyle(color: Color(0xFF4B5563)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
      ),
    ),
    textTheme: const TextTheme(
      displayLarge:  TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      headlineLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      headlineMedium:TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
      titleLarge:    TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
      titleMedium:   TextStyle(color: Color(0xFFE5E7EB)),
      bodyLarge:     TextStyle(color: Color(0xFFD1D5DB)),
      bodyMedium:    TextStyle(color: Color(0xFF9CA3AF)),
    ),
    dividerTheme: const DividerThemeData(color: _border, thickness: 1),
  );
}
