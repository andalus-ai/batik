// lib/src/theming/agent_ui_theme.dart
//
// AgentUIKit v3 — Design Token Theming System
// ============================================================
// A semantic token layer that sits between Flutter's ThemeData
// and the agent-generated UI, so:
//
//  • Agents reference tokens ("primary", "surface", "error")
//    rather than raw hex — UIs automatically match brand
//  • The host app controls all colours through one object
//  • Dark mode is automatic via token resolution
//  • Typography scale is customisable
//  • Tokens are injectable into the system prompt so the LLM
//    knows which values to use
// ============================================================

import 'package:flutter/material.dart';
import '../core/style_utils.dart';

// ─────────────────────────────────────────────
// Colour token palette
// ─────────────────────────────────────────────

class AgentColorTokens {
  AgentColorTokens({
    // Brand
    required this.primary,
    required this.onPrimary,
    required this.primaryContainer,
    required this.onPrimaryContainer,

    // Secondary
    required this.secondary,
    required this.onSecondary,
    required this.secondaryContainer,
    required this.onSecondaryContainer,

    // Tertiary
    required this.tertiary,
    required this.onTertiary,

    // Semantic
    required this.error,
    required this.onError,
    required this.errorContainer,
    required this.success,
    required this.onSuccess,
    required this.warning,
    required this.onWarning,
    required this.info,
    required this.onInfo,

    // Surfaces
    required this.background,
    required this.onBackground,
    required this.surface,
    required this.onSurface,
    required this.surfaceVariant,
    required this.onSurfaceVariant,
    required this.outline,
    required this.outlineVariant,

    // Text
    required this.textPrimary,
    required this.textSecondary,
    required this.textDisabled,
    required this.textInverse,

    // Misc
    required this.shadow,
    required this.scrim,
  });

  // Brand
  final Color primary;
  final Color onPrimary;
  final Color primaryContainer;
  final Color onPrimaryContainer;

  // Secondary
  final Color secondary;
  final Color onSecondary;
  final Color secondaryContainer;
  final Color onSecondaryContainer;

  // Tertiary
  final Color tertiary;
  final Color onTertiary;

  // Semantic states
  final Color error;
  final Color onError;
  final Color errorContainer;
  final Color success;
  final Color onSuccess;
  final Color warning;
  final Color onWarning;
  final Color info;
  final Color onInfo;

  // Surfaces
  final Color background;
  final Color onBackground;
  final Color surface;
  final Color onSurface;
  final Color surfaceVariant;
  final Color onSurfaceVariant;
  final Color outline;
  final Color outlineVariant;

  // Text
  final Color textPrimary;
  final Color textSecondary;
  final Color textDisabled;
  final Color textInverse;

  // Misc
  final Color shadow;
  final Color scrim;

  /// Resolve a token name → Color.
  /// Agents use these names in `backgroundColor`, `foregroundColor` etc.
  Color? resolve(String token) => _getTokenMap()[token.toLowerCase()];

  Map<String, Color> _getTokenMap() => {
        'primary': primary,
        'onprimary': onPrimary,
        'primarycontainer': primaryContainer,
        'onprimarycontainer': onPrimaryContainer,
        'secondary': secondary,
        'onsecondary': onSecondary,
        'secondarycontainer': secondaryContainer,
        'onsecondarycontainer': onSecondaryContainer,
        'tertiary': tertiary,
        'ontertiary': onTertiary,
        'error': error,
        'onerror': onError,
        'errorcontainer': errorContainer,
        'success': success,
        'onsuccess': onSuccess,
        'warning': warning,
        'onwarning': onWarning,
        'info': info,
        'oninfo': onInfo,
        'background': background,
        'onbackground': onBackground,
        'surface': surface,
        'onsurface': onSurface,
        'surfacevariant': surfaceVariant,
        'onsurfacevariant': onSurfaceVariant,
        'outline': outline,
        'outlinevariant': outlineVariant,
        'textprimary': textPrimary,
        'textsecondary': textSecondary,
        'textdisabled': textDisabled,
        'textinverse': textInverse,
        'shadow': shadow,
        'scrim': scrim,
      };

