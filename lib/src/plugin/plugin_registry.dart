// lib/src/plugins/plugin_registry.dart
//
// AgentUIKit v3 — Plugin Package Architecture
// ============================================================
// ChartNode, MapNode, WebViewNode are no longer stubs.
// They are registered by separate pub packages that call
// AgentUIKitPlugins.register(...) on import.
//
// This file defines:
//  1. The plugin contract (AgentUIKitPlugin)
//  2. The plugin registry (AgentUIKitPlugins)
//  3. Built-in lightweight fallback renderers
//  4. Placeholder widgets with install instructions
//  5. Plugin capability reporting (for system prompt)
// ============================================================

import 'package:flutter/material.dart';
import '../core/registry.dart';
import '../schema/ui_schema.dart';

// ─────────────────────────────────────────────
// Plugin contract
// ─────────────────────────────────────────────

abstract class AgentUIKitPlugin {
  const AgentUIKitPlugin();

  /// Unique plugin ID, e.g. "batik_charts"
  String get id;

  /// Human-readable name
  String get name;

  /// Version string
  String get version;

  /// Node types this plugin handles
  List<String> get handledNodeTypes;

  /// Register builders into the provided registry.
  void register(UIComponentRegistry registry);

  /// Optional: schema extensions this plugin adds.
  Map<String, dynamic> get schemaExtensions => {};

  /// Optional: system prompt section (tells agent what new components are available).
  String get systemPromptSection => '';
}

// ─────────────────────────────────────────────
// Plugin registry
// ─────────────────────────────────────────────

class AgentUIKitPlugins {
  AgentUIKitPlugins._();

  static final _plugins = <String, AgentUIKitPlugin>{};
  static UIComponentRegistry? _targetRegistry;

  /// Call once after AgentUIKit.initialize() to bind the target registry.
  static void bindRegistry(UIComponentRegistry registry) {
    _targetRegistry = registry;
    // Re-register any plugins registered before binding
    for (final plugin in _plugins.values) {
      plugin.register(registry);
    }
  }

  /// Register a plugin. Safe to call at any time (before or after initialize).
  static void register(AgentUIKitPlugin plugin) {
    if (_plugins.containsKey(plugin.id)) return; // idempotent
    _plugins[plugin.id] = plugin;
    if (_targetRegistry != null) {
      plugin.register(_targetRegistry!);
    }
  }

  /// All registered plugins.
  static List<AgentUIKitPlugin> get all => List.unmodifiable(_plugins.values);

  /// Check if a plugin is installed.
  static bool has(String id) => _plugins.containsKey(id);

  /// Node types covered by all installed plugins.
  static Set<String> get coveredNodeTypes =>
      _plugins.values.expand((p) => p.handledNodeTypes).toSet();

  /// Combined system prompt section from all plugins.
  static String get systemPromptSection {
    final sections = _plugins.values
        .map((p) => p.systemPromptSection)
        .where((s) => s.isNotEmpty)
        .join('\n\n');
    if (sections.isEmpty) return '';
    return '## Plugin Components\n\n$sections';
  }
}

// ─────────────────────────────────────────────
// Built-in placeholder renderers
// ─────────────────────────────────────────────
// These replace the node entirely with a helpful install prompt
// rather than silently rendering nothing.

/// Renders a placeholder card for plugin nodes that aren't installed.
class PluginPlaceholderBuilder {
  const PluginPlaceholderBuilder({
    required this.nodeType,
    required this.pluginId,
    required this.pluginName,
    required this.installHint,
    this.icon = Icons.extension,
  });

  final String nodeType;
  final String pluginId;
  final String pluginName;
  final String installHint;
  final IconData icon;

  Widget build(BuildContext context, UINode node, NodeRenderer renderer) {
    // In release, render nothing
    if (const bool.fromEnvironment('dart.vm.product')) {
      return const SizedBox.shrink();
    }
    return _PluginPlaceholder(
      nodeType: nodeType,
      pluginId: pluginId,
      pluginName: pluginName,
      installHint: installHint,
      icon: icon,
    );
  }
}

class _PluginPlaceholder extends StatelessWidget {
  const _PluginPlaceholder({
    required this.nodeType,
    required this.pluginId,
    required this.pluginName,
    required this.installHint,
    required this.icon,
  });

