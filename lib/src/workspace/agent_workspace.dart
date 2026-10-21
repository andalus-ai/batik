// lib/src/workspace/agent_workspace.dart
//
// Batik — Agent Workspace Runtime (Patch 039)
// ============================================================
// Multi-pane workspace runtime where chat, documents, diagrams,
// charts, workflows, and whiteboard spaces live side-by-side.
//
// JSON schema:
// {
//   "type": "workspace",
//   "layout": "split|tabs|grid",
//   "panes": [
//     {"type": "chat", "title": "Assistant"},
//     {"type": "document", "title": "Brief", "content": "..."},
//     {"type": "diagram", "title": "Architecture", "mermaid": "flowchart LR\\nA-->B"},
//     {"type": "chart", "title": "Metrics", "spec": {"kind": "bar"}}
//   ]
// }
// ============================================================

import 'package:flutter/material.dart';
import '../schema/ui_schema.dart';
import '../core/registry.dart';
import '../plugin/batik_plugin.dart';
import '../theme/batik_tokens.dart';
import '../tenun/tenun_adapter.dart';

/// Supported workspace layout arrangements.
enum WorkspaceLayout {
  split,
  tabs,
  grid;

  static WorkspaceLayout parse(String? value) =>
      WorkspaceLayout.values.firstWhere(
        (l) => l.name == value?.toLowerCase(),
        orElse: () => WorkspaceLayout.tabs,
      );
}

/// Abstract pane inside a [WorkspaceNode].
abstract class WorkspacePane {
  const WorkspacePane({required this.type, required this.title, this.icon});

  final String type;
  final String title;
  final IconData? icon;

  factory WorkspacePane.fromJson(Map<String, dynamic> j) {
    final type = j['type'] as String? ?? 'custom';
    final title = j['title'] as String? ?? 'Pane';

    return switch (type) {
      'chat' => ChatWorkspacePane(title: title),
      'document' => DocumentWorkspacePane(
          title: title,
          content: j['content'] as String? ?? '',
        ),
      'diagram' => DiagramWorkspacePane(
          title: title,
          mermaid: j['mermaid'] as String?,
        ),
      'chart' => ChartWorkspacePane(
          title: title,
          spec: ChartSpec.fromJson(j['spec'] as Map<String, dynamic>? ?? {}),
        ),
      _ => CustomWorkspacePane(title: title, data: j),
    };
  }

  Map<String, dynamic> toJson();
}

class ChatWorkspacePane extends WorkspacePane {
  const ChatWorkspacePane({super.title = 'Agent Chat'})
      : super(type: 'chat', icon: Icons.chat_bubble_outline);

  @override
  Map<String, dynamic> toJson() => {'type': 'chat', 'title': title};
}

class DocumentWorkspacePane extends WorkspacePane {
  const DocumentWorkspacePane({required super.title, required this.content})
      : super(type: 'document', icon: Icons.article_outlined);

  final String content;

  @override
  Map<String, dynamic> toJson() =>
      {'type': 'document', 'title': title, 'content': content};
}

class DiagramWorkspacePane extends WorkspacePane {
  const DiagramWorkspacePane({required super.title, this.mermaid})
      : super(type: 'diagram', icon: Icons.account_tree_outlined);

  final String? mermaid;

  @override
  Map<String, dynamic> toJson() => {
        'type': 'diagram',
        'title': title,
        if (mermaid != null) 'mermaid': mermaid,
      };
}

class ChartWorkspacePane extends WorkspacePane {
  const ChartWorkspacePane({required super.title, required this.spec})
      : super(type: 'chart', icon: Icons.bar_chart_outlined);

  final ChartSpec spec;

  @override
  Map<String, dynamic> toJson() =>
      {'type': 'chart', 'title': title, 'spec': spec.toJson()};
}

class CustomWorkspacePane extends WorkspacePane {
  const CustomWorkspacePane({required super.title, this.data = const {}})
      : super(type: 'custom', icon: Icons.dashboard_customize_outlined);

  final Map<String, dynamic> data;

  @override
  Map<String, dynamic> toJson() => {'type': 'custom', 'title': title, ...data};
}

/// UINode representing an Agent Workspace.
class WorkspaceNode extends UINode with _WsNodeJsonBase {
  WorkspaceNode({
    super.id,
    super.style,
    super.actions,
    super.condition,
    super.children,
    this.layout = WorkspaceLayout.tabs,
    this.panes = const [],
  }) : super(type: 'workspace');

  final WorkspaceLayout layout;
  final List<WorkspacePane> panes;

  factory WorkspaceNode.fromJson(Map<String, dynamic> j) => WorkspaceNode(
        id: j['id'] as String?,
        style: _parseWsStyle(j),
        actions: _parseWsActions(j),
        condition: j['condition'] as String?,
        layout: WorkspaceLayout.parse(j['layout'] as String?),
        panes: (j['panes'] as List<dynamic>? ?? [])
            .map((p) => WorkspacePane.fromJson(p as Map<String, dynamic>))
            .toList(),
        children: (j['children'] as List<dynamic>? ?? [])
            .map((c) => UINode.fromJson(c as Map<String, dynamic>))
            .toList(),
      );

  @override
  Map<String, dynamic> toJson() => {
        ..._baseWsJson(),
        'layout': layout.name,
        'panes': panes.map((p) => p.toJson()).toList(),
        if (children.isNotEmpty)
          'children': children.map((c) => c.toJson()).toList(),
      };
}

