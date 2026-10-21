// lib/src/schema/ui_schema.dart
//
// AgentUIKit — Core UI Schema
// ============================================================
// Defines the canonical JSON-serialisable tree that any LLM
// (or rule-based agent) produces, and that the renderer
// materialises into Flutter widgets.
//
// Design goals:
//  • Agnostic — no OpenAI / Gemini / Anthropic-specific types.
//  • Extensible — third-party components register themselves.
//  • Versionable — schema carries a semver string.
//  • Safe — unknown nodes degrade gracefully (ErrorWidget or skip).
// ============================================================

import 'dart:convert';

// ─────────────────────────────────────────────
// 1. Top-level envelope
// ─────────────────────────────────────────────

/// The root object returned by an agent turn.
/// Wraps a [UINode] tree plus metadata.
class AgentUIResponse {
  const AgentUIResponse({
    required this.schemaVersion,
    required this.root,
    this.metadata = const {},
    this.sessionId,
    this.turnId,
  });

  /// Semantic version of the UI schema used (e.g. "1.0.0").
  final String schemaVersion;

  /// Root node of the UI tree.
  final UINode root;

  /// Arbitrary key-value pairs the agent may attach (analytics, hints…).
  final Map<String, dynamic> metadata;

  final String? sessionId;
  final String? turnId;

  factory AgentUIResponse.fromJson(Map<String, dynamic> json) {
    return AgentUIResponse(
      schemaVersion: json['schemaVersion'] as String? ?? '1.0.0',
      root: UINode.fromJson(json['root'] as Map<String, dynamic>),
      metadata: (json['metadata'] as Map<String, dynamic>?) ?? {},
      sessionId: json['sessionId'] as String?,
      turnId: json['turnId'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'schemaVersion': schemaVersion,
        'root': root.toJson(),
        'metadata': metadata,
        if (sessionId != null) 'sessionId': sessionId,
        if (turnId != null) 'turnId': turnId,
      };

  factory AgentUIResponse.fromJsonString(String raw) =>
      AgentUIResponse.fromJson(json.decode(raw) as Map<String, dynamic>);

  String toJsonString() => json.encode(toJson());
}

// ─────────────────────────────────────────────
// 2. Node base class
// ─────────────────────────────────────────────

/// Base class for every node in the agent-generated UI tree.
///
/// Each node has:
///  - [type]   — component identifier (e.g. "text", "button", "card")
///  - [id]     — optional stable identifier for diff / accessibility
///  - [props]  — component-specific properties (typed subclasses below)
///  - [children] — ordered child nodes (empty for leaf nodes)
///  - [style]  — portable style overrides
///  - [actions] — declarative event → action mappings
///  - [condition] — optional visibility condition key
abstract class UINode {
  const UINode({
    required this.type,
    this.id,
    this.children = const [],
    this.style,
    this.actions = const {},
    this.condition,
  });

  final String type;
  final String? id;
  final List<UINode> children;
  final UIStyle? style;

  /// Maps event names (e.g. "onTap") to [UIAction] descriptors.
  final Map<String, UIAction> actions;

  /// If non-null, references a key in the runtime [ConditionResolver].
  final String? condition;

  Map<String, dynamic> toJson();

  /// Registry-based factory. Falls back to [UnknownNode] for unregistered
  /// types so the tree never throws during parsing.
  static UINode fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String? ?? 'unknown';
    final factory = _registry[type];
    if (factory != null) return factory(json);

    // Graceful degradation for unknown / future node types.
    return UnknownNode(type: type, rawJson: json);
  }

  // Internal registry — populated via [UINodeRegistry.register].
  static final Map<String, UINode Function(Map<String, dynamic>)> _registry =
      {};

  /// Register an external node type (called by plugins).
  ///
  /// Safe to call multiple times — later registrations win.
  // ignore: library_private_types_in_public_api
  static void registerExternal(
      String type, UINode Function(Map<String, dynamic>) factory) {
    _registry[type] = factory;
  }

  static void _registerBuiltins() {
    _registry.addAll({
      'container': (j) => ContainerNode.fromJson(j),
      'stack': (j) => StackNode.fromJson(j),
      'row': (j) => RowNode.fromJson(j),
      'column': (j) => ColumnNode.fromJson(j),
      'text': (j) => TextNode.fromJson(j),
      'richText': (j) => RichTextNode.fromJson(j),
      'image': (j) => ImageNode.fromJson(j),
      'button': (j) => ButtonNode.fromJson(j),
      'iconButton': (j) => IconButtonNode.fromJson(j),
      'textField': (j) => TextFieldNode.fromJson(j),
      'card': (j) => CardNode.fromJson(j),
      'list': (j) => ListNode.fromJson(j),
      'listItem': (j) => ListItemNode.fromJson(j),
      'grid': (j) => GridNode.fromJson(j),
      'divider': (j) => DividerNode.fromJson(j),
      'spacer': (j) => SpacerNode.fromJson(j),
      'icon': (j) => IconNode.fromJson(j),
      'badge': (j) => BadgeNode.fromJson(j),
      'chip': (j) => ChipNode.fromJson(j),
      'avatar': (j) => AvatarNode.fromJson(j),
      'progressBar': (j) => ProgressBarNode.fromJson(j),
      'switch': (j) => SwitchNode.fromJson(j),
      'slider': (j) => SliderNode.fromJson(j),
      'dropdown': (j) => DropdownNode.fromJson(j),
      'form': (j) => FormNode.fromJson(j),
      'scaffold': (j) => ScaffoldNode.fromJson(j),
      'appBar': (j) => AppBarNode.fromJson(j),
      'bottomNav': (j) => BottomNavNode.fromJson(j),
      'fab': (j) => FabNode.fromJson(j),
      'dialog': (j) => DialogNode.fromJson(j),
      'snackbar': (j) => SnackbarNode.fromJson(j),
      'markdown': (j) => MarkdownNode.fromJson(j),
      'chart': (j) => ChartNode.fromJson(j),
      'map': (j) => MapNode.fromJson(j),
      'webview': (j) => WebViewNode.fromJson(j),
      'custom': (j) => CustomNode.fromJson(j),
      // ── New node types registered as UnknownNode until plugins load ──
      // Plugins call registerExternal() in their initialize() to override.
      'diagram': (j) => UnknownNode(type: 'diagram', rawJson: j),
      'tenun_chart': (j) => UnknownNode(type: 'tenun_chart', rawJson: j),
      'workflow': (j) => UnknownNode(type: 'workflow', rawJson: j),
      'workspace': (j) => UnknownNode(type: 'workspace', rawJson: j),
      'document': (j) => UnknownNode(type: 'document', rawJson: j),
      'shape': (j) => UnknownNode(type: 'shape', rawJson: j),
      'component': (j) => UnknownNode(type: 'component', rawJson: j),
      'template': (j) => UnknownNode(type: 'template', rawJson: j),
    });
  }
}

// ─────────────────────────────────────────────
// 3. Style
// ─────────────────────────────────────────────

class UIStyle {
  const UIStyle({
    this.backgroundColor,
    this.foregroundColor,
    this.borderColor,
    this.borderRadius,
    this.borderWidth,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.minWidth,
    this.maxWidth,
    this.minHeight,
    this.maxHeight,
    this.opacity,
    this.elevation,
    this.fontSize,
    this.fontWeight,
    this.fontFamily,
    this.letterSpacing,
    this.lineHeight,
    this.textAlign,
    this.overflow,
    this.flex,
    this.alignment,
    this.shadow,
    this.gradient,
  });

