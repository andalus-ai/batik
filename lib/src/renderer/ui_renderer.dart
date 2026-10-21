// lib/src/renderer/ui_renderer.dart
//
// Batik Framework — Enhanced Renderer
// ============================================================
// Full-featured UI rendering with:
//  • Diff-aware widget keying (preserves widget state)
//  • Per-node entrance animations
//  • Expression evaluation ({{variable}} in text props)
//  • Riverpod variable store integration
//  • Virtualization for lists/grids
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/registry.dart';
import '../core/action_dispatcher.dart' as batik;
import '../core/action_dispatcher.dart' show ActionHandler;
import '../schema/ui_schema.dart';
import '../diff/ui_diff_engine.dart';
import '../animation/animated_node_renderer.dart';
import '../state/agent_providers.dart';

// ─────────────────────────────────────────────
// AgentUIRenderer
// ─────────────────────────────────────────────

/// Renders agent UI responses with full feature support.
///
/// Transforms [AgentUIResponse] into Flutter widgets with:
/// - Diff-aware rendering (preserves widget state across updates)
/// - Per-node entrance animations
/// - Expression evaluation ({{variable}} templating)
/// - Riverpod variable store integration
/// - Customizable components via registry
/// - Comprehensive error handling
class AgentUIRenderer extends ConsumerStatefulWidget {
  const AgentUIRenderer({
    super.key,
    required this.response,
    required this.actionHandler,
    this.registry,
    this.initialVariables = const {},
    this.onError,
    this.loadingBuilder,
    this.errorBuilder,
    this.theme,
    this.diff,
    this.animationConfig = const AnimationConfig(),
    this.sessionId,
  });

  /// The UI response tree to render
  final AgentUIResponse response;

  /// Handler for user-triggered actions
  final ActionHandler actionHandler;

  /// Custom component builders (defaults to built-in set)
  final UIComponentRegistry? registry;

  /// Initial variables for expression evaluation
  final Map<String, dynamic> initialVariables;

  /// Error handling callback
  final void Function(Object error, StackTrace? stack)? onError;

  /// Custom loading state widget builder
  final WidgetBuilder? loadingBuilder;

  /// Custom error widget builder
  final Widget Function(BuildContext, Object error)? errorBuilder;

  /// Optional theme override
  final ThemeData? theme;

  /// Diff result for change-aware rendering
  final DiffResult? diff;

  /// Animation configuration for node transitions
  final AnimationConfig animationConfig;

  /// Session ID for variable store isolation
  final String? sessionId;

  @override
  ConsumerState<AgentUIRenderer> createState() => _AgentUIRendererState();
}

class _AgentUIRendererState extends ConsumerState<AgentUIRenderer> {
  late RendererImpl _renderer;
  late batik.ActionDispatcher _dispatcher;

  @override
  void initState() {
    super.initState();
    _buildRenderer();
  }

  @override
  void didUpdateWidget(AgentUIRenderer old) {
    super.didUpdateWidget(old);
    if (old.actionHandler != widget.actionHandler ||
        old.registry != widget.registry) {
      _buildRenderer();
    }
  }

