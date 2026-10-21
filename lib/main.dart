// lib/main.dart
//
// Batik Framework - Example Application
// ============================================================
// Demonstrates:
//  • Framework initialization
//  • MockAdapter for offline dev
//  • AnthropicAdapter (commented — swap in your key)
//  • Custom action handler
//  • Custom component registration
//  • AgentUIChat widget
//  • Direct AgentUIRenderer with a hardcoded tree
// ============================================================

import 'package:flutter/material.dart';
import 'batik.dart';

void main() {
  AgentUIKit.initialize();
  runApp(const ExampleApp());
}

// ─────────────────────────────────────────────
// App root
// ─────────────────────────────────────────────

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AgentUIKit Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6750A4)),
        useMaterial3: true,
      ),
      home: const _HomePage(),
    );
  }
}

// ─────────────────────────────────────────────
// Home: tabs for different demo modes
// ─────────────────────────────────────────────

class _HomePage extends StatefulWidget {
  const _HomePage();

  @override
  State<_HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<_HomePage> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AgentUIKit Demo'),
        centerTitle: true,
      ),
      body: [
        const _ChatDemoTab(),
        const _StaticRenderTab(),
        const _ComponentGalleryTab(),
      ][_tab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.chat), label: 'Chat'),
          NavigationDestination(icon: Icon(Icons.widgets), label: 'Static'),
          NavigationDestination(icon: Icon(Icons.dashboard), label: 'Gallery'),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Tab 1: AgentUIChat with MockAdapter
// ─────────────────────────────────────────────

class _ChatDemoTab extends StatelessWidget {
  const _ChatDemoTab();

  @override
  Widget build(BuildContext context) {
    final config = AgentSessionConfig(
      sessionId: 'demo-session',
      adapter: _DemoMockAdapter(),
    );
    
    return AgentUIChat(
      config: config,
      actionHandler: _AppActionHandler(context),
      inputHint: 'Ask the agent to show you a UI…',
      headerBuilder: (ctx) => Container(
        padding: const EdgeInsets.all(12),
        color: Theme.of(ctx).colorScheme.surfaceContainerHighest,
        child: const Text(
          '🤖 Mock Agent — try: "show login form", "show dashboard", "show settings"',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12),
        ),
      ),
      onError: (e) => debugPrint('Error: $e'),
    );
  }
}

// ─────────────────────────────────────────────
// Tab 2: Static AgentUIRenderer
// ─────────────────────────────────────────────

class _StaticRenderTab extends StatelessWidget {
  const _StaticRenderTab();

  AgentUIResponse get _response => AgentUIResponse(
        schemaVersion: '1.0.0',
        root: ScaffoldNode(
          body: ColumnNode(
            style: const UIStyle(padding: UIInsets(all: 16)),
            children: [
              TextNode(
                text: 'Static UI from JSON Schema',
                variant: 'headlineSmall',
              ),
              SpacerNode(height: 16),
              CardNode(
                elevation: 2,
                borderRadius: 12,
                style: const UIStyle(padding: UIInsets(all: 16)),
                children: [
                  RowNode(
                    children: [
                      AvatarNode(
                        initials: 'AK',
                        size: 48,
                        backgroundColor: '#6750A4',
                        foregroundColor: '#FFFFFF',
                      ),
                      SpacerNode(width: 12),
                      ColumnNode(
                        crossAxisAlignment: 'start',
                        mainAxisSize: 'min',
                        children: [
                          TextNode(
                              text: 'Alex Kim', variant: 'titleMedium'),
                          TextNode(
                            text: 'Product Manager',
                            style: const UIStyle(foregroundColor: 'grey'),
                          ),
                        ],
                      ),
                    ],
                  ),
                  SpacerNode(height: 12),
                  DividerNode(),
                  SpacerNode(height: 12),
                  RowNode(
                    mainAxisAlignment: 'spaceBetween',
                    children: [
                      _statCol('42', 'Projects'),
                      _statCol('128', 'Tasks'),
                      _statCol('94%', 'On Track'),
                    ],
                  ),
                ],
              ),
              SpacerNode(height: 16),
              RowNode(
                children: [
                  ButtonNode(
                    label: 'Message',
                    variant: 'filled',
                    icon: 'chat',
                    style: const UIStyle(flex: 1),
                    actions: {
                      'onTap': UIAction(
                          type: ActionTypes.custom,
                          payload: {'handler': 'message'}),
                    },
                  ),
                  SpacerNode(width: 12),
                  ButtonNode(
                    label: 'Profile',
                    variant: 'outlined',
                    icon: 'person',
                    style: const UIStyle(flex: 1),
                  ),
                ],
              ),
              SpacerNode(height: 16),
              TextNode(text: 'Recent Activity', variant: 'titleMedium'),
              SpacerNode(height: 8),
              ListNode(
                shrinkWrap: true,
                children: [
                  _activityItem('Design review completed', 'Today 2:30 PM', 'check_circle', '#4CAF50'),
                  _activityItem('Sprint planning scheduled', 'Today 10:00 AM', 'calendar', '#2196F3'),
                  _activityItem('Bug reported in checkout', 'Yesterday', 'error', '#F44336'),
                ],
              ),
            ],
          ),
        ),
      );

