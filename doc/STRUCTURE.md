# Batik Framework - Project Structure

## Overview

The Batik framework follows a modular, separation-of-concerns architecture designed for maintainability, scalability, and ease of use. All source code is organized under the `lib/src/` directory with clear boundaries between different functional areas.

## Directory Structure

```
lib/
├── batik.dart                    # Main public API entry point
├── src/                          # Source code (internal implementation)
│   ├── batik.dart                # Internal barrel export
│   │
│   ├── schema/                   # UI Schema definitions
│   │   ├── ui_schema.dart        # Core UI node types (UINode, UIStyle, etc.)
│   │   └── schema_validator.dart # JSON schema validation
│   │
│   ├── core/                     # Fundamental interfaces & utilities
│   │   ├── registry.dart         # Component registry (UIComponentRegistry)
│   │   ├── action_dispatcher.dart # Action handling system
│   │   └── style_utils.dart      # Style parsing and utilities
│   │
│   ├── adapters/                 # Agent communication layer
│   │   ├── agent_adapter.dart    # Base adapter interface + implementations
│   │   └── system_prompt_builder.dart # LLM prompt generation
│   │
│   ├── renderer/                 # UI rendering engine
│   │   ├── ui_renderer.dart      # Main renderer (AgentUIRenderer)
│   │   └── virtual_list_renderer.dart # Virtualized list rendering
│   │
│   ├── state/                    # Riverpod state management
│   │   └── agent_providers.dart  # All Riverpod providers
│   │
│   ├── streaming/                # Real-time streaming support
│   │   ├── streaming_parser.dart # Incremental JSON parser
│   │   ├── websocket_client.dart # WebSocket client
│   │   └── websocket_agent_adapter.dart # WS-based adapter
│   │
│   ├── diff/                     # Diff/patch engine
│   │   └── ui_diff_engine.dart   # Tree diffing algorithm
│   │
│   ├── animation/                # Animation system
│   │   └── animated_node_renderer.dart # Animated rendering
│   │
│   ├── widgets/                  # High-level widgets
│   │   ├── agent_ui_chat.dart    # Main chat widget
│   │   ├── multi_agent_orchestrator.dart # Multi-agent coordination
│   │   ├── agent_tool_runner.dart # Tool execution
│   │   ├── agent_localizations.dart # i18n support
│   │   ├── agent_inspector.dart  # DevTools inspector
│   │   ├── session_persistence.dart # Session storage
│   │   ├── agent_ui_theme.dart   # Widget theming
│   │   └── skeleton_loader.dart  # Loading skeleton widget
│   │
│   ├── components/               # Component builders
│   │   ├── builtin_components.dart # Built-in component builders
│   │   └── batik_components.dart # Batik-specific components
│   │
│   ├── theme/                    # Theming system
│   │   ├── batik_theme.dart      # Theme definitions
│   │   └── batik_colors.dart     # Color palette
│   │
│   ├── plugin/                   # Plugin system
│   │   └── plugin_registry.dart  # Plugin management
│   │
│   └── utils/                    # Utility classes
│       ├── response_cache.dart   # Response caching
│       ├── semantics_builder.dart # Accessibility support
│       └── typed_actions.dart    # Type-safe actions
│
└── main.dart                     # Example application
```

## Module Responsibilities

### Schema (`schema/`)
- Defines the canonical UI tree structure
- All node types (Text, Button, Card, etc.)
- Style system (UIStyle, UIInsets, etc.)
- Action system (UIAction)
- JSON serialization/deserialization

### Core (`core/`)
- Component registry for custom widgets
- Action dispatching and handling
- Style parsing utilities
- Fundamental interfaces used throughout

### Adapters (`adapters/`)
- Agent communication abstraction
- Built-in adapters (Anthropic, OpenAI, Mock, WebSocket)
- System prompt generation for LLMs

### Renderer (`renderer/`)
- Transforms UI trees into Flutter widgets
- Diff-aware rendering
- Expression evaluation ({{variable}} templating)
- Virtual list optimization

### State (`state/`)
- Riverpod providers for all framework state
- Session-scoped variable stores
- Agent session management
- Tool call tracking

### Streaming (`streaming/`)
- Incremental JSON parsing
- Real-time UI updates
- WebSocket communication
- Stream event handling

