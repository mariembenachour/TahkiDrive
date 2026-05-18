import 'package:flutter/material.dart';

class AppTheme {
  static const _purple     = Color(0xFF7226FF);
  static const _darkPurple = Color(0xFF160078);

  static final dark = ThemeData(
    brightness: Brightness.dark,
    fontFamily: 'Inter',
    primaryColor: _purple,
    scaffoldBackgroundColor: const Color(0xFF0A0015),
    colorScheme: const ColorScheme.dark(
      primary: _purple,
      secondary: _darkPurple,
      surface: Color(0xFF1A0035),
      onPrimary: Colors.white,
      onSurface: Colors.white,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.w700,
        fontFamily: 'Inter',
      ),
      iconTheme: IconThemeData(color: Colors.white),
    ),
    cardTheme: CardThemeData(
      color: const Color(0xFF1A0035),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Color(0xFF0D0020),
      selectedItemColor: _purple,
      unselectedItemColor: Colors.white38,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white.withOpacity(0.06),
      labelStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _purple, width: 1.5),
      ),
    ),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: Colors.white),
      bodyMedium: TextStyle(color: Colors.white70),
      titleLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
    ),
    dividerColor: Colors.white12,
    iconTheme: const IconThemeData(color: Colors.white),
  );

  static final light = ThemeData(
    brightness: Brightness.light,
    fontFamily: 'Inter',
    primaryColor: _purple,
    scaffoldBackgroundColor: const Color(0xFFF4F0FF),
    colorScheme: const ColorScheme.light(
      primary: _purple,
      secondary: _darkPurple,
      surface: Colors.white,
      onPrimary: Colors.white,
      onSurface: Color(0xFF0A0015),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      titleTextStyle: TextStyle(
        color: Color(0xFF0A0015),
        fontSize: 18,
        fontWeight: FontWeight.w700,
        fontFamily: 'Inter',
      ),
      iconTheme: IconThemeData(color: Color(0xFF0A0015)),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Colors.white,
      selectedItemColor: _purple,
      unselectedItemColor: Colors.black38,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.black.withOpacity(0.05),
      labelStyle: const TextStyle(color: Colors.black54),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _purple, width: 1.5),
      ),
    ),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: Color(0xFF0A0015)),
      bodyMedium: TextStyle(color: Colors.black54),
      titleLarge: TextStyle(color: Color(0xFF0A0015), fontWeight: FontWeight.w700),
    ),
    dividerColor: Colors.black12,
    iconTheme: const IconThemeData(color: Color(0xFF0A0015)),
  );
}
