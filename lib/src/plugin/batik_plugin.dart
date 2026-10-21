// lib/src/plugin/batik_plugin.dart
//
// Batik — Plugin API v2 (Patch 029)
// ============================================================
// Elevates plugins to a first-class runtime concept.
//
// Every plugin declares:
//   • id + version
//   • capabilities (chart, diagram, datasource, workflow…)
//   • optional schema extensions
//   • optional system-prompt section (tells LLMs about new nodes)
//
// Then registers its node builders, action handlers, themes,
// and data sources into the shared registries via BatikRuntime.
//
// Built-in stubs for Tenun, Diagram, Maps, and WebView are kept
// compatible with the old AgentUIKitPlugin contract.
// ============================================================

import 'package:flutter/widgets.dart';
import '../core/registry.dart';
import '../datasource/data_source.dart';

// ─────────────────────────────────────────────
// 1. Capability enum
// ─────────────────────────────────────────────

/// What a plugin provides to the Batik runtime.
enum PluginCapability {
  /// Registers chart node builders (Tenun, fl_chart, charts_flutter…).
  chart,

  /// Registers diagram node builders (flowchart, sequence, mindmap…).
  diagram,

  /// Registers one or more [DataSource] implementations.
  datasource,

  /// Registers workflow node types and executors.
  workflow,

  /// Registers 3D scene node builders (Tenun 3D…).
  scene3d,

  /// Registers document block renderers.
  document,

  /// Registers theme/color overrides.
  theme,

  /// Registers GIS / map node builders.
  map,
}

// ─────────────────────────────────────────────
// 2. Plugin manifest
// ─────────────────────────────────────────────

/// Static metadata about a plugin.
class PluginManifest {
  const PluginManifest({
    required this.id,
    required this.version,
    this.dependencies = const [],
    this.capabilities = const [],
    this.description = '',
  });

  /// Globally unique reverse-DNS style id: "com.example.batik_charts"
  final String id;

  /// SemVer string: "1.0.0"
  final String version;

  /// IDs of other plugins that must be loaded first.
  final List<String> dependencies;

  /// Capabilities this plugin advertises.
  final List<PluginCapability> capabilities;

  final String description;
}

// ─────────────────────────────────────────────
// 3. BatikPlugin contract (v2)
// ─────────────────────────────────────────────

/// The plugin contract every Batik extension must implement.
///
/// The runtime calls methods in this order:
///   1. [manifest] — read metadata + validate dependencies
///   2. [initialize] — async setup (network, FFI, native…)
///   3. [registerNodes] — add node builders to [UIComponentRegistry]
///   4. [registerDataSources] — add sources to [DataSourceRegistry]
///   5. [registerActions] — add action handlers (optional)
///   6. [registerThemes] — add theme overrides (optional)
abstract class BatikPlugin {
  const BatikPlugin();

  PluginManifest get manifest;

  // Convenience getters delegating to manifest
  String get id => manifest.id;
  String get version => manifest.version;
  List<PluginCapability> get capabilities => manifest.capabilities;

  /// Called once after the runtime is ready. Use for async init.
  Future<void> initialize(BatikRuntime runtime) async {}

  /// Register Flutter widget builders for new UINode types.
  void registerNodes(UIComponentRegistry registry) {}

  /// Register [DataSource] implementations.
  void registerDataSources(DataSourceRegistry registry) {}

  /// Register named action handlers.
  void registerActions(ActionRegistry registry) {}

  /// Register theme/color extensions.
  void registerThemes(ThemeRegistry registry) {}

  /// Optional: extra JSON schema properties this plugin introduces.
  Map<String, dynamic> get schemaExtensions => const {};

  /// Optional: system-prompt section that tells LLMs about new node types.
  String get systemPromptSection => '';
}

// ─────────────────────────────────────────────
// 4. Lightweight registries for actions / themes
// ─────────────────────────────────────────────

typedef PluginActionHandler = Future<void> Function(Map<String, dynamic> payload);

class ActionRegistry {
  final _handlers = <String, PluginActionHandler>{};

  void register(String type, PluginActionHandler handler) =>
      _handlers[type] = handler;

  PluginActionHandler? operator [](String type) => _handlers[type];

  bool has(String type) => _handlers.containsKey(type);
}

class ThemeRegistry {
  final _extensions = <String, Map<String, dynamic>>{};

  void register(String id, Map<String, dynamic> themeData) =>
      _extensions[id] = themeData;

  Map<String, dynamic>? operator [](String id) => _extensions[id];

  Iterable<String> get ids => _extensions.keys;
}

// ─────────────────────────────────────────────
// 5. BatikRuntime — loads and manages plugins
// ─────────────────────────────────────────────