  final String nodeType;
  final String pluginId;
  final String pluginName;
  final String installHint;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(
          color: Colors.deepPurple.shade200,
          width: 1.5,
          style: BorderStyle.solid,
        ),
        borderRadius: BorderRadius.circular(12),
        color: Colors.deepPurple.shade50,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.deepPurple, size: 20),
              const SizedBox(width: 8),
              Text(
                '$nodeType requires $pluginName',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.deepPurple,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              installHint,
              style: const TextStyle(
                color: Colors.greenAccent,
                fontFamily: 'monospace',
                fontSize: 11,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Package: $pluginId',
            style: TextStyle(color: Colors.deepPurple.shade400, fontSize: 10),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Plugin definitions
// ─────────────────────────────────────────────

/// Charts plugin stub. Replace with real plugin from batik_charts.
class ChartsPlugin extends AgentUIKitPlugin {
  const ChartsPlugin();

  @override
  String get id => 'batik_charts';
  @override
  String get name => 'AgentUIKit Charts';
  @override
  String get version => '1.0.0';
  @override
  List<String> get handledNodeTypes => ['chart'];

  @override
  void register(UIComponentRegistry registry) {
    const placeholder = PluginPlaceholderBuilder(
      nodeType: 'ChartNode',
      pluginId: 'batik_charts',
      pluginName: 'Charts Plugin',
      installHint:
          'dependencies:\n  batik_charts: ^1.0.0\n\n// main.dart:\nAgentUIKitPlugins.register(const ChartsPlugin());',
      icon: Icons.bar_chart,
    );
    registry.register<ChartNode>(placeholder.build);
  }

  @override
  String get systemPromptSection => '''
ChartNode: {"type": "chart", "chartType": "bar|line|pie|area", "data": [{"label":"A","value":10}], "title": "..."}
''';
}

/// Maps plugin stub. Replace with batik_maps.
class MapsPlugin extends AgentUIKitPlugin {
  const MapsPlugin();

  @override
  String get id => 'batik_maps';
  @override
  String get name => 'AgentUIKit Maps';
  @override
  String get version => '1.0.0';
  @override
  List<String> get handledNodeTypes => ['map'];

  @override
  void register(UIComponentRegistry registry) {
    const placeholder = PluginPlaceholderBuilder(
      nodeType: 'MapNode',
      pluginId: 'batik_maps',
      pluginName: 'Maps Plugin',
      installHint:
          'dependencies:\n  batik_maps: ^1.0.0\n\n// main.dart:\nAgentUIKitPlugins.register(const MapsPlugin());',
      icon: Icons.map,
    );
    registry.register<MapNode>(placeholder.build);
  }
}

/// WebView plugin stub. Replace with batik_webview.
class WebViewPlugin extends AgentUIKitPlugin {
  const WebViewPlugin();

  @override
  String get id => 'batik_webview';
  @override
  String get name => 'AgentUIKit WebView';
  @override
  String get version => '1.0.0';
  @override
  List<String> get handledNodeTypes => ['webview'];

  @override
  void register(UIComponentRegistry registry) {
    const placeholder = PluginPlaceholderBuilder(
      nodeType: 'WebViewNode',
      pluginId: 'batik_webview',
      pluginName: 'WebView Plugin',
      installHint:
          'dependencies:\n  batik_webview: ^1.0.0\n\n// main.dart:\nAgentUIKitPlugins.register(const WebViewPlugin());',
      icon: Icons.web,
    );
    registry.register<WebViewNode>(placeholder.build);
  }
}

// ─────────────────────────────────────────────
// Real plugin template (for plugin package authors)
// ─────────────────────────────────────────────

/// Base class for real plugin implementations.
/// Plugin packages extend this and register their actual widgets.
///
/// ```dart
/// // In batik_charts package:
/// class FlChartPlugin extends AgentUIKitPlugin {
///   @override
///   String get id => 'batik_charts';
///   @override
///   String get name => 'AgentUIKit Charts (fl_chart)';
///   @override
///   String get version => '1.0.0';
///   @override
///   List<String> get handledNodeTypes => ['chart'];
///
///   @override
///   void register(UIComponentRegistry registry) {
///     registry.register<ChartNode>((ctx, node, renderer) {
///       return FlChartWidget(node: node); // your real impl
///     });
///   }
/// }
/// ```
abstract class RealPlugin extends AgentUIKitPlugin {
  const RealPlugin();
}
