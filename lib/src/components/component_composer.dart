// lib/src/components/component_composer.dart
//
// Batik — Component Composition Engine (Patch 048)
// ============================================================
// Enables reusable, high-level composable runtime units.
// Instead of an LLM generating 50 low-level layout nodes (Row, Column,
// Container, Text, Card, Icon), the AI can generate semantic components:
//
// {
//   "type": "component",
//   "component": "CustomerCard",
//   "props": {
//     "name": "Jane Doe",
//     "role": "Lead Architect",
//     "avatar": "https://...",
//     "metrics": {"projects": 12, "tasks": 34}
//   }
// }
// ============================================================

import 'package:flutter/material.dart';
import '../schema/ui_schema.dart';
import '../core/registry.dart';
import '../plugin/batik_plugin.dart';
import '../theme/batik_tokens.dart';

/// Context provided to a [BatikComponent] during rendering.
class BatikComponentContext {
  const BatikComponentContext({
    required this.props,
    required this.context,
    required this.renderer,
    this.children = const [],
  });

  final Map<String, dynamic> props;
  final BuildContext context;
  final NodeRenderer renderer;
  final List<UINode> children;

  T? get<T>(String key, [T? fallback]) =>
      props.containsKey(key) ? props[key] as T? : fallback;
}

/// Base class for composable, reusable UI components in Batik.
abstract class BatikComponent {
  const BatikComponent();

  /// Unique component name, e.g. "CustomerCard", "MetricsCard".
  String get name;

  /// Render the component into a Flutter widget.
  Widget build(BatikComponentContext ctx);
}

/// Registry mapping component names to their [BatikComponent] implementations.
class BatikComponentRegistry {
  BatikComponentRegistry._();
  static final instance = BatikComponentRegistry._();

  final _components = <String, BatikComponent>{};

  void register(BatikComponent component) {
    _components[component.name] = component;
  }

  void unregister(String name) => _components.remove(name);

  BatikComponent? operator [](String name) => _components[name];

  bool has(String name) => _components.containsKey(name);

  Iterable<BatikComponent> get all => _components.values;
}

/// UINode representing a high-level component instantiation.
class ComponentNode extends UINode with _CompNodeJsonBase {
  ComponentNode({
    super.id,
    super.style,
    super.actions,
    super.condition,
    super.children,
    required this.componentName,
    this.props = const {},
  }) : super(type: 'component');

  final String componentName;
  final Map<String, dynamic> props;

  factory ComponentNode.fromJson(Map<String, dynamic> j) => ComponentNode(
        id: j['id'] as String?,
        style: _parseCompStyle(j),
        actions: _parseCompActions(j),
        condition: j['condition'] as String?,
        componentName: j['component'] as String? ?? 'unknown',
        props: j['props'] as Map<String, dynamic>? ?? {},
        children: (j['children'] as List<dynamic>? ?? [])
            .map((c) => UINode.fromJson(c as Map<String, dynamic>))
            .toList(),
      );

  @override
  Map<String, dynamic> toJson() => {
        ..._baseCompJson(),
        'component': componentName,
        if (props.isNotEmpty) 'props': props,
        if (children.isNotEmpty)
          'children': children.map((c) => c.toJson()).toList(),
      };
}

// ─────────────────────────────────────────────
// Built-in Composable Units
// ─────────────────────────────────────────────

/// High-level Customer Profile Card.
class CustomerCardComponent extends BatikComponent {
  const CustomerCardComponent();

  @override
  String get name => 'CustomerCard';

  @override
  Widget build(BatikComponentContext ctx) {
    final theme = Theme.of(ctx.context);
    final title = ctx.get<String>('name', 'Unknown Customer') ?? 'Unknown Customer';
    final subtitle = ctx.get<String>('role', '');
    final status = ctx.get<String>('status', 'Active') ?? 'Active';
    final email = ctx.get<String>('email', '');

    return Card(
      elevation: BatikElevation.card,
      shape: RoundedRectangleBorder(borderRadius: BatikRadius.roundedMd),
      child: Padding(
        padding: const EdgeInsets.all(BatikSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Text(
                    title.isNotEmpty ? title[0].toUpperCase() : '?',
                    style: TextStyle(color: theme.colorScheme.onPrimaryContainer),
                  ),
                ),
                const SizedBox(width: BatikSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: BatikTypography.titleMedium),
                      if (subtitle != null && subtitle.isNotEmpty)
                        Text(subtitle, style: BatikTypography.caption),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: status == 'Active'
                        ? Colors.green.withAlpha(35)
                        : Colors.orange.withAlpha(35),
                    borderRadius: BatikRadius.pill,
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: status == 'Active' ? Colors.green[800] : Colors.orange[800],
                    ),
                  ),
                ),
              ],
            ),
            if (email != null && email.isNotEmpty) ...[
              const SizedBox(height: BatikSpacing.sm),
              Row(
                children: [
                  Icon(Icons.email_outlined, size: 14, color: theme.colorScheme.outline),
                  const SizedBox(width: 4),
                  Text(email, style: BatikTypography.bodyMedium),
                ],
              ),
            ],
            if (ctx.children.isNotEmpty) ...[
              const Divider(height: 16),
              ...ctx.renderer.renderChildren(ctx.context, ctx.children),
            ],
          ],
        ),
      ),
    );
  }
}

