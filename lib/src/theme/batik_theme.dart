import 'package:flutter/material.dart';
import 'batik_colors.dart';

class BatikTheme {
  BatikTheme._();

  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: BatikColors.ochre,
        primary: BatikColors.leather,
        secondary: BatikColors.ochre,
        surface: BatikColors.parchment,
        onSurface: BatikColors.leather,
        onPrimary: BatikColors.parchment,
      ),
      scaffoldBackgroundColor: BatikColors.parchment,
      cardTheme: CardThemeData(
        color: Colors.white.withOpacity(0.8),
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: BatikColors.leather.withOpacity(0.1)),
        ),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          color: BatikColors.leather,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
        titleMedium: TextStyle(
          color: BatikColors.leather,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: TextStyle(color: BatikColors.leather),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: BatikColors.leather,
          foregroundColor: BatikColors.parchment,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }

  static ThemeData get dark {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: BatikColors.ochre,
        brightness: Brightness.dark,
        primary: BatikColors.ochre,
        secondary: BatikColors.gold,
        surface: BatikColors.shadow,
        onSurface: BatikColors.parchment,
      ),
      scaffoldBackgroundColor: BatikColors.shadow,
      cardTheme: CardThemeData(
        color: BatikColors.leather.withOpacity(0.3),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: BatikColors.gold.withOpacity(0.2)),
        ),
      ),
    );
  }
}