  final String? backgroundColor; // CSS hex / named colour
  final String? foregroundColor;
  final String? borderColor;
  final double? borderRadius;
  final double? borderWidth;
  final UIInsets? padding;
  final UIInsets? margin;
  final double? width;
  final double? height;
  final double? minWidth;
  final double? maxWidth;
  final double? minHeight;
  final double? maxHeight;
  final double? opacity;
  final double? elevation;
  final double? fontSize;
  final String? fontWeight; // "normal" | "bold" | "w100"…"w900"
  final String? fontFamily;
  final double? letterSpacing;
  final double? lineHeight;
  final String? textAlign; // "left" | "center" | "right" | "justify"
  final String? overflow; // "clip" | "ellipsis" | "fade" | "visible"
  final int? flex;
  final String? alignment; // "topLeft" | "center" | "bottomRight" …
  final UIShadow? shadow;
  final UIGradient? gradient;

  factory UIStyle.fromJson(Map<String, dynamic> j) => UIStyle(
        backgroundColor: j['backgroundColor'] as String?,
        foregroundColor: j['foregroundColor'] as String?,
        borderColor: j['borderColor'] as String?,
        borderRadius: (j['borderRadius'] as num?)?.toDouble(),
        borderWidth: (j['borderWidth'] as num?)?.toDouble(),
        padding: j['padding'] != null
            ? UIInsets.fromJson(j['padding'] as Map<String, dynamic>)
            : null,
        margin: j['margin'] != null
            ? UIInsets.fromJson(j['margin'] as Map<String, dynamic>)
            : null,
        width: (j['width'] as num?)?.toDouble(),
        height: (j['height'] as num?)?.toDouble(),
        minWidth: (j['minWidth'] as num?)?.toDouble(),
        maxWidth: (j['maxWidth'] as num?)?.toDouble(),
        minHeight: (j['minHeight'] as num?)?.toDouble(),
        maxHeight: (j['maxHeight'] as num?)?.toDouble(),
        opacity: (j['opacity'] as num?)?.toDouble(),
        elevation: (j['elevation'] as num?)?.toDouble(),
        fontSize: (j['fontSize'] as num?)?.toDouble(),
        fontWeight: j['fontWeight'] as String?,
        fontFamily: j['fontFamily'] as String?,
        letterSpacing: (j['letterSpacing'] as num?)?.toDouble(),
        lineHeight: (j['lineHeight'] as num?)?.toDouble(),
        textAlign: j['textAlign'] as String?,
        overflow: j['overflow'] as String?,
        flex: j['flex'] as int?,
        alignment: j['alignment'] as String?,
        shadow: j['shadow'] != null
            ? UIShadow.fromJson(j['shadow'] as Map<String, dynamic>)
            : null,
        gradient: j['gradient'] != null
            ? UIGradient.fromJson(j['gradient'] as Map<String, dynamic>)
            : null,
      );

  Map<String, dynamic> toJson() => {
        if (backgroundColor != null) 'backgroundColor': backgroundColor,
        if (foregroundColor != null) 'foregroundColor': foregroundColor,
        if (borderColor != null) 'borderColor': borderColor,
        if (borderRadius != null) 'borderRadius': borderRadius,
        if (borderWidth != null) 'borderWidth': borderWidth,
        if (padding != null) 'padding': padding!.toJson(),
        if (margin != null) 'margin': margin!.toJson(),
        if (width != null) 'width': width,
        if (height != null) 'height': height,
        if (opacity != null) 'opacity': opacity,
        if (elevation != null) 'elevation': elevation,
        if (fontSize != null) 'fontSize': fontSize,
        if (fontWeight != null) 'fontWeight': fontWeight,
        if (fontFamily != null) 'fontFamily': fontFamily,
        if (letterSpacing != null) 'letterSpacing': letterSpacing,
        if (lineHeight != null) 'lineHeight': lineHeight,
        if (textAlign != null) 'textAlign': textAlign,
        if (overflow != null) 'overflow': overflow,
        if (flex != null) 'flex': flex,
        if (alignment != null) 'alignment': alignment,
        if (shadow != null) 'shadow': shadow!.toJson(),
        if (gradient != null) 'gradient': gradient!.toJson(),
      };
}

class UIInsets {
  const UIInsets({this.top, this.right, this.bottom, this.left, this.all});

  final double? top, right, bottom, left, all;

  factory UIInsets.fromJson(Map<String, dynamic> j) {
    final all = (j['all'] as num?)?.toDouble();
    return UIInsets(
      all: all,
      top: (j['top'] as num?)?.toDouble() ?? all,
      right: (j['right'] as num?)?.toDouble() ?? all,
      bottom: (j['bottom'] as num?)?.toDouble() ?? all,
      left: (j['left'] as num?)?.toDouble() ?? all,
    );
  }

  Map<String, dynamic> toJson() => {
        if (all != null) 'all': all,
        if (top != null) 'top': top,
        if (right != null) 'right': right,
        if (bottom != null) 'bottom': bottom,
        if (left != null) 'left': left,
      };
}

class UIShadow {
  const UIShadow({this.color, this.blurRadius, this.offsetX, this.offsetY});

  final String? color;
  final double? blurRadius;
  final double? offsetX;
  final double? offsetY;

  factory UIShadow.fromJson(Map<String, dynamic> j) => UIShadow(
        color: j['color'] as String?,
        blurRadius: (j['blurRadius'] as num?)?.toDouble(),
        offsetX: (j['offsetX'] as num?)?.toDouble(),
        offsetY: (j['offsetY'] as num?)?.toDouble(),
      );

  Map<String, dynamic> toJson() => {
        if (color != null) 'color': color,
        if (blurRadius != null) 'blurRadius': blurRadius,
        if (offsetX != null) 'offsetX': offsetX,
        if (offsetY != null) 'offsetY': offsetY,
      };
}

class UIGradient {
  const UIGradient({
    required this.type,
    required this.colors,
    this.stops,
    this.angle,
  });

  final String type; // "linear" | "radial"
  final List<String> colors;
  final List<double>? stops;
  final double? angle;

  factory UIGradient.fromJson(Map<String, dynamic> j) => UIGradient(
        type: j['type'] as String? ?? 'linear',
        colors: List<String>.from(j['colors'] as List),
        stops: j['stops'] != null
            ? List<double>.from(
                (j['stops'] as List).map((e) => (e as num).toDouble()))
            : null,
        angle: (j['angle'] as num?)?.toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'type': type,
        'colors': colors,
        if (stops != null) 'stops': stops,
        if (angle != null) 'angle': angle,
      };
}

// ─────────────────────────────────────────────
// 4. Actions
// ─────────────────────────────────────────────

/// Declarative description of what happens on an event.
/// The runtime [ActionDispatcher] interprets these.
class UIAction {
  const UIAction({
    required this.type,
    this.payload = const {},
  });

  /// Built-in types: "agentMessage", "navigate", "setVariable",
  ///                 "openUrl", "dismiss", "custom"
  final String type;
  final Map<String, dynamic> payload;

  factory UIAction.fromJson(Map<String, dynamic> j) => UIAction(
        type: j['type'] as String,
        payload: (j['payload'] as Map<String, dynamic>?) ?? {},
      );

  Map<String, dynamic> toJson() => {'type': type, 'payload': payload};
}

// ─────────────────────────────────────────────
// 5. Concrete node types
// ─────────────────────────────────────────────

List<UINode> _parseChildren(Map<String, dynamic> j) {
  final raw = j['children'] as List<dynamic>?;
  if (raw == null) return const [];
  return raw
      .map((e) => UINode.fromJson(e as Map<String, dynamic>))
      .toList(growable: false);
}

UIStyle? _parseStyle(Map<String, dynamic> j) {
  final s = j['style'] as Map<String, dynamic>?;
  return s == null ? null : UIStyle.fromJson(s);
}

Map<String, UIAction> _parseActions(Map<String, dynamic> j) {
  final raw = j['actions'] as Map<String, dynamic>?;
  if (raw == null) return const {};
  return raw
      .map((k, v) => MapEntry(k, UIAction.fromJson(v as Map<String, dynamic>)));
}

mixin _NodeJsonBase on UINode {
  Map<String, dynamic> _baseJson() => {
        'type': type,
        if (id != null) 'id': id,
        if (style != null) 'style': style!.toJson(),
        if (actions.isNotEmpty)
          'actions': actions.map((k, v) => MapEntry(k, v.toJson())),
        if (condition != null) 'condition': condition,
      };
}

// ── Layout ──────────────────────────────────

class ContainerNode extends UINode with _NodeJsonBase {
  ContainerNode({
    super.id,
    super.children,
    super.style,
    super.actions,
    super.condition,
    this.clipBehavior,
  }) : super(type: 'container');

