// lib/batik.dart — Batik Framework Public API
// ============================================================
// Main entry point for the Batik framework.
// Import this file to access all framework features.
//
// Usage:
//   import 'package:batik/batik.dart';
// ============================================================
library batik;

// Export everything from the src directory
export 'src/batik.dart';
export 'src/diagram/diagram_graph.dart';
export 'src/diagram/diagram_renderer.dart';
export 'src/diagram/mermaid_parser.dart';

// Bootstrap and initialization
import 'src/schema/ui_schema.dart' as ui_schema;
import 'src/components/builtin_components.dart';
import 'src/plugin/plugin_registry.dart';
import 'src/core/registry.dart';

/// Batik Framework initialization class.
///
/// Call [AgentUIKit.initialize()] once before [runApp()] to set up
/// the framework with built-in components and plugins.
///
/// Example:
/// ```dart
/// void main() async {
///   WidgetsFlutterBinding.ensureInitialized();
///   await AgentUIKit.initialize();
///   runApp(const ProviderScope(child: MyApp()));
/// }
/// ```
class AgentUIKit {
  AgentUIKit._();
  static bool _initialized = false;

  /// Initialize the Batik framework.
  ///
  /// This method:
  /// - Bootstraps the UI schema
  /// - Registers all built-in components
  /// - Binds plugin registry
  ///
  /// Call this once before [runApp()] in your main() function.
  static Future<void> initialize({UIComponentRegistry? registry}) async {
    if (_initialized) return;
    _bootstrapSchema();
    registerBuiltinComponents(registry);
    AgentUIKitPlugins.bindRegistry(registry ?? UIComponentRegistry.instance);
    _initialized = true;
  }

  static void _bootstrapSchema() {
    ui_schema.bootstrapSchema();
  }
}