  /// Build from Flutter's ColorScheme — easiest integration path.
  factory AgentColorTokens.fromColorScheme(ColorScheme cs) => AgentColorTokens(
        primary: cs.primary,
        onPrimary: cs.onPrimary,
        primaryContainer: cs.primaryContainer,
        onPrimaryContainer: cs.onPrimaryContainer,
        secondary: cs.secondary,
        onSecondary: cs.onSecondary,
        secondaryContainer: cs.secondaryContainer,
        onSecondaryContainer: cs.onSecondaryContainer,
        tertiary: cs.tertiary,
        onTertiary: cs.onTertiary,
        error: cs.error,
        onError: cs.onError,
        errorContainer: cs.errorContainer,
        success: const Color(0xFF2E7D32),
        onSuccess: Colors.white,
        warning: const Color(0xFFF57F17),
        onWarning: Colors.white,
        info: const Color(0xFF0277BD),
        onInfo: Colors.white,
        background: cs.surface,
        onBackground: cs.onSurface,
        surface: cs.surface,
        onSurface: cs.onSurface,
        surfaceVariant: cs.surfaceContainerHighest,
        onSurfaceVariant: cs.onSurfaceVariant,
        outline: cs.outline,
        outlineVariant: cs.outlineVariant,
        textPrimary: cs.onSurface,
        textSecondary: cs.onSurfaceVariant,
        textDisabled: cs.onSurface.withOpacity(.38),
        textInverse: cs.onInverseSurface,
        shadow: cs.shadow,
        scrim: cs.scrim,
      );

  /// Export token map as hex strings (for injecting into system prompt).
  Map<String, String> toHexMap() => _getTokenMap().map(
        (k, v) => MapEntry(k,
            '#${v.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}'),
      );
}

// ─────────────────────────────────────────────
// Typography tokens
// ─────────────────────────────────────────────

class AgentTypographyTokens {
  const AgentTypographyTokens({
    required this.displayLarge,
    required this.displayMedium,
    required this.displaySmall,
    required this.headlineLarge,
    required this.headlineMedium,
    required this.headlineSmall,
    required this.titleLarge,
    required this.titleMedium,
    required this.titleSmall,
    required this.bodyLarge,
    required this.bodyMedium,
    required this.bodySmall,
    required this.labelLarge,
    required this.labelMedium,
    required this.labelSmall,
    this.fontFamily,
    this.monoFontFamily,
  });

  final TextStyle displayLarge;
  final TextStyle displayMedium;
  final TextStyle displaySmall;
  final TextStyle headlineLarge;
  final TextStyle headlineMedium;
  final TextStyle headlineSmall;
  final TextStyle titleLarge;
  final TextStyle titleMedium;
  final TextStyle titleSmall;
  final TextStyle bodyLarge;
  final TextStyle bodyMedium;
  final TextStyle bodySmall;
  final TextStyle labelLarge;
  final TextStyle labelMedium;
  final TextStyle labelSmall;
  final String? fontFamily;
  final String? monoFontFamily;

  factory AgentTypographyTokens.fromTextTheme(TextTheme t) =>
      AgentTypographyTokens(
        displayLarge: t.displayLarge ?? const TextStyle(),
        displayMedium: t.displayMedium ?? const TextStyle(),
        displaySmall: t.displaySmall ?? const TextStyle(),
        headlineLarge: t.headlineLarge ?? const TextStyle(),
        headlineMedium: t.headlineMedium ?? const TextStyle(),
        headlineSmall: t.headlineSmall ?? const TextStyle(),
        titleLarge: t.titleLarge ?? const TextStyle(),
        titleMedium: t.titleMedium ?? const TextStyle(),
        titleSmall: t.titleSmall ?? const TextStyle(),
        bodyLarge: t.bodyLarge ?? const TextStyle(),
        bodyMedium: t.bodyMedium ?? const TextStyle(),
        bodySmall: t.bodySmall ?? const TextStyle(),
        labelLarge: t.labelLarge ?? const TextStyle(),
        labelMedium: t.labelMedium ?? const TextStyle(),
        labelSmall: t.labelSmall ?? const TextStyle(),
      );

  TextStyle? resolve(String variant) => {
        'displayLarge': displayLarge,
        'displayMedium': displayMedium,
        'displaySmall': displaySmall,
        'headlineLarge': headlineLarge,
        'headlineMedium': headlineMedium,
        'headlineSmall': headlineSmall,
        'titleLarge': titleLarge,
        'titleMedium': titleMedium,
        'titleSmall': titleSmall,
        'bodyLarge': bodyLarge,
        'bodyMedium': bodyMedium,
        'bodySmall': bodySmall,
        'labelLarge': labelLarge,
        'labelMedium': labelMedium,
        'labelSmall': labelSmall,
      }[variant];
}

