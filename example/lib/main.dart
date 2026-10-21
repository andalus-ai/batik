// example/lib/main.dart
//
// Batik Framework - Complete Example Application
// ============================================================
// This example demonstrates:
//  • Framework initialization
//  • Multiple adapter types (Mock, Anthropic, OpenAI, WebSocket)
//  • Custom action handlers
//  • Custom component registration
//  • AgentUIChat widget
//  • Direct AgentUIRenderer usage
//  • Multi-agent orchestration
//  • Theme customization
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:batik/batik.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Batik framework
  await AgentUIKit.initialize();
  
  // Initialize Hive for session persistence (optional)
  await Hive.initFlutter();
  
  runApp(const ProviderScope(child: BatikExampleApp()));
}

// ─────────────────────────────────────────────────────────────────────
// Main Application
// ─────────────────────────────────────────────────────────────────────

class BatikExampleApp extends StatelessWidget {
  const BatikExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Batik Framework Example',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6750A4),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6750A4),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system,
      home: const _ExampleHomePage(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Home Page with Navigation
// ─────────────────────────────────────────────────────────────────────

class _ExampleHomePage extends StatefulWidget {
  const _ExampleHomePage();

  @override
  State<_ExampleHomePage> createState() => _ExampleHomePageState();
}

class _ExampleHomePageState extends State<_ExampleHomePage> {
  int _selectedIndex = 0;

  final List<_ExampleTab> _tabs = [
    const _ExampleTab(
      label: 'Chat',
      icon: Icons.chat_bubble_outline,
      selectedIcon: Icons.chat_bubble,
    ),
    const _ExampleTab(
      label: 'Components',
      icon: Icons.widgets_outlined,
      selectedIcon: Icons.widgets,
    ),
    const _ExampleTab(
      label: 'Multi-Agent',
      icon: Icons.account_tree_outlined,
      selectedIcon: Icons.account_tree,
    ),
    const _ExampleTab(
      label: 'Settings',
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: const [
          _ChatDemoTab(),
          _ComponentGalleryTab(),
          _MultiAgentDemoTab(),
          _SettingsTab(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) => setState(() => _selectedIndex = index),
        destinations: _tabs
            .map(
              (tab) => NavigationDestination(
                icon: Icon(tab.icon),
                selectedIcon: Icon(tab.selectedIcon),
                label: tab.label,
              ),
            )
            .toList(),
      ),
    );
  }
}

class _ExampleTab {
  const _ExampleTab({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

// ─────────────────────────────────────────────────────────────────────
// Tab 1: Chat Demo with Mock Adapter
// ─────────────────────────────────────────────────────────────────────

class _ChatDemoTab extends StatelessWidget {
  const _ChatDemoTab();

  @override
  Widget build(BuildContext context) {
    final config = AgentSessionConfig(
      sessionId: 'chat-demo',
      adapter: _SmartMockAdapter(),
      enableStreaming: true,
      maxHistoryTurns: 50,
    );

    return AgentUIChat(
      config: config,
      actionHandler: _ExampleActionHandler(context),
      animationConfig: const AnimationConfig(
        entranceAnimation: UIAnimation(type: 'fadeIn', duration: Duration(milliseconds: 300)),
        enableEntranceAnimations: true,
        staggerDelay: Duration(milliseconds: 50),
      ),
      inputHint: 'Ask the agent to show a UI...',
      showToolStatusIndicator: true,
      useStreaming: true,
      headerBuilder: (ctx) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(ctx).colorScheme.surfaceContainerHighest,
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(16),
            bottomRight: Radius.circular(16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: Theme.of(ctx).colorScheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Text(
                  'Batik Chat Demo',
                  style: Theme.of(ctx).textTheme.titleSmall,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Try: "login form", "dashboard", "settings", "profile", "chat interface"',
              style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                color: Theme.of(ctx).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      onError: (error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $error'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Tab 2: Component Gallery
// ─────────────────────────────────────────────────────────────────────

class _ComponentGalleryTab extends StatelessWidget {
  const _ComponentGalleryTab();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('Buttons'),
          _ComponentShowcase(
            response: AgentUIResponse(
              schemaVersion: '2.0.0',
              root: RowNode(
                children: [
                  ButtonNode(label: 'Elevated', variant: 'elevated', style: const UIStyle(flex: 1)),
                  SpacerNode(width: 8),
                  ButtonNode(label: 'Filled', variant: 'filled', style: const UIStyle(flex: 1)),
                  SpacerNode(width: 8),
                  ButtonNode(label: 'Outlined', variant: 'outlined', style: const UIStyle(flex: 1)),
                  SpacerNode(width: 8),
                  ButtonNode(label: 'Text', variant: 'text', style: const UIStyle(flex: 1)),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          _sectionHeader('Form Controls'),
          _ComponentShowcase(
            response: AgentUIResponse(
              schemaVersion: '2.0.0',
              root: ColumnNode(
                children: [
                  TextFieldNode(label: 'Email', inputType: 'email', prefixIcon: 'email'),
                  SpacerNode(height: 12),
                  TextFieldNode(label: 'Password', obscureText: true, prefixIcon: 'lock'),
                  SpacerNode(height: 12),
                  SwitchNode(value: true, label: 'Enable notifications'),
                  SpacerNode(height: 12),
                  SliderNode(value: 0.5, min: 0, max: 1, divisions: 10, label: 'Volume'),
                  SpacerNode(height: 12),
                  DropdownNode(
                    label: 'Country',
                    options: [
                      DropdownOption(label: 'United States', value: 'us'),
                      DropdownOption(label: 'United Kingdom', value: 'uk'),
                      DropdownOption(label: 'Germany', value: 'de'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          _sectionHeader('Cards & Lists'),
          _ComponentShowcase(
            response: AgentUIResponse(
              schemaVersion: '2.0.0',
              root: ColumnNode(
                children: [
                  CardNode(
                    style: const UIStyle(padding: UIInsets(all: 16)),
                    children: [
                      RowNode(
                        children: [
                          AvatarNode(initials: 'JD', size: 48, backgroundColor: '#6750A4'),
                          SpacerNode(width: 12),
                          ColumnNode(
                            crossAxisAlignment: 'start',
                            children: [
                              TextNode(text: 'Jane Doe', variant: 'titleMedium'),
                              TextNode(text: 'Product Designer', style: const UIStyle(foregroundColor: 'grey')),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                  SpacerNode(height: 12),
                  ListNode(
                    shrinkWrap: true,
                    children: [
                      ListItemNode(
                        leading: IconNode(icon: 'home', color: '#6750A4'),
                        title: TextNode(text: 'Home'),
                        subtitle: TextNode(text: 'Main dashboard'),
                      ),
                      DividerNode(),
                      ListItemNode(
                        leading: IconNode(icon: 'settings', color: '#6750A4'),
                        title: TextNode(text: 'Settings'),
                        subtitle: TextNode(text: 'App preferences'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          _sectionHeader('Progress & Feedback'),
          _ComponentShowcase(
            response: AgentUIResponse(
              schemaVersion: '2.0.0',
              root: ColumnNode(
                children: [
                  ProgressBarNode(value: 0.75),
                  SpacerNode(height: 16),
                  RowNode(
                    mainAxisAlignment: 'spaceAround',
                    children: [
                      ProgressBarNode(value: 0.3, variant: 'circular'),
                      ProgressBarNode(value: 0.6, variant: 'circular'),
                      ProgressBarNode(value: 1.0, variant: 'circular'),
                    ],
                  ),
                  SpacerNode(height: 16),
                  RowNode(
                    mainAxisAlignment: 'spaceAround',
                    children: [
                      BadgeNode(label: '5', children: [IconNode(icon: 'notifications', size: 28)]),
                      ChipNode(label: 'Action', variant: 'action'),
                      ChipNode(label: 'Filter', variant: 'filter', selected: true),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(
      title,
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
    ),
  );
}

class _ComponentShowcase extends StatelessWidget {
  const _ComponentShowcase({required this.response});

  final AgentUIResponse response;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: AgentUIRenderer(
        response: response,
        actionHandler: LoggingActionHandler(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Tab 3: Multi-Agent Demo
// ─────────────────────────────────────────────────────────────────────

class _MultiAgentDemoTab extends StatelessWidget {
  const _MultiAgentDemoTab();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.account_tree,
            size: 64,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            'Multi-Agent Orchestration',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'This demo shows how multiple specialized agents can work together to complete complex tasks.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              _showMultiAgentDialog(context);
            },
            icon: const Icon(Icons.play_arrow),
            label: const Text('Start Demo'),
          ),
        ],
      ),
    );
  }

  void _showMultiAgentDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Multi-Agent Demo'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _agentTile('Research Agent', 'Gathers information from multiple sources', Icons.search),
            const SizedBox(height: 8),
            _agentTile('Analysis Agent', 'Processes and analyzes collected data', Icons.analytics),
            const SizedBox(height: 8),
            _agentTile('Presentation Agent', 'Creates visual summaries and reports', Icons.presentation),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Multi-agent workflow started...')),
              );
            },
            child: const Text('Start'),
          ),
        ],
      ),
    );
  }

  Widget _agentTile(String title, String subtitle, IconData icon) => ListTile(
    leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
    title: Text(title),
    subtitle: Text(subtitle),
  );
}

// ─────────────────────────────────────────────────────────────────────
// Tab 4: Settings
// ─────────────────────────────────────────────────────────────────────

class _SettingsTab extends StatefulWidget {
  const _SettingsTab();

  @override
  State<_SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<_SettingsTab> {
  bool _enableAnimations = true;
  bool _enableStreaming = true;
  bool _darkMode = false;
  String _selectedAdapter = 'Mock';

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _settingsSection(
            'General',
            [
              SwitchListTile(
                title: const Text('Enable Animations'),
                subtitle: const Text('Show entrance and transition animations'),
                value: _enableAnimations,
                onChanged: (v) => setState(() => _enableAnimations = v),
              ),
              SwitchListTile(
                title: const Text('Enable Streaming'),
                subtitle: const Text('Stream responses in real-time'),
                value: _enableStreaming,
                onChanged: (v) => setState(() => _enableStreaming = v),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          _settingsSection(
            'Appearance',
            [
              SwitchListTile(
                title: const Text('Dark Mode'),
                subtitle: const Text('Use dark theme'),
                value: _darkMode,
                onChanged: (v) => setState(() => _darkMode = v),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          _settingsSection(
            'Agent Configuration',
            [
              ListTile(
                title: const Text('Selected Adapter'),
                subtitle: Text(_selectedAdapter),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showAdapterSelector(context),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          _settingsSection(
            'About',
            [
              ListTile(
                title: const Text('Batik Framework'),
                subtitle: const Text('Version 0.1.0'),
                leading: const Icon(Icons.info_outline),
              ),
              ListTile(
                title: const Text('Documentation'),
                leading: const Icon(Icons.description),
                trailing: const Icon(Icons.open_in_new),
                onTap: () {
                  // Open documentation
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _settingsSection(String title, List<Widget> children) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.bold,
        ),
      ),
      const SizedBox(height: 8),
      Card(
        clipBehavior: Clip.antiAlias,
        child: Column(children: children),
      ),
    ],
  );

  void _showAdapterSelector(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Select Agent Adapter'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String>(
              title: const Text('Mock Adapter'),
              subtitle: const Text('For testing and development'),
              value: 'Mock',
              groupValue: _selectedAdapter,
              onChanged: (v) {
                setState(() => _selectedAdapter = v!);
                Navigator.pop(ctx);
              },
            ),
            RadioListTile<String>(
              title: const Text('Anthropic Adapter'),
              subtitle: const Text('Claude API integration'),
              value: 'Anthropic',
              groupValue: _selectedAdapter,
              onChanged: (v) {
                setState(() => _selectedAdapter = v!);
                Navigator.pop(ctx);
              },
            ),
            RadioListTile<String>(
              title: const Text('OpenAI Adapter'),
              subtitle: const Text('GPT-4 API integration'),
              value: 'OpenAI',
              groupValue: _selectedAdapter,
              onChanged: (v) {
                setState(() => _selectedAdapter = v!);
                Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Smart Mock Adapter - Returns different UIs based on user input
// ─────────────────────────────────────────────────────────────────────

class _SmartMockAdapter extends AgentAdapter {
  @override
  Future<AgentTurnOutput> sendTurn(AgentTurnInput input) async {
    await Future.delayed(const Duration(milliseconds: 800));
    
    final msg = input.userMessage.toLowerCase();
    AgentUIResponse response;

    if (msg.contains('login') || msg.contains('sign in')) {
      response = _loginForm();
    } else if (msg.contains('dashboard') || msg.contains('analytics')) {
      response = _dashboard();
    } else if (msg.contains('settings') || msg.contains('preferences')) {
      response = _settingsUI();
    } else if (msg.contains('profile') || msg.contains('user')) {
      response = _profileUI();
    } else if (msg.contains('chat') || msg.contains('message')) {
      response = _chatInterface();
    } else {
      response = _defaultResponse(input.userMessage);
    }

    return AgentTurnOutput(uiResponse: response);
  }

  @override
  AgentUIResponse? parseResponse(dynamic raw) => null;

  AgentUIResponse _defaultResponse(String userInput) => AgentUIResponse(
    schemaVersion: '2.0.0',
    root: CardNode(
      style: const UIStyle(padding: UIInsets(all: 20)),
      children: [
        ColumnNode(
          children: [
            IconNode(icon: 'chat', size: 48, color: '#6750A4'),
            SpacerNode(height: 16),
            TextNode(text: '🤖 Batik Agent', variant: 'headlineMedium'),
            SpacerNode(height: 8),
            TextNode(
              text: 'You said: "$userInput"',
              style: const UIStyle(foregroundColor: 'grey'),
            ),
            SpacerNode(height: 16),
            DividerNode(),
            SpacerNode(height: 16),
            TextNode(text: 'Try these commands:', variant: 'titleSmall'),
            SpacerNode(height: 8),
            _commandChip('Show login form'),
            SpacerNode(height: 4),
            _commandChip('Show dashboard'),
            SpacerNode(height: 4),
            _commandChip('Show settings'),
            SpacerNode(height: 4),
            _commandChip('Show profile'),
          ],
        ),
      ],
    ),
  );

  ButtonNode _commandChip(String label) => ButtonNode(
    label: label,
    variant: 'outlined',
    style: const UIStyle(width: double.infinity),
    actions: {
      'onTap': UIAction(
        type: ActionTypes.agentMessage,
        payload: {'message': label},
      ),
    },
  );

  AgentUIResponse _loginForm() => AgentUIResponse(
    schemaVersion: '2.0.0',
    root: ScaffoldNode(
      body: ColumnNode(
        style: const UIStyle(padding: UIInsets(all: 24)),
        children: [
          SpacerNode(height: 40),
          AvatarNode(initials: '🔐', size: 80, backgroundColor: '#6750A4'),
          SpacerNode(height: 24),
          TextNode(text: 'Welcome Back', variant: 'headlineLarge'),
          SpacerNode(height: 8),
          TextNode(
            text: 'Sign in to continue',
            style: const UIStyle(foregroundColor: 'grey'),
          ),
          SpacerNode(height: 32),
          TextFieldNode(
            label: 'Email',
            inputType: 'email',
            prefixIcon: 'email',
            variableBinding: 'email',
          ),
          SpacerNode(height: 16),
          TextFieldNode(
            label: 'Password',
            obscureText: true,
            prefixIcon: 'lock',
            variableBinding: 'password',
          ),
          Align(
            alignment: 'centerRight',
            child: TextNode(
              text: 'Forgot password?',
              style: const UIStyle(foregroundColor: '#6750A4'),
            ),
          ),
          SpacerNode(height: 24),
          ButtonNode(
            label: 'Sign In',
            variant: 'filled',
            icon: 'login',
            style: const UIStyle(width: double.infinity),
            actions: {
              'onTap': UIAction(
                type: ActionTypes.agentMessage,
                payload: {'message': 'User signed in'},
              ),
            },
          ),
          SpacerNode(height: 16),
          RowNode(
            children: [
              const Expanded(child: DividerNode()),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: TextNode(text: 'OR'),
              ),
              const Expanded(child: DividerNode()),
            ],
          ),
          SpacerNode(height: 16),
          ButtonNode(
            label: 'Continue with Google',
            variant: 'outlined',
            icon: 'google',
            style: const UIStyle(width: double.infinity),
          ),
        ],
      ),
    ),
  );

  AgentUIResponse _dashboard() => AgentUIResponse(
    schemaVersion: '2.0.0',
    root: ScaffoldNode(
      appBar: AppBarNode(
        title: TextNode(text: 'Dashboard'),
        backgroundColor: '#6750A4',
      ),
      body: SingleChildScrollView(
        style: const UIStyle(padding: UIInsets(all: 16)),
        child: ColumnNode(
          children: [
            GridNode(
              crossAxisCount: 2,
              childAspectRatio: 1.5,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              children: [
                _statCard('Revenue', '\$48,290', 'chart_bar', '#6750A4'),
                _statCard('Users', '12,840', 'group', '#2196F3'),
                _statCard('Orders', '3,420', 'shopping_cart', '#4CAF50'),
                _statCard('Issues', '23', 'error', '#F44336'),
              ],
            ),
            SpacerNode(height: 24),
            TextNode(text: 'Recent Activity', variant: 'titleMedium'),
            SpacerNode(height: 12),
            ListNode(
              shrinkWrap: true,
              children: List.generate(
                5,
                (i) => ListItemNode(
                  leading: AvatarNode(
                    initials: 'O${i + 1}',
                    size: 40,
                    backgroundColor: ['#6750A4', '#2196F3', '#4CAF50', '#F44336', '#FF9800'][i],
                  ),
                  title: TextNode(text: 'Order #${1000 + i}'),
                  subtitle: TextNode(text: '\$${(i + 1) * 49}.99'),
                  trailing: ChipNode(
                    label: ['Pending', 'Shipped', 'Delivered', 'Processing', 'Cancelled'][i],
                    variant: 'action',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  CardNode _statCard(String title, String value, String icon, String color) => CardNode(
    style: const UIStyle(padding: UIInsets(all: 12)),
    children: [
      ColumnNode(
        crossAxisAlignment: 'start',
        children: [
          RowNode(
            mainAxisAlignment: 'spaceBetween',
            children: [
              TextNode(text: title, style: const UIStyle(foregroundColor: 'grey', fontSize: 12)),
              IconNode(icon: icon, color: color, size: 20),
            ],
          ),
          SpacerNode(height: 8),
          TextNode(text: value, variant: 'titleLarge'),
        ],
      ),
    ],
  );

  AgentUIResponse _settingsUI() => AgentUIResponse(
    schemaVersion: '2.0.0',
    root: ScaffoldNode(
      appBar: AppBarNode(title: TextNode(text: 'Settings')),
      body: SingleChildScrollView(
        style: const UIStyle(padding: UIInsets(all: 16)),
        child: ColumnNode(
          children: [
            CardNode(
              style: const UIStyle(padding: UIInsets(all: 16)),
              children: [
                TextNode(text: 'Preferences', variant: 'titleMedium'),
                SpacerNode(height: 12),
                SwitchNode(value: true, label: '🔔 Push Notifications', variableBinding: 'notifications'),
                DividerNode(),
                SwitchNode(value: false, label: '🌙 Dark Mode', variableBinding: 'darkMode'),
                DividerNode(),
                SwitchNode(value: true, label: '📊 Analytics', variableBinding: 'analytics'),
              ],
            ),
            SpacerNode(height: 16),
            CardNode(
              style: const UIStyle(padding: UIInsets(all: 16)),
              children: [
                TextNode(text: 'Display', variant: 'titleMedium'),
                SpacerNode(height: 12),
                TextNode(text: 'Text Size', variant: 'bodyMedium'),
                SliderNode(value: 0.5, min: 0.2, max: 1.0, divisions: 8, variableBinding: 'textSize'),
              ],
            ),
            SpacerNode(height: 16),
            ButtonNode(
              label: 'Save Settings',
              variant: 'filled',
              icon: 'save',
              style: const UIStyle(width: double.infinity),
              actions: {
                'onTap': UIAction(
                  type: ActionTypes.setVariable,
                  payload: {'settingsSaved': true},
                ),
              },
            ),
          ],
        ),
      ),
    ),
  );

  AgentUIResponse _profileUI() => AgentUIResponse(
    schemaVersion: '2.0.0',
    root: ScaffoldNode(
      body: SingleChildScrollView(
        style: const UIStyle(padding: UIInsets(all: 16)),
        child: ColumnNode(
          children: [
            CardNode(
              style: const UIStyle(padding: UIInsets(all: 20)),
              children: [
                ColumnNode(
                  children: [
                    AvatarNode(initials: 'JD', size: 100, backgroundColor: '#6750A4'),
                    SpacerNode(height: 16),
                    TextNode(text: 'Jane Doe', variant: 'headlineMedium'),
                    TextNode(
                      text: 'jane.doe@example.com',
                      style: const UIStyle(foregroundColor: 'grey'),
                    ),
                    SpacerNode(height: 16),
                    RowNode(
                      mainAxisAlignment: 'spaceEvenly',
                      children: [
                        _profileStat('Posts', '142'),
                        VerticalDividerNode(),
                        _profileStat('Followers', '1.2K'),
                        VerticalDividerNode(),
                        _profileStat('Following', '340'),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            SpacerNode(height: 16),
            ButtonNode(
              label: 'Edit Profile',
              variant: 'outlined',
              icon: 'edit',
              style: const UIStyle(width: double.infinity),
            ),
          ],
        ),
      ),
    ),
  );

  ColumnNode _profileStat(String label, String value) => ColumnNode(
    children: [
      TextNode(text: value, variant: 'titleMedium'),
      TextNode(text: label, style: const UIStyle(foregroundColor: 'grey', fontSize: 12)),
    ],
  );

  AgentUIResponse _chatInterface() => AgentUIResponse(
    schemaVersion: '2.0.0',
    root: ScaffoldNode(
      appBar: AppBarNode(
        title: TextNode(text: 'Messages'),
        backgroundColor: '#6750A4',
      ),
      body: ColumnNode(
        children: [
          Expanded(
            child: ListNode(
              children: List.generate(
                10,
                (i) => ListItemNode(
                  leading: AvatarNode(
                    initials: 'U${i + 1}',
                    size: 40,
                    backgroundColor: ['#6750A4', '#2196F3', '#4CAF50'][i % 3],
                  ),
                  title: TextNode(text: 'User ${i + 1}'),
                  subtitle: TextNode(
                    text: 'This is a sample message ${i + 1}',
                    style: const UIStyle(foregroundColor: 'grey'),
                  ),
                  trailing: TextNode(
                    text: '${i}m',
                    style: const UIStyle(foregroundColor: 'grey', fontSize: 12),
                  ),
                ),
              ),
            ),
          ),
          Container(
            style: const UIStyle(
              padding: UIInsets(all: 8),
              backgroundColor: 'surfaceContainerHighest',
            ),
            child: RowNode(
              children: [
                Expanded(
                  child: TextFieldNode(
                    placeholder: 'Type a message...',
                    multiline: false,
                    variableBinding: 'messageInput',
                  ),
                ),
                SpacerNode(width: 8),
                IconButtonNode(icon: 'send', tooltip: 'Send'),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

// Helper node for vertical divider
class VerticalDividerNode extends UINode {
  const VerticalDividerNode() : super(type: 'vdivider', children: const []);
  @override
  Map<String, dynamic> toJson() => {};
}

// ─────────────────────────────────────────────────────────────────────
// Example Action Handler
// ─────────────────────────────────────────────────────────────────────

class _ExampleActionHandler implements ActionHandler {
  _ExampleActionHandler(this._context);
  
  final BuildContext _context;

  @override
  Future<void> handle(
    BuildContext context,
    UIAction action,
    Map<String, dynamic> variables,
  ) async {
    debugPrint('[Action] Type: ${action.type}, Payload: ${action.payload}');
    debugPrint('[Variables] $variables');

    switch (action.type) {
      case ActionTypes.agentMessage:
        final message = action.payload['message'] as String?;
        if (message != null) {
          ScaffoldMessenger.of(_context).showSnackBar(
            SnackBar(
              content: Text(message),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        break;
        
      case ActionTypes.navigate:
        final route = action.payload['route'] as String?;
        debugPrint('[Navigate] To: $route');
        break;
        
      case ActionTypes.setVariable:
        debugPrint('[SetVariable] ${action.payload}');
        break;
        
      case ActionTypes.openUrl:
        final url = action.payload['url'] as String?;
        debugPrint('[OpenURL] $url');
        break;
        
      case ActionTypes.custom:
        final handler = action.payload['handler'] as String?;
        debugPrint('[Custom] Handler: $handler');
        break;
    }
  }
}
