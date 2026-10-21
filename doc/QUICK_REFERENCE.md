# Batik Framework - Quick Reference Guide

## 📦 Package Info

- **Name**: `batik`
- **Version**: 0.1.0
- **Description**: Agent-driven UI generation framework for Flutter
- **Main Import**: `import 'package:batik/batik.dart';`

## 🚀 Quick Start

```dart
import 'package:flutter/material.dart';
import 'package:batik/batik.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AgentUIKit.initialize();
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: AgentUIChat(
        adapter: MockAdapter(),
        actionHandler: MyActionHandler(),
      ),
    );
  }
}
```

## 📁 Module Structure

| Module | Purpose | Key Classes |
|--------|---------|-------------|
| `schema/` | UI tree definitions | `UINode`, `UIStyle`, `UIAction`, `AgentUIResponse` |
| `core/` | Fundamental interfaces | `UIComponentRegistry`, `ActionDispatcher`, `VariableStore` |
| `adapters/` | Agent communication | `AgentAdapter`, `AnthropicAdapter`, `OpenAIAdapter`, `MockAdapter` |
| `renderer/` | UI rendering | `AgentUIRenderer`, `RendererImpl` |
| `state/` | Riverpod providers | `AgentSessionNotifier`, `VariableStoreNotifier` |
| `streaming/` | Real-time updates | `StreamingUIParser`, `WayangAssistantWebSocketClient` |
| `diff/` | Tree diffing | `UIDiffEngine`, `DiffResult`, `UIPatch` |
| `animation/` | Animations | `AnimatedUINode`, `UIAnimation`, `AnimationConfig` |
| `widgets/` | High-level widgets | `AgentUIChat`, `SkeletonLoader`, `MultiAgentOrchestrator` |
| `components/` | Component builders | `registerBuiltinComponents()` |
| `theme/` | Theming | `AgentColorTokens`, `AgentTypographyTokens` |
| `plugin/` | Plugin system | `AgentUIKitPlugins`, `Plugin` |
| `utils/` | Utilities | `ResponseCache`, `SemanticsBuilder` |

## 🎨 Common UI Nodes

### Layout
```dart
ContainerNode(children: [...])
RowNode(children: [...], mainAxisAlignment: 'center')
ColumnNode(children: [...], crossAxisAlignment: 'start')
StackNode(children: [...])
GridNode(crossAxisCount: 2, children: [...])
```

### Content
```dart
TextNode(text: 'Hello', variant: 'titleMedium')
RichTextNode(spans: [...])
ImageNode(src: 'url', fit: 'cover')
IconNode(icon: 'home', size: 24)
MarkdownNode(content: '# Heading')
```

### Interactive
```dart
ButtonNode(label: 'Click', variant: 'filled', actions: {...})
IconButtonNode(icon: 'search', tooltip: 'Search')
TextFieldNode(label: 'Email', variableBinding: 'email')
SwitchNode(value: true, label: 'Enable', variableBinding: 'enabled')
SliderNode(value: 0.5, min: 0, max: 1, variableBinding: 'volume')
DropdownNode(options: [...], variableBinding: 'choice')
```

### Structural
```dart
CardNode(elevation: 2, children: [...])
ListNode(children: [...], shrinkWrap: true)
ListItemNode(leading: ..., title: ..., trailing: ...)
FormNode(children: [...])
```

### Navigation
```dart
ScaffoldNode(
  appBar: AppBarNode(title: ...),
  body: ColumnNode(...),
  bottomNav: BottomNavNode(items: [...]),
  fab: FabNode(icon: 'add'),
)
```

### Overlays
```dart
DialogNode(
  title: ...,
  content: ...,
  confirmAction: ...,
  cancelAction: ...,
)
SnackbarNode(message: 'Done', duration: 3000)
```

### Decoration
```dart
DividerNode()
SpacerNode(height: 16)
BadgeNode(label: '5', children: [...])
ChipNode(label: 'Filter', variant: 'filter')
AvatarNode(initials: 'JD', size: 40)
ProgressBarNode(value: 0.75)
```

## ⚡ Actions

### Built-in Action Types

```dart
// Send message to agent
UIAction(
  type: ActionTypes.agentMessage,
  payload: {'message': 'User clicked button'},
)

// Navigate to route
UIAction(
  type: ActionTypes.navigate,
  payload: {'route': '/details'},
)

// Store variable
UIAction(
  type: ActionTypes.setVariable,
  payload: {'key': 'selected', 'value': 'option1'},
)

// Open URL
UIAction(
  type: ActionTypes.openUrl,
  payload: {'url': 'https://example.com'},
)

// Custom handler
UIAction(
  type: ActionTypes.custom,
  payload: {'handler': 'myHandler', 'data': ...},
)
```

### Action Handler

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
        final message = action.payload['message'] as String;
        // Handle agent message
        break;
      case ActionTypes.custom:
        final handler = action.payload['handler'] as String?;
        // Handle custom action
        break;
    }
  }
}
```

## 🔄 Variables

### Binding Variables

```dart
TextFieldNode(
  label: 'Email',
  variableBinding: 'email',
)

