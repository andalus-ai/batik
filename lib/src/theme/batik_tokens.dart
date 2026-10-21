// lib/src/theme/batik_tokens.dart
//
// Batik — Design System Tokens & Theming
// ============================================================
// Core design tokens: spacing, typography scales, border radii,
// elevation, and theme adaptation for charts (Tenun) & diagrams.
// ============================================================

import 'package:flutter/material.dart';
import 'batik_colors.dart';

/// Semantic spacing tokens for consistent padding, margins, and gaps.
abstract final class BatikSpacing {
  static const double xxs = 2.0;
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 24.0;
  static const double xxl = 32.0;
  static const double xxxl = 48.0;
}

/// Border radius tokens for cards, buttons, dialogs, and chips.
abstract final class BatikRadius {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 24.0;
  static const double full = 9999.0;

  static BorderRadius get roundedXs => BorderRadius.circular(xs);
  static BorderRadius get roundedSm => BorderRadius.circular(sm);
  static BorderRadius get roundedMd => BorderRadius.circular(md);
  static BorderRadius get roundedLg => BorderRadius.circular(lg);
  static BorderRadius get roundedXl => BorderRadius.circular(xl);
  static BorderRadius get pill => BorderRadius.circular(full);
}

/// Elevation tokens.
abstract final class BatikElevation {
  static const double none = 0.0;
  static const double flat = 1.0;
  static const double card = 2.0;
  static const double dropdown = 4.0;
  static const double modal = 8.0;
  static const double toast = 16.0;
}

/// Typography scale tokens.
abstract final class BatikTypography {
  static const String fontFamily = 'sans-serif';

  static const TextStyle displayLarge = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.bold,
    letterSpacing: -0.5,
    height: 1.2,
  );

  static const TextStyle headlineLarge = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    letterSpacing: -0.2,
    height: 1.25,
  );

  static const TextStyle headlineMedium = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 1.3,
  );

  static const TextStyle titleMedium = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.35,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.normal,
    height: 1.45,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.normal,
    height: 1.4,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    height: 1.3,
  );

  static const TextStyle code = TextStyle(
    fontSize: 13,
    fontFamily: 'monospace',
    height: 1.4,
  );
}

/// Adapter that bridges Batik design tokens to Tenun chart theming.
///
/// Ensures charts, diagrams, and 3D scenes look visually harmonious
/// with the application theme (light / dark).
class TenunThemeAdapter {
  const TenunThemeAdapter({
    required this.backgroundColor,
    required this.foregroundColor,
    required this.palette,
    required this.gridColor,
    required this.tooltipColor,
  });

  final Color backgroundColor;
  final Color foregroundColor;
  final List<Color> palette;
  final Color gridColor;
  final Color tooltipColor;

  factory TenunThemeAdapter.fromTheme(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    return TenunThemeAdapter(
      backgroundColor: theme.colorScheme.surface,
      foregroundColor: theme.colorScheme.onSurface,
      palette: isDark
          ? const [
              Color(0xFFE2B062), // gold
              Color(0xFF64B5F6), // blue
              Color(0xFF81C784), // green
              Color(0xFFFFB74D), // orange
              Color(0xFFBA68C8), // purple
              Color(0xFF4DD0E1), // cyan
            ]
          : const [
              BatikColors.ochre,
              BatikColors.leather,
              Color(0xFF1976D2),
              Color(0xFF388E3C),
              Color(0xFFF57C00),
              Color(0xFF7B1FA2),
            ],
      gridColor: theme.colorScheme.outlineVariant.withAlpha(70),
      tooltipColor: isDark ? const Color(0xFF2C2520) : const Color(0xFF3E2723),
    );
  }

  Map<String, dynamic> toChartThemeSpec() => {
        'backgroundColor': '#${backgroundColor.toARGB32().toRadixString(16).padLeft(8, '0')}',
        'textColor': '#${foregroundColor.toARGB32().toRadixString(16).padLeft(8, '0')}',
        'palette': palette
            .map((c) => '#${c.toARGB32().toRadixString(16).padLeft(8, '0')}')
            .toList(),
      };
}