  ColumnNode _statCol(String value, String label) => ColumnNode(
        children: [
          TextNode(text: value, variant: 'titleLarge'),
          TextNode(
              text: label,
              style: const UIStyle(foregroundColor: 'grey', fontSize: 12)),
        ],
      );

  ListItemNode _activityItem(
          String title, String subtitle, String icon, String color) =>
      ListItemNode(
        leading: IconNode(icon: icon, color: color),
        title: TextNode(text: title),
        subtitle: TextNode(
            text: subtitle,
            style: const UIStyle(foregroundColor: 'grey', fontSize: 12)),
      );

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: AgentUIRenderer(
        response: _response,
        actionHandler: _AppActionHandler(context),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Tab 3: Component Gallery
// ─────────────────────────────────────────────

class _ComponentGalleryTab extends StatelessWidget {
  const _ComponentGalleryTab();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: AgentUIRenderer(
        response: AgentUIResponse(
          schemaVersion: '1.0.0',
          root: ColumnNode(
            children: [
              _section('Buttons', [
                RowNode(children: [
                  ButtonNode(label: 'Elevated', variant: 'elevated'),
                  SpacerNode(width: 8),
                  ButtonNode(label: 'Filled', variant: 'filled'),
                  SpacerNode(width: 8),
                  ButtonNode(label: 'Outlined', variant: 'outlined'),
                  SpacerNode(width: 8),
                  ButtonNode(label: 'Text', variant: 'text'),
                ]),
              ]),
              _section('Chips', [
                RowNode(children: [
                  ChipNode(label: 'Action', variant: 'action'),
                  SpacerNode(width: 8),
                  ChipNode(label: 'Filter', variant: 'filter', selected: true),
                  SpacerNode(width: 8),
                  ChipNode(label: 'Icon', icon: 'star', variant: 'action'),
                ]),
              ]),
              _section('Progress', [
                ProgressBarNode(value: 0.65),
                SpacerNode(height: 12),
                RowNode(mainAxisAlignment: 'spaceAround', children: [
                  ProgressBarNode(value: 0.3, variant: 'circular'),
                  ProgressBarNode(value: null, variant: 'circular'),
                  ProgressBarNode(value: 1.0, variant: 'circular',
                      color: '#4CAF50'),
                ]),
              ]),
              _section('Avatars & Badges', [
                RowNode(mainAxisAlignment: 'spaceAround', children: [
                  AvatarNode(initials: 'AB', size: 40,
                      backgroundColor: '#6750A4', foregroundColor: '#fff'),
                  AvatarNode(initials: 'CD', size: 48,
                      backgroundColor: '#F44336', foregroundColor: '#fff'),
                  AvatarNode(initials: 'EF', size: 56,
                      backgroundColor: '#4CAF50', foregroundColor: '#fff'),
                  BadgeNode(
                    label: '5',
                    children: [IconNode(icon: 'notifications', size: 28)],
                  ),
                ]),
              ]),
              _section('Form Controls', [
                TextNode(text: 'Text Fields', variant: 'labelLarge'),
                SpacerNode(height: 8),
                TextFieldNode(
                    label: 'Name', placeholder: 'Enter your name',
                    variableBinding: 'name'),
                SpacerNode(height: 8),
                TextFieldNode(
                    label: 'Message', multiline: true, maxLines: 3,
                    variableBinding: 'message'),
                SpacerNode(height: 16),
                TextNode(text: 'Dropdown', variant: 'labelLarge'),
                SpacerNode(height: 8),
                DropdownNode(
                  label: 'Country',
                  variableBinding: 'country',
                  options: [
                    DropdownOption(label: 'United States', value: 'us'),
                    DropdownOption(label: 'United Kingdom', value: 'uk'),
                    DropdownOption(label: 'Germany', value: 'de'),
                  ],
                ),
                SpacerNode(height: 16),
                SwitchNode(
                    value: false, label: 'Enable notifications',
                    variableBinding: 'notifications'),
                SwitchNode(
                    value: true, label: 'Dark mode',
                    variableBinding: 'darkMode'),
                SpacerNode(height: 8),
                SliderNode(
                    value: 0.5, min: 0, max: 1, divisions: 10,
                    label: 'Volume', variableBinding: 'volume'),
              ]),
            ],
          ),
        ),
        actionHandler: LoggingActionHandler(),
      ),
    );
  }

