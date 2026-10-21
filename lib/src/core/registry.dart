// lib/src/core/registry.dart
//
// AgentUIKit — Node & Component Registry
// ============================================================
// Central registry for schema node types ↔ Flutter widget builders.
// Third parties add their own component builders here.
// ============================================================

import 'package:flutter/widgets.dart';
import '../schema/ui_schema.dart';

/// Signature for a function that converts a [UINode] into a Flutter [Widget].
typedef NodeWidgetBuilder<T extends UINode> =
    Widget Function(BuildContext context, T node, NodeRenderer renderer);

/// [NodeRenderer] is passed to builders so they can recursively render children.
abstract class NodeRenderer {
  Widget render(BuildContext context, UINode node);
  List<Widget> renderChildren(BuildContext context, List<UINode> children);
}

/// Singleton registry that maps [UINode] runtimeType → [NodeWidgetBuilder].
class UIComponentRegistry {
  UIComponentRegistry._();
  static final instance = UIComponentRegistry._();

  final _builders = <Type, NodeWidgetBuilder<UINode>>{};

  final _customBuilders = <String, NodeWidgetBuilder<CustomNode>>{};

  // ── Registration ────────────────────────────────────────────

  /// Register a builder for a concrete [UINode] subtype [T].
  ///
  /// ```dart
  /// UIComponentRegistry.instance.register<TextNode>(
  ///   (ctx, node, renderer) => Text(node.text),
  /// );
  /// ```
  void register<T extends UINode>(NodeWidgetBuilder<T> builder) {
    _builders[T] = (ctx, node, renderer) => builder(ctx, node as T, renderer);
  }

  /// Register a builder for a [CustomNode] identified by [componentId].
  void registerCustom(
    String componentId,
    NodeWidgetBuilder<CustomNode> builder,
  ) {
    _customBuilders[componentId] = builder;
  }

  /// Unregister a type (useful for testing / hot-swap).
  void unregister<T extends UINode>() => _builders.remove(T);
  void unregisterCustom(String componentId) =>
      _customBuilders.remove(componentId);

  // ── Lookup ───────────────────────────────────────────────────

  NodeWidgetBuilder<UINode>? builderFor(UINode node) {
    if (node is CustomNode) {
      final cb = _customBuilders[node.componentId];
      if (cb != null) {
        return (ctx, n, r) => cb(ctx, n as CustomNode, r);
      }
    }
    return _builders[node.runtimeType];
  }

  bool isRegistered<T extends UINode>() => _builders.containsKey(T);
  bool isCustomRegistered(String id) => _customBuilders.containsKey(id);

  int get registeredCount => _builders.length + _customBuilders.length;
}
