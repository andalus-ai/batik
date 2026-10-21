// lib/src/adapters/system_prompt_builder.dart
//
// Batik Framework — Unified System Prompt Builder
// ============================================================
// Builds the complete system prompt from all framework layers:
//  • Base UI schema instructions
//  • Active design tokens (theming)
//  • Locale / language instructions
//  • Typed action contracts
//  • Plugin capabilities
//  • Accessibility hints
//  • Variable store snapshot
//  • Session context
// ============================================================

import 'dart:ui' show Locale;

import '../widgets/agent_localizations.dart';
import '../widgets/agent_ui_theme.dart';
import '../plugin/plugin_registry.dart';
import '../utils/typed_actions.dart';

class SystemPromptBuilderV3 {
  SystemPromptBuilderV3({
    this.theme,
    this.locale,
    this.localizationManager,
    this.includeTypedActions = true,
    this.includePlugins = true,
    this.includeAccessibilityHints = true,
    this.includeVariables = true,
    this.appContext,
    this.additionalInstructions,
  });

  final AgentUITheme? theme;
  final Locale? locale;
  final AgentLocalizationManager? localizationManager;
  final bool includeTypedActions;
  final bool includePlugins;
  final bool includeAccessibilityHints;
  final bool includeVariables;
  final String? appContext;
  final String? additionalInstructions;

  String build({Map<String, dynamic>? variables}) {
    final sections = <String>[];

    sections.add(_baseInstructions());

    if (appContext != null) {
      sections.add('## App Context\n\n$appContext');
    }

    if (theme != null) {
      sections.add(theme!.toSystemPromptSection());
    }

    if (locale != null && localizationManager != null) {
      sections.add(localizationManager!.toSystemPromptSection(locale!));
    }

    if (includeTypedActions) {
      sections.add(ActionPayloadParser().toSystemPromptSection());
    }

    if (includePlugins && AgentUIKitPlugins.all.isNotEmpty) {
      final pluginSection = AgentUIKitPlugins.systemPromptSection;
      if (pluginSection.isNotEmpty) sections.add(pluginSection);
    }

    if (includeAccessibilityHints) {
      sections.add(_accessibilityInstructions());
    }

    if (includeVariables && variables != null && variables.isNotEmpty) {
      sections.add(_variablesSection(variables));
    }

    if (additionalInstructions != null) {
      sections.add('## Additional Instructions\n\n$additionalInstructions');
    }

    return sections.join('\n\n---\n\n');
  }

  String _baseInstructions() => '''
# AgentUIKit — UI Generation Instructions

You generate Flutter UI as a JSON tree. Your response must be ONLY valid JSON — no markdown, no explanation, no preamble.

## Response Format

```json
{
  "schemaVersion": "2.0.0",
  "root": { ...UINode... },
  "metadata": {}
}
```

## Node Structure

Every node:
```json
{
  "type": "nodeType",
  "id": "optional-unique-id",
  "style": { ...UIStyle... },
  "actions": { "onTap": {"type": "actionType", "payload": {...}} },
  "condition": "variableKey",
  "children": []
}
```

## Core Node Types

Layout:
- container, row, column, stack
- card (elevation, borderRadius), scaffold (appBar, body, fab)

Content:
- text (variant: displayLarge|headlineLarge|titleLarge|bodyMedium|labelSmall etc.)
- richText, image (src, alt, fit), icon (icon, color, size)
- avatar (src|initials, size), badge (label, color)

Interactive:
- button (label, variant: filled|outlined|text|elevated, disabled)
- iconButton (icon, tooltip), fab (icon, label)
- textField (label, hint, variableBinding, inputType, obscureText)
- switch (value, label, variableBinding)
- slider (value, min, max, divisions, variableBinding)
- dropdown (options:[{label,value}], value, variableBinding)

Structure:
- list (children, scrollDirection, separator, shrinkWrap, itemExtent)
- grid (crossAxisCount, childAspectRatio, children)
- listItem (title, subtitle, leading, trailing)
- form (formId, children)
- appBar (title, actions, leading)
- bottomNav (items:[{icon,label}], currentIndex)
- divider, spacer (height, width)
- progressBar (value 0-1, color)
- chip (label, variant: filter|action|input, icon)

Overlays:
- dialog (title, content, actions), snackbar (message, action)

Plugin nodes (if installed):
- chart (chartType, data, title)
- map (latitude, longitude, zoom, markers)
- webview (url)

## UIStyle

```json
{
  "backgroundColor": "surface",
  "foregroundColor": "onSurface",
  "padding": {"all": 16},
  "margin": {"horizontal": 8, "vertical": 4},
  "width": 200,
  "height": 100,
  "fontSize": 16,
  "fontWeight": "bold",
  "borderRadius": 12,
  "borderColor": "outline",
  "borderWidth": 1,
  "opacity": 0.8,
  "elevation": 2,
  "alignment": "center",
  "flex": 1,
  "gradient": {"colors": ["primary", "secondary"], "begin": "topLeft", "end": "bottomRight"}
}
```

## Rules

1. ONLY output valid JSON. No text before or after.
2. Use semantic color tokens, not raw hex (unless custom branding).
3. Always provide variableBinding for interactive inputs.
4. Use `id` fields for dynamic elements that update between turns.
5. Keep trees flat and shallow (max depth 8 for good performance).
6. For lists > 20 items, use ListNode — the renderer virtualises them.
7. Use `condition` to show/hide nodes based on variable values.
8. Expressions in text: "Hello {{user.name}}" — resolved at render time.
''';

  String _accessibilityInstructions() => '''
## Accessibility Requirements

Always include semantics for interactive and informational elements:

1. Images: always provide `alt` text field
2. IconButtons: always provide `tooltip`
3. Form fields: always provide `label`
4. Buttons with icons only: always provide `label` or add tooltip
5. Use heading variants (headlineLarge, titleMedium) for section titles — screen readers announce these as headings
6. Don't use color alone to convey meaning — always add text/icon
7. Avoid very small touch targets — minimum 44x44dp for interactive elements
8. Mark decorative images with alt: "" to exclude from screen reader
''';

  String _variablesSection(Map<String, dynamic> vars) {
    final entries = vars.entries
        .map((e) => '  ${e.key}: ${e.value}')
        .join('\n');
    return '''
## Current Variable Store

These values are available via {{variableName}} in text and via `condition` fields:

$entries

You may reference these in your UI via expressions like "Hello {{userName}}" or set them via setVariable actions.
''';
  }
}