/// The central Batik runtime singleton.
///
/// ```dart
/// final runtime = BatikRuntime.instance;
///
/// await runtime.loadPlugin(TenunPlugin());
/// await runtime.loadPlugin(DiagramPlugin());
/// await runtime.initialize();
/// ```
class BatikRuntime {
  BatikRuntime._();
  static final instance = BatikRuntime._();

  final _plugins = <String, BatikPlugin>{};
  final _pluginLoadOrder = <String>[];

  final nodeRegistry = UIComponentRegistry.instance;
  final dataSourceRegistry = DataSourceRegistry.instance;
  final actionRegistry = ActionRegistry();
  final themeRegistry = ThemeRegistry();

  bool _initialized = false;

  /// Register a plugin. Can be called before [initialize].
  void loadPlugin(BatikPlugin plugin) {
    final id = plugin.id;
    if (_plugins.containsKey(id)) return; // idempotent
    _plugins[id] = plugin;
    _pluginLoadOrder.add(id);
  }

  /// Initialize all loaded plugins in dependency order.
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    // Topological ordering: respect declared dependencies.
    final ordered = _resolveDependencyOrder();
    for (final id in ordered) {
      final plugin = _plugins[id]!;
      await plugin.initialize(this);
      plugin.registerNodes(nodeRegistry);
      plugin.registerDataSources(dataSourceRegistry);
      plugin.registerActions(actionRegistry);
      plugin.registerThemes(themeRegistry);
    }
  }

  // ── Queries ──────────────────────────────────────────────────

  bool hasPlugin(String id) => _plugins.containsKey(id);

  List<BatikPlugin> get allPlugins =>
      _pluginLoadOrder.map((id) => _plugins[id]!).toList();

  List<BatikPlugin> pluginsWithCapability(PluginCapability cap) =>
      _plugins.values.where((p) => p.capabilities.contains(cap)).toList();

  /// Combined system-prompt additions from all plugins.
  String get pluginSystemPrompt {
    final sections = _plugins.values
        .map((p) => p.systemPromptSection)
        .where((s) => s.isNotEmpty)
        .join('\n\n');
    if (sections.isEmpty) return '';
    return '## Batik Plugin Components\n\n$sections';
  }

  // ── Internals ────────────────────────────────────────────────

  List<String> _resolveDependencyOrder() {
    final visited = <String>{};
    final result = <String>[];

    void visit(String id) {
      if (visited.contains(id)) return;
      visited.add(id);
      final plugin = _plugins[id];
      if (plugin == null) return;
      for (final dep in plugin.manifest.dependencies) {
        visit(dep);
      }
      result.add(id);
    }

    for (final id in _pluginLoadOrder) {
      visit(id);
    }
    return result;
  }
}

// ─────────────────────────────────────────────
// 6. Backward-compat bridge
// ─────────────────────────────────────────────
// AgentUIKitPlugin from plugin_registry.dart is kept as-is.
// New plugins implement BatikPlugin instead.

/// Adapter that wraps a legacy [AgentUIKitPlugin] (v1) as a [BatikPlugin].
///
/// This lets teams migrate to the v2 API incrementally without
/// changing existing plugin packages.
abstract class LegacyPluginAdapter implements BatikPlugin {
  const LegacyPluginAdapter();

  /// The v1 plugin this adapter wraps.
  dynamic get legacyPlugin;

  @override
  void registerNodes(UIComponentRegistry registry) {
    // ignore: avoid_dynamic_calls
    (legacyPlugin as dynamic).register(registry);
  }

  @override
  void registerDataSources(DataSourceRegistry registry) {}
  @override
  void registerActions(ActionRegistry registry) {}
  @override
  void registerThemes(ThemeRegistry registry) {}
}

// ─────────────────────────────────────────────
// 7. Placeholder widget (shared utility)
// ─────────────────────────────────────────────

/// Shows a coloured install-hint card in debug mode; invisible in release.
class PluginRequiredPlaceholder extends StatelessWidget {
  const PluginRequiredPlaceholder({
    super.key,
    required this.nodeType,
    required this.pluginId,
    required this.installHint,
    this.icon,
  });

  final String nodeType;
  final String pluginId;
  final String installHint;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    if (const bool.fromEnvironment('dart.vm.product')) {
      return const SizedBox.shrink();
    }
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFF7C4DFF), width: 1.5),
        borderRadius: BorderRadius.circular(10),
        color: const Color(0xFFEDE7F6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            if (icon != null)
              Icon(icon, color: const Color(0xFF7C4DFF), size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '$nodeType — plugin $pluginId required',
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF7C4DFF),
                    fontSize: 13),
              ),
            ),
          ]),
          const SizedBox(height: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
                color: const Color(0xFF212121),
                borderRadius: BorderRadius.circular(6)),
            child: Text(
              installHint,
              style: const TextStyle(
                  color: Color(0xFF69FF47),
                  fontFamily: 'monospace',
                  fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}