  void _buildRenderer() {
    final store = batik.VariableStore();
    store.setMany(widget.initialVariables);
    _dispatcher = batik.ActionDispatcher(
      handler: widget.actionHandler,
      variableStore: store,
    );
    _renderer = RendererImpl(
      registry: widget.registry ?? UIComponentRegistry.instance,
      dispatcher: _dispatcher,
      store: store,
      conditionResolver: batik.ConditionResolver(store),
      diff: widget.diff,
      animationConfig: widget.animationConfig,
      onError: widget.onError,
      ref: ref,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme ?? Theme.of(context);

    // Watch the riverpod variable store for this session
    final sessionVars = ref.watch(
      sessionVariableStoreProvider(widget.sessionId ?? 'default'),
    );

    // Sync riverpod store into the local dispatcher store
    _renderer.store.setMany(sessionVars);

    Widget content;
    try {
      content = _renderer.render(context, widget.response.root);
    } catch (e, st) {
      widget.onError?.call(e, st);
      content = widget.errorBuilder?.call(context, e) ??
          _DefaultErrorWidget(error: e);
    }

    return Theme(
      data: theme,
      child: _UIRendererScope(
        renderer: _renderer,
        dispatcher: _dispatcher,
        store: _renderer.store,
        sessionId: widget.sessionId ?? 'default',
        child: content,
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Scope (InheritedWidget)
// ─────────────────────────────────────────────

class _UIRendererScope extends InheritedWidget {
  const _UIRendererScope({
    required this.renderer,
    required this.dispatcher,
    required this.store,
    required this.sessionId,
    required super.child,
  });

  final RendererImpl renderer;
  final batik.ActionDispatcher dispatcher;
  final batik.VariableStore store;
  final String sessionId;

  static _UIRendererScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_UIRendererScope>();

  static _UIRendererScope of(BuildContext context) {
    final scope = maybeOf(context);
    assert(
      scope != null,
      'No _UIRendererScope found. Wrap with AgentUIRenderer.',
    );
    return scope!;
  }

  @override
  bool updateShouldNotify(_UIRendererScope old) =>
      renderer != old.renderer || sessionId != old.sessionId;
}

extension AgentUIContext on BuildContext {
  /// Get the action dispatcher for this renderer context
  batik.ActionDispatcher get agentDispatcher =>
      _UIRendererScope.of(this).dispatcher;

  /// Get the variable store for this renderer context
  batik.VariableStore get agentVariables => _UIRendererScope.of(this).store;

  /// Get the session ID for this renderer context
  String get agentSessionId => _UIRendererScope.of(this).sessionId;
}

// ─────────────────────────────────────────────
// Renderer implementation
// ─────────────────────────────────────────────

/// Core rendering engine that transforms UI nodes into widgets.
///
/// Responsibilities:
/// - Resolves conditions (if nodes should render)
/// - Evaluates template expressions ({{variable}})
/// - Dispatches to component builders via registry
/// - Applies diff-aware keying for state preservation
/// - Animates changes based on diff patches
class RendererImpl implements NodeRenderer {
  RendererImpl({
    required this.registry,
    required this.dispatcher,
    required this.store,
    required this.conditionResolver,
    required this.animationConfig,
    this.diff,
    this.onError,
    this.ref,
  });

  final UIComponentRegistry registry;
  final batik.ActionDispatcher dispatcher;
  final batik.VariableStore store;
  final batik.ConditionResolver conditionResolver;
  final AnimationConfig animationConfig;
  final DiffResult? diff;
  final void Function(Object, StackTrace?)? onError;
  final WidgetRef? ref;

  // Expression evaluator
  static final _exprPattern = RegExp(r'\{\{([^}]+)\}\}');

  @override
  Widget render(BuildContext context, UINode node) {
    // Condition check
    if (!conditionResolver.evaluate(node.condition)) {
      return const SizedBox.shrink();
    }

    try {
      // Evaluate expressions in text props
      final resolvedNode = _resolveExpressions(node);

      final builder = registry.builderFor(resolvedNode);
      if (builder == null) {
        return _UnknownWidget(node: resolvedNode);
      }

      Widget widget = builder(context, resolvedNode, this);

      // Apply entrance animation for newly inserted nodes
      final patch = _findPatch(node.id);
      if (patch is InsertPatch && animationConfig.enableEntranceAnimations) {
        widget = AnimatedUINode(
          animation: animationConfig.entranceAnimation,
          child: widget,
        );
      } else if (patch is UpdatePatch &&
          animationConfig.enableUpdateAnimations) {
        widget = DiffAwareWidget(
          nodeId: node.id,
          config: animationConfig,
          patch: patch,
          child: widget,
        );
      }

      // Key by ID for widget tree stability
      if (node.id != null) {
        widget = KeyedSubtree(key: ValueKey(node.id), child: widget);
      }

      return widget;
    } catch (e, st) {
      onError?.call(e, st);
      return _DefaultErrorWidget(error: e);
    }
  }

  @override
  List<Widget> renderChildren(BuildContext context, List<UINode> children) {
    return children.map((c) => render(context, c)).toList(growable: false);
  }

  UIPatch? _findPatch(String? nodeId) {
    if (nodeId == null || diff == null) return null;
    for (final patch in diff!.patches) {
      if (patch is UpdatePatch && patch.newNode.id == nodeId) return patch;
      if (patch is InsertPatch && patch.node.id == nodeId) return patch;
    }
    return null;
  }

  UINode _resolveExpressions(UINode node) {
    // Only resolve text nodes for now
    if (node is! TextNode) return node;
    if (!node.text.contains('{{')) return node;

    final resolved = node.text.replaceAllMapped(_exprPattern, (m) {
      final key = m.group(1)!.trim();
      final parts = key.split('.');
      dynamic val = store.snapshot();
      for (final part in parts) {
        if (val is Map)
          val = val[part];
        else
          return '{{$key}}';
      }
      return val?.toString() ?? '';
    });

    return TextNode(
      id: node.id,
      style: node.style,
      actions: node.actions,
      condition: node.condition,
      text: resolved,
      variant: node.variant,
      selectable: node.selectable,
    );
  }
}

// ─────────────────────────────────────────────
// Fallback widgets
// ─────────────────────────────────────────────

class _UnknownWidget extends StatelessWidget {
  const _UnknownWidget({required this.node});
  final UINode node;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.orange.shade300),
        borderRadius: BorderRadius.circular(4),
        color: Colors.orange.shade50,
      ),
      child: Text(
        '⚠ No builder for: ${node.type}',
        style: TextStyle(color: Colors.orange.shade800, fontSize: 11),
      ),
    );
  }
}

class _DefaultErrorWidget extends StatelessWidget {
  const _DefaultErrorWidget({required this.error});
  final Object error;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        border: Border.all(color: Colors.red.shade300),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '🚨 $error',
        style: TextStyle(color: Colors.red.shade700, fontSize: 11),
      ),
    );
  }
}