/// Renderer for WorkspaceNode.
class WorkspaceRendererWidget extends StatefulWidget {
  const WorkspaceRendererWidget({super.key, required this.node});

  final WorkspaceNode node;

  @override
  State<WorkspaceRendererWidget> createState() =>
      _WorkspaceRendererWidgetState();
}

class _WorkspaceRendererWidgetState extends State<WorkspaceRendererWidget> {
  int _activeTab = 0;

  @override
  Widget build(BuildContext context) {
    if (widget.node.panes.isEmpty) {
      return const SizedBox(
        height: 100,
        child: Center(child: Text('Empty Workspace')),
      );
    }

    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BatikRadius.roundedMd,
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          // Pane Tab Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withAlpha(50),
              border: Border(bottom: BorderSide(color: theme.colorScheme.outlineVariant)),
            ),
            child: Row(
              children: [
                for (var i = 0; i < widget.node.panes.length; i++) ...[
                  InkWell(
                    onTap: () => setState(() => _activeTab = i),
                    borderRadius: BatikRadius.roundedSm,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: _activeTab == i
                            ? theme.colorScheme.primaryContainer
                            : Colors.transparent,
                        borderRadius: BatikRadius.roundedSm,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (widget.node.panes[i].icon != null) ...[
                            Icon(
                              widget.node.panes[i].icon,
                              size: 14,
                              color: _activeTab == i
                                  ? theme.colorScheme.onPrimaryContainer
                                  : theme.colorScheme.outline,
                            ),
                            const SizedBox(width: 6),
                          ],
                          Text(
                            widget.node.panes[i].title,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: _activeTab == i ? FontWeight.bold : FontWeight.normal,
                              color: _activeTab == i
                                  ? theme.colorScheme.onPrimaryContainer
                                  : theme.colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
              ],
            ),
          ),
          // Active Pane View
          Padding(
            padding: const EdgeInsets.all(BatikSpacing.md),
            child: _buildActivePane(context, widget.node.panes[_activeTab]),
          ),
        ],
      ),
    );
  }

  Widget _buildActivePane(BuildContext context, WorkspacePane pane) {
    return switch (pane) {
      ChatWorkspacePane _ => Container(
          height: 180,
          alignment: Alignment.center,
          child: const Text('Agent Chat Active Session', style: TextStyle(color: Colors.grey)),
        ),
      DocumentWorkspacePane doc => SingleChildScrollView(
          child: Text(doc.content, style: BatikTypography.bodyLarge),
        ),
      DiagramWorkspacePane diag => diag.mermaid != null
          ? Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                borderRadius: BatikRadius.roundedSm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Mermaid Diagram Preview', style: BatikTypography.caption),
                  const SizedBox(height: 6),
                  Text(diag.mermaid!, style: BatikTypography.code),
                ],
              ),
            )
          : const Center(child: Text('No diagram specified')),
      ChartWorkspacePane ch => TenunChartRenderer(
          node: TenunChartNode(spec: ch.spec),
        ),
      _ => const Center(child: Text('Custom Workspace Pane')),
    };
  }
}

/// Plugin registering WorkspaceNode into Batik.
class WorkspacePlugin extends BatikPlugin {
  const WorkspacePlugin();

  @override
  PluginManifest get manifest => const PluginManifest(
        id: 'batik_workspace',
        version: '0.1.0',
        capabilities: [PluginCapability.document],
        description: 'Multi-pane Agent Workspace supporting tabbed/split views of chat, docs, diagrams, and charts.',
      );

  @override
  Future<void> initialize(BatikRuntime runtime) async {
    UINode.registerExternal('workspace', (j) => WorkspaceNode.fromJson(j));
  }

  @override
  void registerNodes(UIComponentRegistry registry) {
    registry.register<WorkspaceNode>((context, node, renderer) {
      return WorkspaceRendererWidget(node: node);
    });
  }

  @override
  String get systemPromptSection => '''
WorkspaceNode: {
  "type": "workspace",
  "layout": "tabs|split|grid",
  "panes": [
    {"type": "chat", "title": "Chat"},
    {"type": "document", "title": "Brief", "content": "..."},
    {"type": "diagram", "title": "Arch", "mermaid": "flowchart LR\\nA-->B"},
    {"type": "chart", "title": "Analytics", "spec": {"kind": "bar"}}
  ]
}''';
}

// ── Private serialization helpers ─────────────────────────────
UIStyle? _parseWsStyle(Map<String, dynamic> j) {
  final s = j['style'] as Map<String, dynamic>?;
  return s == null ? null : UIStyle.fromJson(s);
}

Map<String, UIAction> _parseWsActions(Map<String, dynamic> j) {
  final raw = j['actions'] as Map<String, dynamic>?;
  if (raw == null) return const {};
  return raw
      .map((k, v) => MapEntry(k, UIAction.fromJson(v as Map<String, dynamic>)));
}

mixin _WsNodeJsonBase on UINode {
  Map<String, dynamic> _baseWsJson() => {
        'type': type,
        if (id != null) 'id': id,
        if (style != null) 'style': style!.toJson(),
        if (actions.isNotEmpty)
          'actions': actions.map((k, v) => MapEntry(k, v.toJson())),
        if (condition != null) 'condition': condition,
      };
}
