# Batik Framework

**A model-agnostic Flutter framework for agent-driven UI generation**

Batik is a comprehensive, production-ready framework for building AI agent workflows with dynamic UI generation. Inspired by Google Gemini's GenUI SDK but built to be LLM-provider agnostic, extensible, and production-ready.

## Features

- 🎨 **Agent-Generated UIs** - LLMs can generate complete Flutter UI trees via JSON schema
- 🔄 **Streaming Support** - Real-time incremental UI updates as the agent responds
- ⚡ **Diff-Aware Rendering** - Intelligent diffing preserves widget state across updates
- 🎭 **Animations** - Per-node entrance, update, and exit animations
- 🧩 **Plugin System** - Hot-reloadable plugins with multiple isolation strategies
- 🌐 **Multi-Agent** - Support for multi-agent orchestration and coordination
- 🛠️ **Tool Integration** - MCP (Model Context Protocol) tool support
- 🎯 **Type-Safe** - Strongly-typed action system and state management
- 📱 **Material Design** - Built-in Material 3 components
- 🔌 **Multiple Adapters** - Anthropic, OpenAI, WebSocket, and custom REST adapters

## Installation

Add Batik to your `pubspec.yaml`:

```yaml
dependencies:
  batik: ^0.0.1
```

## Quick Start

### 1. Initialize the Framework

```dart
import 'package:flutter/material.dart';
import 'package:batik/batik.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AgentUIKit.initialize();
  runApp(const ProviderScope(child: MyApp()));
}
```

### 2. Create an Agent Adapter

```dart
// Using the built-in MockAdapter for testing
final adapter = MockAdapter(
  delay: const Duration(milliseconds: 500),
  responseFactory: (input) => AgentUIResponse(
    schemaVersion: '2.0.0',
    root: CardNode(
      style: const UIStyle(padding: UIInsets(all: 16)),
      children: [
        TextNode(text: 'Hello from Batik!', variant: 'titleMedium'),
      ],
    ),
  ),
);

// Or use Anthropic, OpenAI, WebSocket, etc.
final adapter = AnthropicAdapter(apiKey: 'your-key');
```

### 3. Use the Chat Widget

```dart
class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: AgentUIChat(
        adapter: adapter,
        actionHandler: MyActionHandler(),
        inputHint: 'Ask the agent...',
      ),
    );
  }
}
```

### 4. Handle Actions

```dart
class MyActionHandler implements ActionHandler {
  @override
  Future<void> handle(
    BuildContext context,
    UIAction action,
    Map<String, dynamic> variables,
  ) async {
    switch (action.type) {
      case ActionTypes.agentMessage:
        // Handle agent message
        break;
      case ActionTypes.navigate:
        // Handle navigation
        break;
      case ActionTypes.custom:
        // Handle custom actions
        break;
    }
  }
}
```

## Architecture

Batik follows a modular architecture with clear separation of concerns:

```
lib/
├── batik.dart              # Main entry point
└── src/
    ├── schema/             # UI schema definitions
    ├── core/               # Core interfaces
    ├── adapters/           # Agent adapters
    ├── renderer/           # UI renderer
    ├── state/              # Riverpod state
    ├── streaming/          # Streaming support
    ├── diff/               # Diff engine
    ├── animation/          # Animations
    ├── widgets/            # High-level widgets
    ├── components/         # Component builders
    ├── theme/              # Theming
    ├── plugin/             # Plugin system
    └── utils/              # Utilities
```

See [STRUCTURE.md](STRUCTURE.md) for detailed documentation.

## Core Concepts

### UI Schema

Batik uses a JSON schema to represent UI trees. The LLM generates this schema, and Batik renders it into Flutter widgets.

```json
{
  "schemaVersion": "2.0.0",
  "root": {
    "type": "scaffold",
    "body": {
      "type": "column",
      "children": [
        {"type": "text", "text": "Hello World"},
        {"type": "button", "label": "Click Me"}
      ]
    }
  }
}
```

### Nodes

Batik provides a comprehensive set of built-in nodes:

- **Layout**: Container, Row, Column, Stack, Grid
- **Content**: Text, RichText, Image, Icon, Markdown
- **Interactive**: Button, IconButton, TextField, Switch, Slider, Dropdown
- **Structural**: Card, List, ListItem, Form
- **Navigation**: Scaffold, AppBar, BottomNav, Fab
- **Overlays**: Dialog, Snackbar
- **Decoration**: Divider, Spacer, Badge, Chip, Avatar, ProgressBar

### Actions

Actions define what happens when users interact with the UI:

```dart
ButtonNode(
  label: 'Submit',
  actions: {
    'onTap': UIAction(
      type: ActionTypes.agentMessage,
      payload: {'message': 'Form submitted'},
    ),
  },
)
```

