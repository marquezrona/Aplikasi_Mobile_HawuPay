import 'package:flutter/material.dart';

class TW {
  static const navy = Color(0xFF0A3663);
  static const navyDark = Color(0xFF0C2340);
  static const cream = Color(0xFFFAF8F5);
  static const border = Color(0xFFE5DEC9);
  static const terracotta = Color(0xFFA63A2B);
  static const red = Color(0xFF8B2626);
  static const gold = Color(0xFFE6A100);
  static const goldLight = Color(0xFFFFC52D);
  static const indigo = navy;
  static const slate50 = cream;
  static const slate200 = border;
  static const slate500 = Color(0xFF64748B);
  static const slate900 = navyDark;
  static const emerald = Color(0xFF16A34A);
  static const amber = gold;
}

ThemeData appTheme() {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: TW.navy,
    primary: TW.navy,
    secondary: TW.terracotta,
    tertiary: TW.gold,
    surface: Colors.white,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: TW.cream,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: TW.navyDark,
      elevation: 0,
      scrolledUnderElevation: 1,
      centerTitle: false,
    ),
    drawerTheme: const DrawerThemeData(backgroundColor: Colors.white),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: TW.border),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      labelStyle: const TextStyle(color: TW.slate500),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: TW.navy, width: 1.5),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: TW.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: TW.border),
      ),
    ),
    navigationDrawerTheme: const NavigationDrawerThemeData(
      indicatorColor: Color(0xFFE7EEF5),
      tileHeight: 52,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: TW.navy,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: TW.navy),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: TW.navy,
      foregroundColor: Colors.white,
    ),
    chipTheme: const ChipThemeData(
      side: BorderSide(color: TW.border),
      backgroundColor: TW.cream,
      labelStyle: TextStyle(color: TW.navyDark),
    ),
    dividerColor: TW.border,
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: TW.navy),
  );
}
