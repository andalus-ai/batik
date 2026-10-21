# Batik Framework Example

This example application demonstrates the capabilities of the Batik framework for building agent-driven UI applications.

## Features Demonstrated

### 1. **Chat Interface** (`lib/main.dart` - Chat Tab)
- Real-time agent conversation with streaming support
- Smart mock adapter that generates different UIs based on user input
- Custom action handling
- Entrance animations
- Tool status indicators
- Error handling

**Try these commands:**
- "Show login form"
- "Show dashboard"
- "Show settings"
- "Show profile"
- "Show chat interface"

### 2. **Component Gallery** (`lib/main.dart` - Components Tab)
- Buttons (Elevated, Filled, Outlined, Text)
- Form controls (TextField, Switch, Slider, Dropdown)
- Cards and Lists
- Progress indicators
- Badges and Chips
- Avatars

### 3. **Multi-Agent Demo** (`lib/main.dart` - Multi-Agent Tab)
- Demonstrates multi-agent orchestration concept
- Shows how multiple specialized agents can work together

### 4. **Settings** (`lib/main.dart` - Settings Tab)
- Animation toggles
- Streaming configuration
- Theme customization
- Adapter selection

## Running the Example

### Prerequisites
- Flutter SDK 3.10.0 or higher
- Dart SDK 3.0.0 or higher

### Setup

1. **Navigate to the example directory:**
   ```bash
   cd wayang-ui/batik/example
   ```

2. **Get dependencies:**
   ```bash
   flutter pub get
   ```

3. **Run the app:**
   ```bash
   flutter run
   ```

### Running on Different Platforms

```bash
# Android
flutter run -d android

# iOS
flutter run -d ios

# Web
flutter run -d chrome

# macOS
flutter run -d macos
```

## Architecture

### Main Components

1. **`main.dart`** - Complete example application
   - `BatikExampleApp` - Root application widget
   - `_ExampleHomePage` - Main navigation hub
   - `_ChatDemoTab` - Chat interface demonstration
   - `_ComponentGalleryTab` - Component showcase
   - `_MultiAgentDemoTab` - Multi-agent orchestration demo
   - `_SettingsTab` - Application settings

2. **`_SmartMockAdapter`** - Intelligent mock adapter
   - Generates context-aware UI responses
   - Demonstrates agent adaptation capabilities

3. **`_ExampleActionHandler`** - Custom action handler
   - Processes user interactions
   - Demonstrates action dispatching

### Key Concepts Demonstrated

#### 1. Framework Initialization
```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AgentUIKit.initialize();
  await Hive.initFlutter();
  runApp(const ProviderScope(child: BatikExampleApp()));
}
```

#### 2. AgentUIChat Configuration
```dart
final config = AgentSessionConfig(
  sessionId: 'chat-demo',
  adapter: _SmartMockAdapter(),
  enableStreaming: true,
  maxHistoryTurns: 50,
);

AgentUIChat(
  config: config,
  actionHandler: _ExampleActionHandler(context),
  animationConfig: const AnimationConfig(
    entranceAnimation: UIAnimation(type: 'fadeIn'),
    enableEntranceAnimations: true,
  ),
  useStreaming: true,
)
```

#### 3. Custom Component Registration
```dart
UIComponentRegistry.instance.registerCustom(
  'myChart',
  (context, node, renderer) => MyCustomChartWidget(node),
);
```

#### 4. Action Handling
```dart
class _ExampleActionHandler implements ActionHandler {
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
      case ActionTypes.custom:
        // Handle custom action
        break;
    }
  }
}
```

## Customization

### Changing the Theme

Edit the `BatikExampleApp` widget:

```dart
theme: ThemeData(
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xFF6750A4), // Change this
    brightness: Brightness.light,
  ),
),
```

### Adding Custom Adapters

Create a new adapter by extending `AgentAdapter`:

```dart
class MyCustomAdapter extends AgentAdapter {
  @override
  Future<AgentTurnOutput> sendTurn(AgentTurnInput input) async {
    // Your implementation
    return AgentTurnOutput(uiResponse: myResponse);
  }
}
```

### Adding Custom Components

Register custom component builders:

```dart
UIComponentRegistry.instance.register<MyCustomNode>(
  (context, node, renderer) {
    return MyCustomWidget(data: node.data);
  },
);
```

## Project Structure

```
example/
├── lib/
│   └── main.dart              # Main example application
├── test/                      # Example tests (add your own)
├── android/                   # Android-specific files (generated)
├── ios/                       # iOS-specific files (generated)
├── pubspec.yaml              # Dependencies
└── analysis_options.yaml     # Lint rules
```

## Testing

Run the example tests:

```bash
cd example
flutter test
```

## Troubleshooting

### Common Issues

1. **Dependencies not found:**
   ```bash
   flutter clean
   flutter pub get
   ```

2. **Build fails:**
   ```bash
   flutter clean
   flutter pub get
   flutter run
   ```

3. **Hot reload not working:**
   - Restart the app with `r` in the terminal
   - Or do a full restart with `R`

### Getting Help

- Check the main [README.md](../README.md)
- Review [STRUCTURE.md](../STRUCTURE.md) for architecture details
- See [QUICK_REFERENCE.md](../QUICK_REFERENCE.md) for API reference
- Open an issue on GitHub

## Next Steps

After exploring this example:

1. **Create your own adapter** - Connect to your preferred LLM
2. **Build custom components** - Extend the component library
3. **Implement multi-agent workflows** - Coordinate multiple agents
4. **Add persistence** - Use Hive for session storage
5. **Customize the theme** - Match your brand identity

## License

This example is part of the Batik framework and is licensed under the MIT License.

---

**Made with ❤️ using the Batik Framework**