  ColumnNode _section(String title, List<UINode> children) => ColumnNode(
        style: const UIStyle(margin: UIInsets(bottom: 24)),
        children: [
          TextNode(text: title, variant: 'titleMedium'),
          DividerNode(),
          SpacerNode(height: 8),
          ...children,
        ],
      );
}

// ─────────────────────────────────────────────
// Mock adapter — returns different UIs per prompt
// ─────────────────────────────────────────────

class _DemoMockAdapter extends AgentAdapter {
  @override
  Future<AgentTurnOutput> sendTurn(AgentTurnInput input) async {
    await Future.delayed(const Duration(milliseconds: 600));
    final msg = input.userMessage.toLowerCase();

    AgentUIResponse response;
    if (msg.contains('login') || msg.contains('sign in')) {
      response = _loginForm();
    } else if (msg.contains('dashboard')) {
      response = _dashboard();
    } else if (msg.contains('settings')) {
      response = _settings();
    } else if (msg.contains('profile')) {
      response = _profile();
    } else {
      response = AgentUIResponse(
        schemaVersion: '1.0.0',
        root: CardNode(
          style: const UIStyle(padding: UIInsets(all: 16)),
          children: [
            TextNode(text: '🤖 Agent Response', variant: 'titleMedium'),
            SpacerNode(height: 8),
            TextNode(text: 'Try: "login form", "dashboard", "settings", "profile"'),
          ],
        ),
      );
    }
    return AgentTurnOutput(uiResponse: response);
  }

  @override
  AgentUIResponse? parseResponse(dynamic raw) => null;

  AgentUIResponse _loginForm() => AgentUIResponse(
        schemaVersion: '1.0.0',
        root: CardNode(
          elevation: 0,
          borderRadius: 16,
          style: const UIStyle(padding: UIInsets(all: 24)),
          children: [
            ColumnNode(
              children: [
                TextNode(text: 'Welcome back 👋', variant: 'headlineMedium'),
                SpacerNode(height: 4),
                TextNode(
                  text: 'Sign in to continue',
                  style: const UIStyle(foregroundColor: 'grey'),
                ),
                SpacerNode(height: 24),
                TextFieldNode(
                    label: 'Email', inputType: 'email', prefixIcon: 'email',
                    variableBinding: 'email'),
                SpacerNode(height: 16),
                TextFieldNode(
                    label: 'Password', obscureText: true, prefixIcon: 'lock',
                    variableBinding: 'password'),
                SpacerNode(height: 24),
                ButtonNode(
                  label: 'Sign In',
                  variant: 'filled',
                  style: UIStyle(width: double.infinity),
                  actions: {
                    'onTap': UIAction(
                        type: 'agentMessage',
                        payload: {'message': 'User signed in'}),
                  },
                ),
                SpacerNode(height: 12),
                ButtonNode(label: 'Forgot password?', variant: 'text'),
              ],
            ),
          ],
        ),
      );

  AgentUIResponse _dashboard() => AgentUIResponse(
        schemaVersion: '1.0.0',
        root: ColumnNode(
          children: [
            TextNode(text: 'Dashboard', variant: 'headlineSmall'),
            SpacerNode(height: 16),
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
            SpacerNode(height: 16),
            TextNode(text: 'Recent Orders', variant: 'titleMedium'),
            SpacerNode(height: 8),
            ...List.generate(
                3,
                (i) => ListItemNode(
                      leading: AvatarNode(
                          initials: 'O${i + 1}',
                          size: 36,
                          backgroundColor: '#6750A4',
                          foregroundColor: '#fff'),
                      title: TextNode(text: 'Order #${1000 + i}'),
                      subtitle: TextNode(text: '\$${(i + 1) * 49}.99'),
                      trailing: ChipNode(
                          label: ['Pending', 'Shipped', 'Delivered'][i],
                          variant: 'action'),
                    )),
          ],
        ),
      );