/// High-level Metric Stat Card (KPI tile).
class MetricsCardComponent extends BatikComponent {
  const MetricsCardComponent();

  @override
  String get name => 'MetricsCard';

  @override
  Widget build(BatikComponentContext ctx) {
    final theme = Theme.of(ctx.context);
    final label = ctx.get<String>('label', 'Metric');
    final value = ctx.get<dynamic>('value', '0').toString();
    final delta = ctx.get<String>('delta', '');
    final isPositive = ctx.get<bool>('positive', true) ?? true;

    return Container(
      padding: const EdgeInsets.all(BatikSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BatikRadius.roundedMd,
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label ?? '', style: BatikTypography.caption),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(value, style: BatikTypography.headlineLarge),
              if (delta != null && delta.isNotEmpty)
                Row(
                  children: [
                    Icon(
                      isPositive ? Icons.trending_up : Icons.trending_down,
                      size: 16,
                      color: isPositive ? Colors.green : Colors.red,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      delta,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isPositive ? Colors.green : Colors.red,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// High-level Agent Status Banner.
class AgentStatusComponent extends BatikComponent {
  const AgentStatusComponent();

  @override
  String get name => 'AgentStatus';

  @override
  Widget build(BatikComponentContext ctx) {
    final theme = Theme.of(ctx.context);
    final agentName = ctx.get<String>('agent', 'Assistant');
    final state = ctx.get<String>('state', 'idle');
    final message = ctx.get<String>('message', 'Ready');

    final color = switch (state) {
      'running' || 'thinking' => Colors.blue,
      'error' => Colors.red,
      'done' || 'success' => Colors.green,
      _ => theme.colorScheme.outline,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BatikRadius.roundedSm,
        border: Border.all(color: color.withAlpha(70)),
      ),
      child: Row(
        children: [
          Icon(Icons.smart_toy_outlined, size: 16, color: color),
          const SizedBox(width: 8),
          Text(agentName ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          const SizedBox(width: 8),
          Text('•', style: TextStyle(color: color)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message ?? '',
              style: const TextStyle(fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// ComponentPlugin & Renderer
// ─────────────────────────────────────────────

class ComponentPlugin extends BatikPlugin {
  const ComponentPlugin();

  @override
  PluginManifest get manifest => const PluginManifest(
        id: 'batik_components',
        version: '0.1.0',
        capabilities: [PluginCapability.document],
        description: 'Composable runtime component system with built-in CustomerCard, MetricsCard, and AgentStatus.',
      );

  @override
  Future<void> initialize(BatikRuntime runtime) async {
    UINode.registerExternal('component', (j) => ComponentNode.fromJson(j));

    // Register built-in component units
    final registry = BatikComponentRegistry.instance;
    registry.register(const CustomerCardComponent());
    registry.register(const MetricsCardComponent());
    registry.register(const AgentStatusComponent());
  }

  @override
  void registerNodes(UIComponentRegistry registry) {
    registry.register<ComponentNode>((context, node, renderer) {
      final comp = BatikComponentRegistry.instance[node.componentName];
      if (comp == null) {
        return Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.red.shade200),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text('Unknown component: ${node.componentName}',
              style: const TextStyle(color: Colors.red, fontSize: 12)),
        );
      }
      return comp.build(BatikComponentContext(
        props: node.props,
        context: context,
        renderer: renderer,
        children: node.children,
      ));
    });
  }

  @override
  String get systemPromptSection => '''
ComponentNode: {
  "type": "component",
  "component": "CustomerCard|MetricsCard|AgentStatus",
  "props": { ... }
}
Examples:
- CustomerCard: {"name": "Jane", "role": "Architect", "status": "Active", "email": "jane@example.com"}
- MetricsCard: {"label": "Active Users", "value": "1,240", "delta": "+12%", "positive": true}
- AgentStatus: {"agent": "Researcher", "state": "running|done|error", "message": "Analyzing data..."}''';
}

// ── Private serialization helpers ─────────────────────────────
UIStyle? _parseCompStyle(Map<String, dynamic> j) {
  final s = j['style'] as Map<String, dynamic>?;
  return s == null ? null : UIStyle.fromJson(s);
}

Map<String, UIAction> _parseCompActions(Map<String, dynamic> j) {
  final raw = j['actions'] as Map<String, dynamic>?;
  if (raw == null) return const {};
  return raw
      .map((k, v) => MapEntry(k, UIAction.fromJson(v as Map<String, dynamic>)));
}

mixin _CompNodeJsonBase on UINode {
  Map<String, dynamic> _baseCompJson() => {
        'type': type,
        if (id != null) 'id': id,
        if (style != null) 'style': style!.toJson(),
        if (actions.isNotEmpty)
          'actions': actions.map((k, v) => MapEntry(k, v.toJson())),
        if (condition != null) 'condition': condition,
      };
}