// ─────────────────────────────────────────────
// Spacing tokens
// ─────────────────────────────────────────────

class AgentSpacingTokens {
  const AgentSpacingTokens({
    this.xs = 4,
    this.sm = 8,
    this.md = 16,
    this.lg = 24,
    this.xl = 32,
    this.xxl = 48,
    this.borderRadiusSm = 4,
    this.borderRadiusMd = 8,
    this.borderRadiusLg = 16,
    this.borderRadiusFull = 9999,
    this.elevationLow = 1,
    this.elevationMid = 4,
    this.elevationHigh = 8,
  });

  final double xs, sm, md, lg, xl, xxl;
  final double borderRadiusSm, borderRadiusMd, borderRadiusLg, borderRadiusFull;
  final double elevationLow, elevationMid, elevationHigh;

  double? resolve(String token) => {
        'xs': xs,
        'sm': sm,
        'md': md,
        'lg': lg,
        'xl': xl,
        'xxl': xxl,
      }[token];
}

// ─────────────────────────────────────────────
// Main theme object
// ─────────────────────────────────────────────

class AgentUITheme {
  const AgentUITheme({
    required this.colors,
    required this.typography,
    this.spacing = const AgentSpacingTokens(),
    this.isDark = false,
  });

  final AgentColorTokens colors;
  final AgentTypographyTokens typography;
  final AgentSpacingTokens spacing;
  final bool isDark;

  /// Derive from Flutter's ThemeData (easiest path).
  factory AgentUITheme.fromThemeData(ThemeData theme) => AgentUITheme(
        colors: AgentColorTokens.fromColorScheme(theme.colorScheme),
        typography: AgentTypographyTokens.fromTextTheme(theme.textTheme),
        isDark: theme.brightness == Brightness.dark,
      );

  /// Resolve a color reference from any node style property.
  /// Accepts: token names, hex strings, CSS named colors.
  Color? resolveColor(String? raw) {
    if (raw == null) return null;
    // Try token first
    final token = colors.resolve(raw);
    if (token != null) return token;
    // Fall back to hex/named
    return parseColor(raw);
  }

  /// Export token names → hex for injecting into the system prompt.
  String toSystemPromptSection() {
    final colorMap = colors.toHexMap();
    final entries =
        colorMap.entries.map((e) => '  ${e.key}: ${e.value}').join('\n');
    return '''
## App Design Tokens

Use these token names (not raw hex) for colors — they automatically adapt to dark/light mode:

$entries

Spacing tokens: xs=4, sm=8, md=16, lg=24, xl=32, xxl=48
Border radius: sm=4, md=8, lg=16, full=9999
Elevation: low=1, mid=4, high=8

Always prefer semantic tokens (primary, surface, error) over raw hex values.
''';
  }
}

// ─────────────────────────────────────────────
// InheritedWidget scope
// ─────────────────────────────────────────────

class AgentUIThemeScope extends InheritedWidget {
  const AgentUIThemeScope({
    super.key,
    required this.theme,
    required super.child,
  });

  final AgentUITheme theme;

  static AgentUITheme of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<AgentUIThemeScope>();
    if (scope != null) return scope.theme;
    // Fallback: derive from Flutter theme
    return AgentUITheme.fromThemeData(Theme.of(context));
  }

  static AgentUITheme? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<AgentUIThemeScope>()
        ?.theme;
  }

  @override
  bool updateShouldNotify(AgentUIThemeScope old) => theme != old.theme;
}

/// Extension for easy access anywhere in the tree.
extension AgentUIThemeContext on BuildContext {
  AgentUITheme get agentTheme => AgentUIThemeScope.of(this);
  AgentColorTokens get agentColors => AgentUIThemeScope.of(this).colors;
  AgentTypographyTokens get agentTypography =>
      AgentUIThemeScope.of(this).typography;
  AgentSpacingTokens get agentSpacing => AgentUIThemeScope.of(this).spacing;
}

// ─────────────────────────────────────────────
// Theme-aware color parser (replaces raw parseColor)
// ─────────────────────────────────────────────

/// Resolves a color string using the AgentUITheme first, then falls
/// back to hex/named parsing. Use this everywhere instead of parseColor.
Color? resolveThemedColor(BuildContext context, String? raw) {
  if (raw == null) return null;
  final theme = AgentUIThemeScope.maybeOf(context);
  if (theme != null) {
    final token = theme.colors.resolve(raw);
    if (token != null) return token;
  }
  return parseColor(raw);
}