### Diff (`diff/`)
- Tree comparison algorithm
- Minimal patch generation
- Change detection for animations

### Animation (`animation/`)
- Per-node entrance animations
- Update/exit transitions
- Shimmer effects
- Motion preferences

### Widgets (`widgets/`)
- High-level, ready-to-use widgets
- AgentUIChat (main chat interface)
- Multi-agent orchestration
- Developer tools (inspector)
- Session persistence

### Components (`components/`)
- Built-in component builders
- All standard Material widgets
- Custom component support

### Theme (`theme/`)
- Color tokens
- Typography tokens
- Theme customization

### Plugin (`plugin/`)
- Plugin lifecycle management
- Plugin registry
- Hot-reload support

### Utils (`utils/`)
- Response caching
- Accessibility (semantics)
- Type-safe action helpers

## Import Guidelines

### For Framework Users

Import only the main entry point:

```dart
import 'package:batik/batik.dart';

void main() {
  AgentUIKit.initialize();
  runApp(MyApp());
}
```

### For Framework Developers

Import from specific modules:

```dart
import '../schema/ui_schema.dart';
import '../core/registry.dart';
import '../renderer/ui_renderer.dart';
```

Use relative imports within `src/` and avoid circular dependencies.

## Separation of Concerns

### What Goes Where?

1. **Schema**: Pure data structures, no Flutter dependencies
2. **Core**: Abstract interfaces, no business logic
3. **Adapters**: External communication only
4. **Renderer**: Widget tree materialization only
5. **State**: Riverpod providers only
6. **Streaming**: Stream processing only
7. **Widgets**: Complete, reusable widgets
8. **Components**: Individual widget builders
9. **Utils**: Cross-cutting concerns

### Dependency Rules

- Lower layers cannot depend on upper layers
- Schema is the foundation (no dependencies)
- Core depends only on Schema
- Renderer depends on Schema + Core
- State depends on Schema + Core + Adapters
- Widgets depend on everything below

## Modular Widgets

The framework extracts common UI patterns into reusable widgets:

### SkeletonLoader
```dart
SkeletonLoader(
  lines: 3,
  showAvatar: true,
  showHeader: true,
)
```

### AgentUIChat
```dart
AgentUIChat(
  adapter: MyAdapter(),
  actionHandler: MyHandler(),
  showInputBar: true,
)
```

### MultiAgentOrchestrator
```dart
MultiAgentOrchestrator(
  agents: [agent1, agent2],
  orchestrator: myOrchestrator,
)
```

## Best Practices

### For Component Authors

1. Register custom components in `components/`
2. Follow the builder pattern: `Widget build(BuildContext, Node, Renderer)`
3. Use `applyStyle()` for consistent styling
4. Handle actions via `context.agentDispatcher`

### For Widget Authors

1. Extract reusable widgets to `widgets/`
2. Use Riverpod for state management
3. Support customization via callbacks
4. Include loading/error states

### For Plugin Authors

1. Use `plugin_registry.dart` interfaces
2. Implement hot-reload compatibility checks
3. Follow isolation strategies
4. Register via `AgentUIKitPlugins`

## Migration Guide (from old structure)

If you're updating from the previous flat structure:

### Old Imports
```dart
import 'package:batik/agent_ui_chat.dart';
import 'package:batik/agent_adapter.dart';
import 'package:batik/ui_renderer.dart';
```

### New Imports
```dart
import 'package:batik/batik.dart'; // Everything exported from main file
```

Or for specific modules:
```dart
import 'package:batik/src/widgets/agent_ui_chat.dart';
import 'package:batik/src/adapters/agent_adapter.dart';
import 'package:batik/src/renderer/ui_renderer.dart';
```

## Future Enhancements

Planned additions to the structure:

1. **`tools/`** - MCP tool implementations
2. **`memory/`** - Conversation memory management
3. **`guardrails/`** - Safety and policy enforcement
4. **`orchestration/`** - Advanced workflow patterns
5. **`testing/`** - Test utilities and mocks

## Questions?

For questions about the structure or where to place new code:
- Check existing modules for similar functionality
- Follow the dependency rules
- Keep separation of concerns clear
- Ask in the framework's issue tracker