  CardNode _statCard(String title, String value, String icon, String color) =>
      CardNode(
        style: const UIStyle(padding: UIInsets(all: 12)),
        children: [
          RowNode(
            mainAxisAlignment: 'spaceBetween',
            children: [
              TextNode(text: title, style: UIStyle(foregroundColor: 'grey', fontSize: 12)),
              IconNode(icon: icon, color: color, size: 20),
            ],
          ),
          SpacerNode(height: 8),
          TextNode(text: value, variant: 'titleLarge'),
        ],
      );

  AgentUIResponse _settings() => AgentUIResponse(
        schemaVersion: '1.0.0',
        root: ColumnNode(
          children: [
            TextNode(text: 'Settings', variant: 'headlineSmall'),
            SpacerNode(height: 16),
            SwitchNode(value: true, label: '🔔 Push Notifications',
                variableBinding: 'notifications'),
            DividerNode(),
            SwitchNode(value: false, label: '🌙 Dark Mode',
                variableBinding: 'darkMode'),
            DividerNode(),
            SwitchNode(value: true, label: '📊 Analytics',
                variableBinding: 'analytics'),
            DividerNode(),
            SpacerNode(height: 16),
            TextNode(text: 'Text Size', variant: 'bodyMedium'),
            SliderNode(value: 0.5, min: 0.2, max: 1.0, divisions: 8,
                variableBinding: 'textSize'),
            SpacerNode(height: 24),
            ButtonNode(
              label: 'Save Settings',
              variant: 'filled',
              icon: 'save',
              actions: {
                'onTap': UIAction(
                    type: ActionTypes.custom,
                    payload: {'handler': 'saveSettings'}),
              },
            ),
          ],
        ),
      );

  AgentUIResponse _profile() => AgentUIResponse(
        schemaVersion: '1.0.0',
        root: ColumnNode(
          children: [
            CardNode(
              style: const UIStyle(padding: UIInsets(all: 20)),
              children: [
                ColumnNode(
                  children: [
                    AvatarNode(
                        initials: 'JD', size: 80,
                        backgroundColor: '#6750A4', foregroundColor: '#fff'),
                    SpacerNode(height: 12),
                    TextNode(text: 'Jane Doe', variant: 'titleLarge'),
                    TextNode(
                        text: 'jane.doe@example.com',
                        style: const UIStyle(foregroundColor: 'grey')),
                    SpacerNode(height: 16),
                    RowNode(
                      mainAxisAlignment: 'spaceEvenly',
                      children: [
                        _profileStat('Posts', '142'),
                        VerticalDivider(),
                        _profileStat('Followers', '1.2K'),
                        VerticalDivider(),
                        _profileStat('Following', '340'),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            SpacerNode(height: 16),
            ButtonNode(
                label: 'Edit Profile', variant: 'outlined', icon: 'edit',
                style: UIStyle(width: double.infinity)),
          ],
        ),
      );

  ColumnNode _profileStat(String label, String value) => ColumnNode(
        children: [
          TextNode(text: value, variant: 'titleMedium'),
          TextNode(text: label, style: const UIStyle(foregroundColor: 'grey', fontSize: 12)),
        ],
      );
}

// Vertcal divider helper (plain widget, not schema node)
class VerticalDivider extends UINode {
  VerticalDivider() : super(type: '_vd_', children: const [], actions: const {});
  @override
  Map<String, dynamic> toJson() => {};
}

// ─────────────────────────────────────────────
// Custom action handler
// ─────────────────────────────────────────────

class _AppActionHandler implements ActionHandler {
  const _AppActionHandler(this._context);
  final BuildContext _context;

  @override
  Future<void> handle(
    BuildContext context,
    UIAction action,
    Map<String, dynamic> variables,
  ) async {
    debugPrint('[App] Action: ${action.type} payload: ${action.payload}');
    debugPrint('[App] Variables: $variables');

    switch (action.type) {
      case ActionTypes.agentMessage:
        ScaffoldMessenger.of(_context).showSnackBar(
          SnackBar(
            content: Text(
                action.payload['message'] as String? ?? 'Action triggered'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        break;
      case ActionTypes.navigate:
        debugPrint('[App] Navigate to: ${action.payload['route']}');
        break;
      case ActionTypes.openUrl:
        debugPrint('[App] Open URL: ${action.payload['url']}');
        break;
      case ActionTypes.custom:
        final handler = action.payload['handler'] as String?;
        switch (handler) {
          case 'message':
            ScaffoldMessenger.of(_context).showSnackBar(
              const SnackBar(content: Text('Opening message thread…')),
            );
            break;
          case 'saveSettings':
            ScaffoldMessenger.of(_context).showSnackBar(
              const SnackBar(content: Text('✅ Settings saved!')),
            );
            break;
        }
        break;
    }
  }
}