SwitchNode(
  value: true,
  variableBinding: 'notifications',
)
```

### Using Variables in Text

```dart
TextNode(text: 'Hello, {{username}}!')
```

### Accessing Variables

```dart
final store = context.agentVariables;
final email = store.get<String>('email');
store.set('count', 42);
```

## 🎭 Animations

### Animation Config

```dart
AnimationConfig(
  entranceAnimation: UIAnimation(type: 'fadeIn'),
  updateAnimation: UIAnimation(type: 'scale'),
  enableEntranceAnimations: true,
  enableUpdateAnimations: true,
  staggerDelay: Duration(milliseconds: 40),
)
```

### Animation Types

- `fadeIn` - Fade in
- `slideUp`, `slideDown`, `slideLeft`, `slideRight` - Slide animations
- `scale` - Scale up/down
- `shimmer` - Shimmer effect
- `bounce` - Bounce animation
- `flip` - Flip animation

## 🌐 Adapters

### Mock Adapter

```dart
final adapter = MockAdapter(
  delay: const Duration(milliseconds: 500),
  responseFactory: (input) => AgentUIResponse(
    schemaVersion: '2.0.0',
    root: CardNode(children: [...]),
  ),
);
```

### Anthropic Adapter

```dart
final adapter = AnthropicAdapter(
  apiKey: 'your-api-key',
  model: 'claude-opus-4-6',
  maxTokens: 4096,
);
```

### OpenAI Adapter

```dart
final adapter = OpenAIAdapter(
  apiKey: 'your-api-key',
  model: 'gpt-4o',
  maxTokens: 4096,
);
```

### WebSocket Adapter

```dart
final adapter = WebSocketAgentAdapter(
  client: WayangAssistantWebSocketClient(
    url: 'ws://localhost:8080/ws',
  ),
);
```

## 🧩 Custom Components

### Register Custom Component

```dart
UIComponentRegistry.instance.registerCustom(
  'myChart',
  (context, node, renderer) {
    return MyCustomChartWidget(
      data: node.props['data'],
      type: node.props['type'],
    );
  },
);
```

### Custom Node Type

```dart
class ChartNode extends UINode with _NodeJsonBase {
  ChartNode({
    super.id,
    super.style,
    super.actions,
    required this.chartType,
    required this.data,
  }) : super(type: 'chart', children: const []);

  final String chartType;
  final List<Map<String, dynamic>> data;

  factory ChartNode.fromJson(Map<String, dynamic> j) => ChartNode(
    id: j['id'] as String?,
    style: _parseStyle(j),
    actions: _parseActions(j),
    chartType: j['chartType'] as String,
    data: List<Map<String, dynamic>>.from(j['data'] as List),
  );

  @override
  Map<String, dynamic> toJson() => {
    ..._baseJson(),
    'chartType': chartType,
    'data': data,
  };
}
```

## 🎯 Styling

### UIStyle Properties

```dart
UIStyle(
  backgroundColor: '#6750A4',
  foregroundColor: '#FFFFFF',
  borderColor: '#CCCCCC',
  borderRadius: 8,
  borderWidth: 1,
  padding: UIInsets(all: 16),
  margin: UIInsets(top: 8, bottom: 8),
  width: 200,
  height: 100,
  opacity: 0.8,
  elevation: 4,
  fontSize: 16,
  fontWeight: 'bold',
  fontFamily: 'Roboto',
  textAlign: 'center',
  overflow: 'ellipsis',
  flex: 1,
  alignment: 'center',
)
```

### applyStyle Helper

```dart
Widget _buildContainer(BuildContext ctx, ContainerNode node, NodeRenderer r) {
  Widget child = Column(children: r.renderChildren(ctx, node.children));
  return applyStyle(child, node.style);
}
```

## 📊 State Management

### Riverpod Providers

```dart
// Watch session state
final sessionState = ref.watch(agentSessionProvider(config));

// Send message
ref.read(agentSessionProvider(config).notifier).sendMessage('Hello');

// Access variables
final vars = ref.watch(sessionVariableStoreProvider(sessionId));
ref.read(sessionVariableStoreProvider(sessionId).notifier).set('key', value);
```

### Session Config

```dart
final config = AgentSessionConfig(
  sessionId: 'my-session',
  initialMessages: [...],
  adapter: myAdapter,
);
```

## 🛠️ Utilities

### Skeleton Loader

```dart
SkeletonLoader(
  lines: 3,
  showAvatar: true,
  showHeader: true,
  shimmerDuration: Duration(milliseconds: 1200),
)
```

### Response Cache

```dart
final cache = ResponseCache();
cache.set('key', response, ttl: Duration(minutes: 5));
final cached = cache.get('key');
```

### Semantics Builder

```dart
final semantics = SemanticsBuilder();
semantics.label = 'Button';
semantics.actions = [SemanticsAction.tap];
```

## 📝 Best Practices

1. **Always initialize**: Call `AgentUIKit.initialize()` before `runApp()`
2. **Use Riverpod**: Leverage providers for state management
3. **Handle errors**: Provide `onError` callbacks
4. **Type safety**: Use typed action handlers
5. **Variable binding**: Bind form inputs to variables
6. **Custom components**: Register early in app lifecycle
7. **Streaming**: Enable for better UX on slow connections
8. **Animations**: Use sparingly for better performance

## 🔗 Resources

- **Full Documentation**: See `README.md` and `STRUCTURE.md`
- **Example App**: See `lib/main.dart`
- **API Reference**: See individual file documentation
- **Changelog**: See `CHANGELOG_REORGANIZATION.md`

---

For more help, visit our GitHub repository or join our Discord community.