  final String? clipBehavior; // "none" | "hardEdge" | "antiAlias"

  factory ContainerNode.fromJson(Map<String, dynamic> j) => ContainerNode(
        id: j['id'] as String?,
        children: _parseChildren(j),
        style: _parseStyle(j),
        actions: _parseActions(j),
        condition: j['condition'] as String?,
        clipBehavior: j['clipBehavior'] as String?,
      );

  @override
  Map<String, dynamic> toJson() => {
        ..._baseJson(),
        if (clipBehavior != null) 'clipBehavior': clipBehavior,
        if (children.isNotEmpty)
          'children': children.map((c) => c.toJson()).toList(),
      };
}

class RowNode extends UINode with _NodeJsonBase {
  RowNode({
    super.id,
    super.children,
    super.style,
    super.actions,
    super.condition,
    this.mainAxisAlignment,
    this.crossAxisAlignment,
    this.mainAxisSize,
  }) : super(type: 'row');

  final String? mainAxisAlignment;
  final String? crossAxisAlignment;
  final String? mainAxisSize;

  factory RowNode.fromJson(Map<String, dynamic> j) => RowNode(
        id: j['id'] as String?,
        children: _parseChildren(j),
        style: _parseStyle(j),
        actions: _parseActions(j),
        condition: j['condition'] as String?,
        mainAxisAlignment: j['mainAxisAlignment'] as String?,
        crossAxisAlignment: j['crossAxisAlignment'] as String?,
        mainAxisSize: j['mainAxisSize'] as String?,
      );

  @override
  Map<String, dynamic> toJson() => {
        ..._baseJson(),
        if (mainAxisAlignment != null) 'mainAxisAlignment': mainAxisAlignment,
        if (crossAxisAlignment != null)
          'crossAxisAlignment': crossAxisAlignment,
        if (mainAxisSize != null) 'mainAxisSize': mainAxisSize,
        if (children.isNotEmpty)
          'children': children.map((c) => c.toJson()).toList(),
      };
}

class ColumnNode extends UINode with _NodeJsonBase {
  ColumnNode({
    super.id,
    super.children,
    super.style,
    super.actions,
    super.condition,
    this.mainAxisAlignment,
    this.crossAxisAlignment,
    this.mainAxisSize,
  }) : super(type: 'column');

  final String? mainAxisAlignment;
  final String? crossAxisAlignment;
  final String? mainAxisSize;

  factory ColumnNode.fromJson(Map<String, dynamic> j) => ColumnNode(
        id: j['id'] as String?,
        children: _parseChildren(j),
        style: _parseStyle(j),
        actions: _parseActions(j),
        condition: j['condition'] as String?,
        mainAxisAlignment: j['mainAxisAlignment'] as String?,
        crossAxisAlignment: j['crossAxisAlignment'] as String?,
        mainAxisSize: j['mainAxisSize'] as String?,
      );

  @override
  Map<String, dynamic> toJson() => {
        ..._baseJson(),
        if (mainAxisAlignment != null) 'mainAxisAlignment': mainAxisAlignment,
        if (crossAxisAlignment != null)
          'crossAxisAlignment': crossAxisAlignment,
        if (mainAxisSize != null) 'mainAxisSize': mainAxisSize,
        if (children.isNotEmpty)
          'children': children.map((c) => c.toJson()).toList(),
      };
}

class StackNode extends UINode with _NodeJsonBase {
  StackNode({
    super.id,
    super.children,
    super.style,
    super.actions,
    super.condition,
    this.alignment,
    this.fit,
  }) : super(type: 'stack');

  final String? alignment;
  final String? fit; // "loose" | "expand" | "passthrough"

  factory StackNode.fromJson(Map<String, dynamic> j) => StackNode(
        id: j['id'] as String?,
        children: _parseChildren(j),
        style: _parseStyle(j),
        actions: _parseActions(j),
        condition: j['condition'] as String?,
        alignment: j['alignment'] as String?,
        fit: j['fit'] as String?,
      );

  @override
  Map<String, dynamic> toJson() => {
        ..._baseJson(),
        if (alignment != null) 'alignment': alignment,
        if (fit != null) 'fit': fit,
        if (children.isNotEmpty)
          'children': children.map((c) => c.toJson()).toList(),
      };
}

// ── Content ──────────────────────────────────

class TextNode extends UINode with _NodeJsonBase {
  TextNode({
    super.id,
    super.style,
    super.actions,
    super.condition,
    required this.text,
    this.variant,
    this.selectable,
  }) : super(type: 'text', children: const []);

  final String text;

  /// Material typography variant: "displayLarge" | "headlineMedium" | "body1"…
  final String? variant;
  final bool? selectable;

  factory TextNode.fromJson(Map<String, dynamic> j) => TextNode(
        id: j['id'] as String?,
        style: _parseStyle(j),
        actions: _parseActions(j),
        condition: j['condition'] as String?,
        text: j['text'] as String? ?? '',
        variant: j['variant'] as String?,
        selectable: j['selectable'] as bool?,
      );

  @override
  Map<String, dynamic> toJson() => {
        ..._baseJson(),
        'text': text,
        if (variant != null) 'variant': variant,
        if (selectable != null) 'selectable': selectable,
      };
}

class RichTextNode extends UINode with _NodeJsonBase {
  RichTextNode({
    super.id,
    super.style,
    super.actions,
    super.condition,
    required this.spans,
  }) : super(type: 'richText', children: const []);

  final List<TextSpanData> spans;