Built-in action types:
- `agentMessage` - Send message to agent
- `navigate` - Navigate to a route
- `setVariable` - Store a variable
- `openUrl` - Open a URL
- `dismiss` - Dismiss overlay
- `custom` - Custom handler

### Variables

Variables provide state management across turns:

```dart
TextFieldNode(
  label: 'Email',
  variableBinding: 'email',
)

// Access in actions
{{email}}
```

## Adapters

### MockAdapter

Perfect for testing and offline development:

```dart
final adapter = MockAdapter(
  delay: const Duration(milliseconds: 500),
  responseFactory: (input) => /* your UI response */,
);
```

### AnthropicAdapter

Connect to Claude via Anthropic API:

```dart
final adapter = AnthropicAdapter(
  apiKey: 'your-api-key',
  model: 'claude-opus-4-6',
);
```

### OpenAIAdapter

Connect to GPT-4o via OpenAI API:

```dart
final adapter = OpenAIAdapter(
  apiKey: 'your-api-key',
  model: 'gpt-4o',
);
```

### WebSocketAgentAdapter

Real-time bidirectional communication:

```dart
final adapter = WebSocketAgentAdapter(
  client: WayangAssistantWebSocketClient(
    url: 'ws://your-server.com/ws',
  ),
);
```

## Advanced Features

### Streaming

Enable real-time streaming responses:

```dart
AgentUIChat(
  adapter: adapter,
  useStreaming: true,
  showToolStatusIndicator: true,
)
```

### Animations

Configure animations globally:

```dart
AgentUIRenderer(
  response: response,
  animationConfig: AnimationConfig(
    entranceAnimation: UIAnimation(type: 'fadeIn'),
    enableUpdateAnimations: true,
    staggerDelay: Duration(milliseconds: 40),
  ),
)
```

### Multi-Agent Orchestration

Coordinate multiple specialized agents:

```dart
MultiAgentOrchestrator(
  agents: [researchAgent, codingAgent, reviewAgent],
  orchestrator: myOrchestrator,
)
```

### Custom Components

Register custom widget builders:

```dart
UIComponentRegistry.instance.registerCustom(
  'myChart',
  (context, node, renderer) => MyCustomChartWidget(node),
);
```

### Plugins

Create hot-reloadable plugins:

```dart
class MyPlugin implements Plugin {
  @override
  String get id => 'my-plugin';
  
  @override
  void onLoad() {
    // Register components, actions, etc.
  }
}

AgentUIKitPlugins.register(MyPlugin());
```

## Example Application

See `lib/main.dart` for a complete example demonstrating:
- Chat interface with MockAdapter
- Static UI rendering
- Component gallery
- Custom action handlers

Run the example:

```bash
cd lib
flutter run
```

## Migration Guide

### From agent_ui_kit to batik

If you're migrating from the previous `agent_ui_kit` package:

1. Update dependencies:
```yaml
dependencies:
  batik: ^0.1.0  # was: agent_ui_kit: ^0.1.0
```

2. Update imports:
```dart
// Old
import 'package:agent_ui_kit/agent_ui_kit.dart';

// New
import 'package:batik/batik.dart';
```

3. Update initialization:
```dart
// Old
AgentUIKit.initialize();

// New (same API)
await AgentUIKit.initialize();
```

All other APIs remain backward compatible.

## Documentation

- [Project Structure](STRUCTURE.md) - Detailed module documentation
- [API Reference](docs/API.md) - Complete API documentation
- [Examples](examples/) - More example applications
- [Plugins](docs/PLUGINS.md) - Plugin development guide

## Contributing

We welcome contributions! Please see our [Contributing Guide](CONTRIBUTING.md) for details.

### Development Setup

```bash
# Clone the repository
git clone https://github.com/your-org/batik.git

# Install dependencies
flutter pub get

# Run tests
flutter test

# Run the example
cd lib && flutter run
```

## Roadmap

- [ ] Additional LLM adapters (Gemini, Mistral, etc.)
- [ ] Enhanced plugin isolation (WASM, containers)
- [ ] Visual workflow designer
- [ ] Advanced orchestration patterns
- [ ] Memory and context management
- [ ] Guardrails and safety policies
- [ ] Performance optimization tools
- [ ] Enhanced accessibility support

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- Inspired by Google Gemini's GenUI SDK
- Built with [Flutter](https://flutter.dev)
- State management by [Riverpod](https://riverpod.dev)
- Animations by [flutter_animate](https://pub.dev/packages/flutter_animate)

## Support

- **Issues**: [GitHub Issues](https://github.com/your-org/batik/issues)
- **Discussions**: [GitHub Discussions](https://github.com/your-org/batik/discussions)
- **Discord**: [Join our Discord](https://discord.gg/your-org)

---

Made with ❤️ by the Batik Team