  factory RichTextNode.fromJson(Map<String, dynamic> j) => RichTextNode(
        id: j['id'] as String?,
        style: _parseStyle(j),
        actions: _parseActions(j),
        condition: j['condition'] as String?,
        spans: (j['spans'] as List<dynamic>? ?? [])
            .map((e) => TextSpanData.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  @override
  Map<String, dynamic> toJson() => {
        ..._baseJson(),
        'spans': spans.map((s) => s.toJson()).toList(),
      };
}

class TextSpanData {
  const TextSpanData({required this.text, this.style, this.actionOnTap});

  final String text;
  final UIStyle? style;
  final UIAction? actionOnTap;

  factory TextSpanData.fromJson(Map<String, dynamic> j) => TextSpanData(
        text: j['text'] as String? ?? '',
        style: j['style'] != null
            ? UIStyle.fromJson(j['style'] as Map<String, dynamic>)
            : null,
        actionOnTap: j['actionOnTap'] != null
            ? UIAction.fromJson(j['actionOnTap'] as Map<String, dynamic>)
            : null,
      );

  Map<String, dynamic> toJson() => {
        'text': text,
        if (style != null) 'style': style!.toJson(),
        if (actionOnTap != null) 'actionOnTap': actionOnTap!.toJson(),
      };
}

class ImageNode extends UINode with _NodeJsonBase {
  ImageNode({
    super.id,
    super.style,
    super.actions,
    super.condition,
    required this.src,
    this.fit,
    this.alt,
    this.srcType,
  }) : super(type: 'image', children: const []);

  /// URL, asset path, or base64 data URI.
  final String src;

  /// "network" | "asset" | "base64" — auto-detected from [src] if omitted.
  final String? srcType;
  final String? fit; // "cover" | "contain" | "fill" | "fitWidth" | "fitHeight"
  final String? alt;

  factory ImageNode.fromJson(Map<String, dynamic> j) => ImageNode(
        id: j['id'] as String?,
        style: _parseStyle(j),
        actions: _parseActions(j),
        condition: j['condition'] as String?,
        src: j['src'] as String? ?? '',
        srcType: j['srcType'] as String?,
        fit: j['fit'] as String?,
        alt: j['alt'] as String?,
      );

  @override
  Map<String, dynamic> toJson() => {
        ..._baseJson(),
        'src': src,
        if (srcType != null) 'srcType': srcType,
        if (fit != null) 'fit': fit,
        if (alt != null) 'alt': alt,
      };
}

class IconNode extends UINode with _NodeJsonBase {
  IconNode({
    super.id,
    super.style,
    super.actions,
    super.condition,
    required this.icon,
    this.size,
    this.color,
    this.package,
  }) : super(type: 'icon', children: const []);

  /// Icon identifier — e.g. "home", "star_outlined" (Maps to MaterialIcons).
  final String icon;
  final double? size;
  final String? color;

  /// For custom icon packages (e.g. "font_awesome_flutter").
  final String? package;

  factory IconNode.fromJson(Map<String, dynamic> j) => IconNode(
        id: j['id'] as String?,
        style: _parseStyle(j),
        actions: _parseActions(j),
        condition: j['condition'] as String?,
        icon: j['icon'] as String? ?? 'help_outline',
        size: (j['size'] as num?)?.toDouble(),
        color: j['color'] as String?,
        package: j['package'] as String?,
      );

  @override
  Map<String, dynamic> toJson() => {
        ..._baseJson(),
        'icon': icon,
        if (size != null) 'size': size,
        if (color != null) 'color': color,
        if (package != null) 'package': package,
      };
}

class MarkdownNode extends UINode with _NodeJsonBase {
  MarkdownNode({
    super.id,
    super.style,
    super.actions,
    super.condition,
    required this.content,
  }) : super(type: 'markdown', children: const []);

  final String content;

  factory MarkdownNode.fromJson(Map<String, dynamic> j) => MarkdownNode(
        id: j['id'] as String?,
        style: _parseStyle(j),
        actions: _parseActions(j),
        condition: j['condition'] as String?,
        content: j['content'] as String? ?? '',
      );

  @override
  Map<String, dynamic> toJson() => {
        ..._baseJson(),
        'content': content,
      };
}

// ── Interactive ──────────────────────────────

class ButtonNode extends UINode with _NodeJsonBase {
  ButtonNode({
    super.id,
    super.style,
    super.actions,
    super.condition,
    super.children,
    this.label,
    this.variant,
    this.icon,
    this.disabled,
    this.loading,
  }) : super(type: 'button');

  final String? label;

  /// "elevated" | "filled" | "outlined" | "text" | "tonal"
  final String? variant;
  final String? icon;
  final bool? disabled;
  final bool? loading;

  factory ButtonNode.fromJson(Map<String, dynamic> j) => ButtonNode(
        id: j['id'] as String?,
        style: _parseStyle(j),
        actions: _parseActions(j),
        condition: j['condition'] as String?,
        children: _parseChildren(j),
        label: j['label'] as String?,
        variant: j['variant'] as String?,
        icon: j['icon'] as String?,
        disabled: j['disabled'] as bool?,
        loading: j['loading'] as bool?,
      );

  @override
  Map<String, dynamic> toJson() => {
        ..._baseJson(),
        if (label != null) 'label': label,
        if (variant != null) 'variant': variant,
        if (icon != null) 'icon': icon,
        if (disabled != null) 'disabled': disabled,
        if (loading != null) 'loading': loading,
        if (children.isNotEmpty)
          'children': children.map((c) => c.toJson()).toList(),
      };
}

class IconButtonNode extends UINode with _NodeJsonBase {
  IconButtonNode({
    super.id,
    super.style,
    super.actions,
    super.condition,
    required this.icon,
    this.tooltip,
    this.disabled,
  }) : super(type: 'iconButton', children: const []);

  final String icon;
  final String? tooltip;
  final bool? disabled;

  factory IconButtonNode.fromJson(Map<String, dynamic> j) => IconButtonNode(
        id: j['id'] as String?,
        style: _parseStyle(j),
        actions: _parseActions(j),
        condition: j['condition'] as String?,
        icon: j['icon'] as String? ?? 'help_outline',
        tooltip: j['tooltip'] as String?,
        disabled: j['disabled'] as bool?,
      );

  @override
  Map<String, dynamic> toJson() => {
        ..._baseJson(),
        'icon': icon,
        if (tooltip != null) 'tooltip': tooltip,
        if (disabled != null) 'disabled': disabled,
      };
}

class TextFieldNode extends UINode with _NodeJsonBase {
  TextFieldNode({
    super.id,
    super.style,
    super.actions,
    super.condition,
    this.label,
    this.placeholder,
    this.value,
    this.inputType,
    this.multiline,
    this.maxLines,
    this.minLines,
    this.required,
    this.disabled,
    this.obscureText,
    this.prefixIcon,
    this.suffixIcon,
    this.helperText,
    this.errorText,
    this.variableBinding,
  }) : super(type: 'textField', children: const []);

  final String? label;
  final String? placeholder;
  final String? value;

  /// "text" | "number" | "email" | "phone" | "url" | "password"
  final String? inputType;
  final bool? multiline;
  final int? maxLines;
  final int? minLines;
  final bool? required;
  final bool? disabled;
  final bool? obscureText;
  final String? prefixIcon;
  final String? suffixIcon;
  final String? helperText;
  final String? errorText;

  /// Key name in the [VariableStore] this field reads/writes.
  final String? variableBinding;

  factory TextFieldNode.fromJson(Map<String, dynamic> j) => TextFieldNode(
        id: j['id'] as String?,
        style: _parseStyle(j),
        actions: _parseActions(j),
        condition: j['condition'] as String?,
        label: j['label'] as String?,
        placeholder: j['placeholder'] as String?,
        value: j['value'] as String?,
        inputType: j['inputType'] as String?,
        multiline: j['multiline'] as bool?,
        maxLines: j['maxLines'] as int?,
        minLines: j['minLines'] as int?,
        required: j['required'] as bool?,
        disabled: j['disabled'] as bool?,
        obscureText: j['obscureText'] as bool?,
        prefixIcon: j['prefixIcon'] as String?,
        suffixIcon: j['suffixIcon'] as String?,
        helperText: j['helperText'] as String?,
        errorText: j['errorText'] as String?,
        variableBinding: j['variableBinding'] as String?,
      );

  @override
  Map<String, dynamic> toJson() => {
        ..._baseJson(),
        if (label != null) 'label': label,
        if (placeholder != null) 'placeholder': placeholder,
        if (value != null) 'value': value,
        if (inputType != null) 'inputType': inputType,
        if (multiline != null) 'multiline': multiline,
        if (maxLines != null) 'maxLines': maxLines,
        if (disabled != null) 'disabled': disabled,
        if (variableBinding != null) 'variableBinding': variableBinding,
      };
}

class SwitchNode extends UINode with _NodeJsonBase {
  SwitchNode({
    super.id,
    super.style,
    super.actions,
    super.condition,
    required this.value,
    this.label,
    this.variableBinding,
  }) : super(type: 'switch', children: const []);

  final bool value;
  final String? label;
  final String? variableBinding;

  factory SwitchNode.fromJson(Map<String, dynamic> j) => SwitchNode(
        id: j['id'] as String?,
        style: _parseStyle(j),
        actions: _parseActions(j),
        condition: j['condition'] as String?,
        value: j['value'] as bool? ?? false,
        label: j['label'] as String?,
        variableBinding: j['variableBinding'] as String?,
      );

  @override
  Map<String, dynamic> toJson() => {
        ..._baseJson(),
        'value': value,
        if (label != null) 'label': label,
        if (variableBinding != null) 'variableBinding': variableBinding,
      };
}

class SliderNode extends UINode with _NodeJsonBase {
  SliderNode({
    super.id,
    super.style,
    super.actions,
    super.condition,
    required this.value,
    this.min,
    this.max,
    this.divisions,
    this.label,
    this.variableBinding,
  }) : super(type: 'slider', children: const []);

  final double value;
  final double? min;
  final double? max;
  final int? divisions;
  final String? label;
  final String? variableBinding;

  factory SliderNode.fromJson(Map<String, dynamic> j) => SliderNode(
        id: j['id'] as String?,
        style: _parseStyle(j),
        actions: _parseActions(j),
        condition: j['condition'] as String?,
        value: (j['value'] as num?)?.toDouble() ?? 0,
        min: (j['min'] as num?)?.toDouble(),
        max: (j['max'] as num?)?.toDouble(),
        divisions: j['divisions'] as int?,
        label: j['label'] as String?,
        variableBinding: j['variableBinding'] as String?,
      );

  @override
  Map<String, dynamic> toJson() => {
        ..._baseJson(),
        'value': value,
        if (min != null) 'min': min,
        if (max != null) 'max': max,
        if (divisions != null) 'divisions': divisions,
        if (label != null) 'label': label,
        if (variableBinding != null) 'variableBinding': variableBinding,
      };
}

class DropdownNode extends UINode with _NodeJsonBase {
  DropdownNode({
    super.id,
    super.style,
    super.actions,
    super.condition,
    required this.options,
    this.value,
    this.label,
    this.variableBinding,
  }) : super(type: 'dropdown', children: const []);

  final List<DropdownOption> options;
  final String? value;
  final String? label;
  final String? variableBinding;

  factory DropdownNode.fromJson(Map<String, dynamic> j) => DropdownNode(
        id: j['id'] as String?,
        style: _parseStyle(j),
        actions: _parseActions(j),
        condition: j['condition'] as String?,
        options: (j['options'] as List<dynamic>? ?? [])
            .map((e) => DropdownOption.fromJson(e as Map<String, dynamic>))
            .toList(),
        value: j['value'] as String?,
        label: j['label'] as String?,
        variableBinding: j['variableBinding'] as String?,
      );

  @override
  Map<String, dynamic> toJson() => {
        ..._baseJson(),
        'options': options.map((o) => o.toJson()).toList(),
        if (value != null) 'value': value,
        if (label != null) 'label': label,
        if (variableBinding != null) 'variableBinding': variableBinding,
      };
}

class DropdownOption {
  const DropdownOption({required this.label, required this.value});

  final String label;
  final String value;

  factory DropdownOption.fromJson(Map<String, dynamic> j) => DropdownOption(
        label: j['label'] as String? ?? '',
        value: j['value'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {'label': label, 'value': value};
}

// ── Structural ───────────────────────────────

class CardNode extends UINode with _NodeJsonBase {
  CardNode({
    super.id,
    super.children,
    super.style,
    super.actions,
    super.condition,
    this.elevation,
    this.borderRadius,
  }) : super(type: 'card');

  final double? elevation;
  final double? borderRadius;

  factory CardNode.fromJson(Map<String, dynamic> j) => CardNode(
        id: j['id'] as String?,
        children: _parseChildren(j),
        style: _parseStyle(j),
        actions: _parseActions(j),
        condition: j['condition'] as String?,
        elevation: (j['elevation'] as num?)?.toDouble(),
        borderRadius: (j['borderRadius'] as num?)?.toDouble(),
      );

  @override
  Map<String, dynamic> toJson() => {
        ..._baseJson(),
        if (elevation != null) 'elevation': elevation,
        if (borderRadius != null) 'borderRadius': borderRadius,
        if (children.isNotEmpty)
          'children': children.map((c) => c.toJson()).toList(),
      };
}

class ListNode extends UINode with _NodeJsonBase {
  ListNode({
    super.id,
    super.children,
    super.style,
    super.actions,
    super.condition,
    this.scrollDirection,
    this.shrinkWrap,
    this.itemExtent,
    this.separator,
  }) : super(type: 'list');

  final String? scrollDirection; // "vertical" | "horizontal"
  final bool? shrinkWrap;
  final double? itemExtent;
  final UINode? separator;

  factory ListNode.fromJson(Map<String, dynamic> j) => ListNode(
        id: j['id'] as String?,
        children: _parseChildren(j),
        style: _parseStyle(j),
        actions: _parseActions(j),
        condition: j['condition'] as String?,
        scrollDirection: j['scrollDirection'] as String?,
        shrinkWrap: j['shrinkWrap'] as bool?,
        itemExtent: (j['itemExtent'] as num?)?.toDouble(),
        separator: j['separator'] != null
            ? UINode.fromJson(j['separator'] as Map<String, dynamic>)
            : null,
      );

  @override
  Map<String, dynamic> toJson() => {
        ..._baseJson(),
        if (scrollDirection != null) 'scrollDirection': scrollDirection,
        if (shrinkWrap != null) 'shrinkWrap': shrinkWrap,
        if (itemExtent != null) 'itemExtent': itemExtent,
        if (separator != null) 'separator': separator!.toJson(),
        if (children.isNotEmpty)
          'children': children.map((c) => c.toJson()).toList(),
      };
}

class ListItemNode extends UINode with _NodeJsonBase {
  ListItemNode({
    super.id,
    super.children,
    super.style,
    super.actions,
    super.condition,
    this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.selected,
  }) : super(type: 'listItem');

  final UINode? title;
  final UINode? subtitle;
  final UINode? leading;
  final UINode? trailing;
  final bool? selected;

  factory ListItemNode.fromJson(Map<String, dynamic> j) {
    UINode? parseOptional(String key) {
      final raw = j[key] as Map<String, dynamic>?;
      return raw != null ? UINode.fromJson(raw) : null;
    }

    return ListItemNode(
      id: j['id'] as String?,
      children: _parseChildren(j),
      style: _parseStyle(j),
      actions: _parseActions(j),
      condition: j['condition'] as String?,
      title: parseOptional('title'),
      subtitle: parseOptional('subtitle'),
      leading: parseOptional('leading'),
      trailing: parseOptional('trailing'),
      selected: j['selected'] as bool?,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        ..._baseJson(),
        if (title != null) 'title': title!.toJson(),
        if (subtitle != null) 'subtitle': subtitle!.toJson(),
        if (leading != null) 'leading': leading!.toJson(),
        if (trailing != null) 'trailing': trailing!.toJson(),
        if (selected != null) 'selected': selected,
      };
}

class GridNode extends UINode with _NodeJsonBase {
  GridNode({
    super.id,
    super.children,
    super.style,
    super.actions,
    super.condition,
    this.crossAxisCount,
    this.childAspectRatio,
    this.mainAxisSpacing,
    this.crossAxisSpacing,
  }) : super(type: 'grid');

  final int? crossAxisCount;
  final double? childAspectRatio;
  final double? mainAxisSpacing;
  final double? crossAxisSpacing;

  factory GridNode.fromJson(Map<String, dynamic> j) => GridNode(
        id: j['id'] as String?,
        children: _parseChildren(j),
        style: _parseStyle(j),
        actions: _parseActions(j),
        condition: j['condition'] as String?,
        crossAxisCount: j['crossAxisCount'] as int?,
        childAspectRatio: (j['childAspectRatio'] as num?)?.toDouble(),
        mainAxisSpacing: (j['mainAxisSpacing'] as num?)?.toDouble(),
        crossAxisSpacing: (j['crossAxisSpacing'] as num?)?.toDouble(),
      );

  @override
  Map<String, dynamic> toJson() => {
        ..._baseJson(),
        if (crossAxisCount != null) 'crossAxisCount': crossAxisCount,
        if (childAspectRatio != null) 'childAspectRatio': childAspectRatio,
        if (mainAxisSpacing != null) 'mainAxisSpacing': mainAxisSpacing,
        if (crossAxisSpacing != null) 'crossAxisSpacing': crossAxisSpacing,
        if (children.isNotEmpty)
          'children': children.map((c) => c.toJson()).toList(),
      };
}

class FormNode extends UINode with _NodeJsonBase {
  FormNode({
    super.id,
    super.children,
    super.style,
    super.actions,
    super.condition,
    this.submitAction,
  }) : super(type: 'form');

  final UIAction? submitAction;

  factory FormNode.fromJson(Map<String, dynamic> j) => FormNode(
        id: j['id'] as String?,
        children: _parseChildren(j),
        style: _parseStyle(j),
        actions: _parseActions(j),
        condition: j['condition'] as String?,
        submitAction: j['submitAction'] != null
            ? UIAction.fromJson(j['submitAction'] as Map<String, dynamic>)
            : null,
      );

  @override
  Map<String, dynamic> toJson() => {
        ..._baseJson(),
        if (submitAction != null) 'submitAction': submitAction!.toJson(),
        if (children.isNotEmpty)
          'children': children.map((c) => c.toJson()).toList(),
      };
}

// ── Scaffold / Navigation ─────────────────────

class ScaffoldNode extends UINode with _NodeJsonBase {
  ScaffoldNode({
    super.id,
    super.style,
    super.actions,
    super.condition,
    this.appBar,
    this.body,
    this.bottomNav,
    this.fab,
    this.drawer,
    this.backgroundColor,
  }) : super(type: 'scaffold', children: const []);

  final AppBarNode? appBar;
  final UINode? body;
  final BottomNavNode? bottomNav;
  final FabNode? fab;
  final UINode? drawer;
  final String? backgroundColor;

  factory ScaffoldNode.fromJson(Map<String, dynamic> j) => ScaffoldNode(
        id: j['id'] as String?,
        style: _parseStyle(j),
        actions: _parseActions(j),
        condition: j['condition'] as String?,
        appBar: j['appBar'] != null
            ? AppBarNode.fromJson(j['appBar'] as Map<String, dynamic>)
            : null,
        body: j['body'] != null
            ? UINode.fromJson(j['body'] as Map<String, dynamic>)
            : null,
        bottomNav: j['bottomNav'] != null
            ? BottomNavNode.fromJson(j['bottomNav'] as Map<String, dynamic>)
            : null,
        fab: j['fab'] != null
            ? FabNode.fromJson(j['fab'] as Map<String, dynamic>)
            : null,
        drawer: j['drawer'] != null
            ? UINode.fromJson(j['drawer'] as Map<String, dynamic>)
            : null,
        backgroundColor: j['backgroundColor'] as String?,
      );

  @override
  Map<String, dynamic> toJson() => {
        ..._baseJson(),
        if (appBar != null) 'appBar': appBar!.toJson(),
        if (body != null) 'body': body!.toJson(),
        if (bottomNav != null) 'bottomNav': bottomNav!.toJson(),
        if (fab != null) 'fab': fab!.toJson(),
        if (drawer != null) 'drawer': drawer!.toJson(),
        if (backgroundColor != null) 'backgroundColor': backgroundColor,
      };
}

class AppBarNode extends UINode with _NodeJsonBase {
  AppBarNode({
    super.id,
    super.style,
    super.actions,
    this.title,
    this.leading,
    this.actions_nodes,
    this.backgroundColor,
    this.centerTitle,
    this.elevation,
  }) : super(type: 'appBar', children: const []);

  final UINode? title;
  final UINode? leading;
  final List<UINode>? actions_nodes;
  final String? backgroundColor;
  final bool? centerTitle;
  final double? elevation;

  factory AppBarNode.fromJson(Map<String, dynamic> j) => AppBarNode(
        id: j['id'] as String?,
        style: _parseStyle(j),
        actions: _parseActions(j),
        title: j['title'] != null
            ? UINode.fromJson(j['title'] as Map<String, dynamic>)
            : null,
        leading: j['leading'] != null
            ? UINode.fromJson(j['leading'] as Map<String, dynamic>)
            : null,
        actions_nodes: (j['actionNodes'] as List<dynamic>?)
            ?.map((e) => UINode.fromJson(e as Map<String, dynamic>))
            .toList(),
        backgroundColor: j['backgroundColor'] as String?,
        centerTitle: j['centerTitle'] as bool?,
        elevation: (j['elevation'] as num?)?.toDouble(),
      );

  @override
  Map<String, dynamic> toJson() => {
        ..._baseJson(),
        if (title != null) 'title': title!.toJson(),
        if (leading != null) 'leading': leading!.toJson(),
        if (actions_nodes != null)
          'actionNodes': actions_nodes!.map((n) => n.toJson()).toList(),
        if (backgroundColor != null) 'backgroundColor': backgroundColor,
        if (centerTitle != null) 'centerTitle': centerTitle,
        if (elevation != null) 'elevation': elevation,
      };
}

class BottomNavNode extends UINode with _NodeJsonBase {
  BottomNavNode({
    super.id,
    super.style,
    super.actions,
    required this.items,
    this.currentIndex,
    this.backgroundColor,
  }) : super(type: 'bottomNav', children: const []);

  final List<BottomNavItem> items;
  final int? currentIndex;
  final String? backgroundColor;

  factory BottomNavNode.fromJson(Map<String, dynamic> j) => BottomNavNode(
        id: j['id'] as String?,
        style: _parseStyle(j),
        actions: _parseActions(j),
        items: (j['items'] as List<dynamic>? ?? [])
            .map((e) => BottomNavItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        currentIndex: j['currentIndex'] as int?,
        backgroundColor: j['backgroundColor'] as String?,
      );

  @override
  Map<String, dynamic> toJson() => {
        ..._baseJson(),
        'items': items.map((i) => i.toJson()).toList(),
        if (currentIndex != null) 'currentIndex': currentIndex,
        if (backgroundColor != null) 'backgroundColor': backgroundColor,
      };
}

class BottomNavItem {
  const BottomNavItem({required this.icon, this.label, this.activeIcon});

  final String icon;
  final String? label;
  final String? activeIcon;

  factory BottomNavItem.fromJson(Map<String, dynamic> j) => BottomNavItem(
        icon: j['icon'] as String? ?? 'circle',
        label: j['label'] as String?,
        activeIcon: j['activeIcon'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'icon': icon,
        if (label != null) 'label': label,
        if (activeIcon != null) 'activeIcon': activeIcon,
      };
}

class FabNode extends UINode with _NodeJsonBase {
  FabNode({
    super.id,
    super.style,
    super.actions,
    required this.icon,
    this.label,
    this.extended,
    this.mini,
    this.backgroundColor,
    this.foregroundColor,
  }) : super(type: 'fab', children: const []);

  final String icon;
  final String? label;
  final bool? extended;
  final bool? mini;
  final String? backgroundColor;
  final String? foregroundColor;

  factory FabNode.fromJson(Map<String, dynamic> j) => FabNode(
        id: j['id'] as String?,
        style: _parseStyle(j),
        actions: _parseActions(j),
        icon: j['icon'] as String? ?? 'add',
        label: j['label'] as String?,
        extended: j['extended'] as bool?,
        mini: j['mini'] as bool?,
        backgroundColor: j['backgroundColor'] as String?,
        foregroundColor: j['foregroundColor'] as String?,
      );

  @override
  Map<String, dynamic> toJson() => {
        ..._baseJson(),
        'icon': icon,
        if (label != null) 'label': label,
        if (extended != null) 'extended': extended,
        if (mini != null) 'mini': mini,
        if (backgroundColor != null) 'backgroundColor': backgroundColor,
        if (foregroundColor != null) 'foregroundColor': foregroundColor,
      };
}

// ── Overlays ─────────────────────────────────

class DialogNode extends UINode with _NodeJsonBase {
  DialogNode({
    super.id,
    super.children,
    super.style,
    super.actions,
    super.condition,
    this.title,
    this.content,
    this.confirmAction,
    this.cancelAction,
    this.barrierDismissible,
  }) : super(type: 'dialog');

  final UINode? title;
  final UINode? content;
  final UIAction? confirmAction;
  final UIAction? cancelAction;
  final bool? barrierDismissible;

  factory DialogNode.fromJson(Map<String, dynamic> j) => DialogNode(
        id: j['id'] as String?,
        children: _parseChildren(j),
        style: _parseStyle(j),
        actions: _parseActions(j),
        condition: j['condition'] as String?,
        title: j['title'] != null
            ? UINode.fromJson(j['title'] as Map<String, dynamic>)
            : null,
        content: j['content'] != null
            ? UINode.fromJson(j['content'] as Map<String, dynamic>)
            : null,
        confirmAction: j['confirmAction'] != null
            ? UIAction.fromJson(j['confirmAction'] as Map<String, dynamic>)
            : null,
        cancelAction: j['cancelAction'] != null
            ? UIAction.fromJson(j['cancelAction'] as Map<String, dynamic>)
            : null,
        barrierDismissible: j['barrierDismissible'] as bool?,
      );

  @override
  Map<String, dynamic> toJson() => {
        ..._baseJson(),
        if (title != null) 'title': title!.toJson(),
        if (content != null) 'content': content!.toJson(),
        if (confirmAction != null) 'confirmAction': confirmAction!.toJson(),
        if (cancelAction != null) 'cancelAction': cancelAction!.toJson(),
        if (barrierDismissible != null)
          'barrierDismissible': barrierDismissible,
      };
}

class SnackbarNode extends UINode with _NodeJsonBase {
  SnackbarNode({
    super.id,
    super.style,
    super.actions,
    super.condition,
    required this.message,
    this.actionLabel,
    this.actionOnTap,
    this.duration,
    this.variant,
  }) : super(type: 'snackbar', children: const []);

  final String message;
  final String? actionLabel;
  final UIAction? actionOnTap;
  final int? duration; // milliseconds
  final String? variant; // "info" | "success" | "warning" | "error"

  factory SnackbarNode.fromJson(Map<String, dynamic> j) => SnackbarNode(
        id: j['id'] as String?,
        style: _parseStyle(j),
        actions: _parseActions(j),
        condition: j['condition'] as String?,
        message: j['message'] as String? ?? '',
        actionLabel: j['actionLabel'] as String?,
        actionOnTap: j['actionOnTap'] != null
            ? UIAction.fromJson(j['actionOnTap'] as Map<String, dynamic>)
            : null,
        duration: j['duration'] as int?,
        variant: j['variant'] as String?,
      );

  @override
  Map<String, dynamic> toJson() => {
        ..._baseJson(),
        'message': message,
        if (actionLabel != null) 'actionLabel': actionLabel,
        if (actionOnTap != null) 'actionOnTap': actionOnTap!.toJson(),
        if (duration != null) 'duration': duration,
        if (variant != null) 'variant': variant,
      };
}

// ── Decoration / Misc ─────────────────────────

class DividerNode extends UINode with _NodeJsonBase {
  DividerNode({
    super.id,
    super.style,
    super.actions,
    super.condition,
    this.thickness,
    this.color,
    this.indent,
    this.endIndent,
    this.direction,
  }) : super(type: 'divider', children: const []);

  final double? thickness;
  final String? color;
  final double? indent;
  final double? endIndent;
  final String? direction; // "horizontal" | "vertical"

  factory DividerNode.fromJson(Map<String, dynamic> j) => DividerNode(
        id: j['id'] as String?,
        style: _parseStyle(j),
        actions: _parseActions(j),
        condition: j['condition'] as String?,
        thickness: (j['thickness'] as num?)?.toDouble(),
        color: j['color'] as String?,
        indent: (j['indent'] as num?)?.toDouble(),
        endIndent: (j['endIndent'] as num?)?.toDouble(),
        direction: j['direction'] as String?,
      );

  @override
  Map<String, dynamic> toJson() => {
        ..._baseJson(),
        if (thickness != null) 'thickness': thickness,
        if (color != null) 'color': color,
        if (indent != null) 'indent': indent,
        if (endIndent != null) 'endIndent': endIndent,
        if (direction != null) 'direction': direction,
      };
}

class SpacerNode extends UINode with _NodeJsonBase {
  SpacerNode({
    super.id,
    super.style,
    super.condition,
    this.width,
    this.height,
    this.flex,
  }) : super(type: 'spacer', children: const [], actions: const {});

  final double? width;
  final double? height;
  final int? flex;

  factory SpacerNode.fromJson(Map<String, dynamic> j) => SpacerNode(
        id: j['id'] as String?,
        style: _parseStyle(j),
        condition: j['condition'] as String?,
        width: (j['width'] as num?)?.toDouble(),
        height: (j['height'] as num?)?.toDouble(),
        flex: j['flex'] as int?,
      );

  @override
  Map<String, dynamic> toJson() => {
        ..._baseJson(),
        if (width != null) 'width': width,
        if (height != null) 'height': height,
        if (flex != null) 'flex': flex,
      };
}

class BadgeNode extends UINode with _NodeJsonBase {
  BadgeNode({
    super.id,
    super.children,
    super.style,
    super.actions,
    super.condition,
    this.label,
    this.backgroundColor,
    this.textColor,
  }) : super(type: 'badge');

  final String? label;
  final String? backgroundColor;
  final String? textColor;

  factory BadgeNode.fromJson(Map<String, dynamic> j) => BadgeNode(
        id: j['id'] as String?,
        children: _parseChildren(j),
        style: _parseStyle(j),
        actions: _parseActions(j),
        condition: j['condition'] as String?,
        label: j['label'] as String?,
        backgroundColor: j['backgroundColor'] as String?,
        textColor: j['textColor'] as String?,
      );

  @override
  Map<String, dynamic> toJson() => {
        ..._baseJson(),
        if (label != null) 'label': label,
        if (backgroundColor != null) 'backgroundColor': backgroundColor,
        if (textColor != null) 'textColor': textColor,
        if (children.isNotEmpty)
          'children': children.map((c) => c.toJson()).toList(),
      };
}

class ChipNode extends UINode with _NodeJsonBase {
  ChipNode({
    super.id,
    super.style,
    super.actions,
    super.condition,
    required this.label,
    this.icon,
    this.selected,
    this.deletable,
    this.variant,
  }) : super(type: 'chip', children: const []);

  final String label;
  final String? icon;
  final bool? selected;
  final bool? deletable;
  final String? variant; // "filter" | "action" | "input" | "assist"

  factory ChipNode.fromJson(Map<String, dynamic> j) => ChipNode(
        id: j['id'] as String?,
        style: _parseStyle(j),
        actions: _parseActions(j),
        condition: j['condition'] as String?,
        label: j['label'] as String? ?? '',
        icon: j['icon'] as String?,
        selected: j['selected'] as bool?,
        deletable: j['deletable'] as bool?,
        variant: j['variant'] as String?,
      );

  @override
  Map<String, dynamic> toJson() => {
        ..._baseJson(),
        'label': label,
        if (icon != null) 'icon': icon,
        if (selected != null) 'selected': selected,
        if (deletable != null) 'deletable': deletable,
        if (variant != null) 'variant': variant,
      };
}

class AvatarNode extends UINode with _NodeJsonBase {
  AvatarNode({
    super.id,
    super.style,
    super.actions,
    super.condition,
    this.src,
    this.initials,
    this.size,
    this.backgroundColor,
    this.foregroundColor,
  }) : super(type: 'avatar', children: const []);

  final String? src;
  final String? initials;
  final double? size;
  final String? backgroundColor;
  final String? foregroundColor;

  factory AvatarNode.fromJson(Map<String, dynamic> j) => AvatarNode(
        id: j['id'] as String?,
        style: _parseStyle(j),
        actions: _parseActions(j),
        condition: j['condition'] as String?,
        src: j['src'] as String?,
        initials: j['initials'] as String?,
        size: (j['size'] as num?)?.toDouble(),
        backgroundColor: j['backgroundColor'] as String?,
        foregroundColor: j['foregroundColor'] as String?,
      );

  @override
  Map<String, dynamic> toJson() => {
        ..._baseJson(),
        if (src != null) 'src': src,
        if (initials != null) 'initials': initials,
        if (size != null) 'size': size,
        if (backgroundColor != null) 'backgroundColor': backgroundColor,
        if (foregroundColor != null) 'foregroundColor': foregroundColor,
      };
}

class ProgressBarNode extends UINode with _NodeJsonBase {
  ProgressBarNode({
    super.id,
    super.style,
    super.actions,
    super.condition,
    this.value,
    this.variant,
    this.color,
    this.backgroundColor,
    this.strokeWidth,
  }) : super(type: 'progressBar', children: const []);

  /// null = indeterminate, 0.0–1.0 = determinate
  final double? value;
  final String? variant; // "linear" | "circular"
  final String? color;
  final String? backgroundColor;
  final double? strokeWidth;

  factory ProgressBarNode.fromJson(Map<String, dynamic> j) => ProgressBarNode(
        id: j['id'] as String?,
        style: _parseStyle(j),
        actions: _parseActions(j),
        condition: j['condition'] as String?,
        value: (j['value'] as num?)?.toDouble(),
        variant: j['variant'] as String?,
        color: j['color'] as String?,
        backgroundColor: j['backgroundColor'] as String?,
        strokeWidth: (j['strokeWidth'] as num?)?.toDouble(),
      );

  @override
  Map<String, dynamic> toJson() => {
        ..._baseJson(),
        if (value != null) 'value': value,
        if (variant != null) 'variant': variant,
        if (color != null) 'color': color,
        if (backgroundColor != null) 'backgroundColor': backgroundColor,
        if (strokeWidth != null) 'strokeWidth': strokeWidth,
      };
}

// ── Rich / Plugin nodes ───────────────────────

class ChartNode extends UINode with _NodeJsonBase {
  ChartNode({
    super.id,
    super.style,
    super.actions,
    super.condition,
    required this.chartType,
    required this.data,
    this.title,
    this.xAxisLabel,
    this.yAxisLabel,
    this.showLegend,
  }) : super(type: 'chart', children: const []);

  final String chartType; // "bar" | "line" | "pie" | "scatter"
  final Map<String, dynamic> data;
  final String? title;
  final String? xAxisLabel;
  final String? yAxisLabel;
  final bool? showLegend;

  factory ChartNode.fromJson(Map<String, dynamic> j) => ChartNode(
        id: j['id'] as String?,
        style: _parseStyle(j),
        actions: _parseActions(j),
        condition: j['condition'] as String?,
        chartType: j['chartType'] as String? ?? 'bar',
        data: j['data'] as Map<String, dynamic>? ?? {},
        title: j['title'] as String?,
        xAxisLabel: j['xAxisLabel'] as String?,
        yAxisLabel: j['yAxisLabel'] as String?,
        showLegend: j['showLegend'] as bool?,
      );

  @override
  Map<String, dynamic> toJson() => {
        ..._baseJson(),
        'chartType': chartType,
        'data': data,
        if (title != null) 'title': title,
        if (xAxisLabel != null) 'xAxisLabel': xAxisLabel,
        if (yAxisLabel != null) 'yAxisLabel': yAxisLabel,
        if (showLegend != null) 'showLegend': showLegend,
      };
}

class MapNode extends UINode with _NodeJsonBase {
  MapNode({
    super.id,
    super.style,
    super.actions,
    super.condition,
    required this.lat,
    required this.lng,
    this.zoom,
    this.markers,
  }) : super(type: 'map', children: const []);

  final double lat;
  final double lng;
  final double? zoom;
  final List<MapMarker>? markers;

  factory MapNode.fromJson(Map<String, dynamic> j) => MapNode(
        id: j['id'] as String?,
        style: _parseStyle(j),
        actions: _parseActions(j),
        condition: j['condition'] as String?,
        lat: (j['lat'] as num?)?.toDouble() ?? 0,
        lng: (j['lng'] as num?)?.toDouble() ?? 0,
        zoom: (j['zoom'] as num?)?.toDouble(),
        markers: (j['markers'] as List<dynamic>?)
            ?.map((e) => MapMarker.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  @override
  Map<String, dynamic> toJson() => {
        ..._baseJson(),
        'lat': lat,
        'lng': lng,
        if (zoom != null) 'zoom': zoom,
        if (markers != null)
          'markers': markers!.map((m) => m.toJson()).toList(),
      };
}

class MapMarker {
  const MapMarker({required this.lat, required this.lng, this.label});

  final double lat, lng;
  final String? label;

  factory MapMarker.fromJson(Map<String, dynamic> j) => MapMarker(
        lat: (j['lat'] as num).toDouble(),
        lng: (j['lng'] as num).toDouble(),
        label: j['label'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'lat': lat,
        'lng': lng,
        if (label != null) 'label': label,
      };
}

class WebViewNode extends UINode with _NodeJsonBase {
  WebViewNode({
    super.id,
    super.style,
    super.actions,
    super.condition,
    required this.url,
    this.javascript,
  }) : super(type: 'webview', children: const []);

  final String url;
  final bool? javascript;

  factory WebViewNode.fromJson(Map<String, dynamic> j) => WebViewNode(
        id: j['id'] as String?,
        style: _parseStyle(j),
        actions: _parseActions(j),
        condition: j['condition'] as String?,
        url: j['url'] as String? ?? '',
        javascript: j['javascript'] as bool?,
      );

  @override
  Map<String, dynamic> toJson() => {
        ..._baseJson(),
        'url': url,
        if (javascript != null) 'javascript': javascript,
      };
}

/// An escape hatch — pass arbitrary props to a named registered widget.
class CustomNode extends UINode with _NodeJsonBase {
  CustomNode({
    super.id,
    super.children,
    super.style,
    super.actions,
    super.condition,
    required this.componentId,
    this.props = const {},
  }) : super(type: 'custom');

  final String componentId;
  final Map<String, dynamic> props;

  factory CustomNode.fromJson(Map<String, dynamic> j) => CustomNode(
        id: j['id'] as String?,
        children: _parseChildren(j),
        style: _parseStyle(j),
        actions: _parseActions(j),
        condition: j['condition'] as String?,
        componentId: j['componentId'] as String? ?? '',
        props: j['props'] as Map<String, dynamic>? ?? {},
      );

  @override
  Map<String, dynamic> toJson() => {
        ..._baseJson(),
        'componentId': componentId,
        'props': props,
        if (children.isNotEmpty)
          'children': children.map((c) => c.toJson()).toList(),
      };
}

/// Represents any node whose [type] is not in the registry.
class UnknownNode extends UINode with _NodeJsonBase {
  UnknownNode({required super.type, required this.rawJson})
      : super(children: const [], actions: const {});

  final Map<String, dynamic> rawJson;

  @override
  Map<String, dynamic> toJson() => rawJson;
}

// ─────────────────────────────────────────────
// 6. Bootstrap
// ─────────────────────────────────────────────
void bootstrapSchema() => UINode._registerBuiltins();
