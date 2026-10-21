// lib/src/diagram/diagram_node_widget.dart
//
// Batik — DiagramNode UINode (Patch 033)
// ============================================================
// UINode subtype for the "diagram" JSON type.
// Wraps a DiagramGraph and registers into the schema.
//
// JSON schema:
// {
//   "type": "diagram",
//   "diagramType": "flowchart|sequence|mindmap|stateMachine",
//   "direction": "TB|LR|BT|RL",
//   "title": "optional title",
//   "source": "optional_datasource_id",
//   "mermaid": "optional raw Mermaid string",
//   "nodes": [...],
//   "edges": [...]
// }
// ============================================================

import 'package:flutter/material.dart';
import '../schema/ui_schema.dart';
import '../core/registry.dart';
import '../plugin/batik_plugin.dart';
import '../datasource/data_source.dart';
import 'diagram_graph.dart';
import 'diagram_renderer.dart';
import 'mermaid_parser.dart';

// ─────────────────────────────────────────────
// UINode for diagrams
// ─────────────────────────────────────────────

class DiagramUINode extends UINode with _DiagNodeJsonBase {
  DiagramUINode({
    super.id,
    super.style,
    super.actions,
    super.condition,
    required this.graph,
    this.dataSourceId,
    this.mermaidSource,
  }) : super(type: 'diagram', children: const []);

  final DiagramGraph graph;

  /// Optional DataSource id for live graph updates.
  final String? dataSourceId;

  /// Original Mermaid source string (stored for round-trip fidelity).
  final String? mermaidSource;

  factory DiagramUINode.fromJson(Map<String, dynamic> j) {
    // 1. Mermaid string takes priority if provided
    final mermaidStr = j['mermaid'] as String?;
    if (mermaidStr != null && mermaidStr.isNotEmpty) {
      final graph = const MermaidParser().parse(mermaidStr);
      return DiagramUINode(
        id: j['id'] as String?,
        style: _parseDiagStyle(j),
        actions: _parseDiagActions(j),
        condition: j['condition'] as String?,
        graph: graph,
        dataSourceId: j['source'] as String?,
        mermaidSource: mermaidStr,
      );
    }

    // 2. Inline nodes/edges JSON
    final rawNodes = j['nodes'] as List<dynamic>?;
    final rawEdges = j['edges'] as List<dynamic>?;

    if (rawNodes != null && rawEdges != null) {
      final graph = DiagramGraph.fromJson(j);
      return DiagramUINode(
        id: j['id'] as String?,
        style: _parseDiagStyle(j),
        actions: _parseDiagActions(j),
        condition: j['condition'] as String?,
        graph: graph,
        dataSourceId: j['source'] as String?,
      );
    }

    // 3. Empty placeholder (data comes from DataSource)
    final emptyGraph = DiagramGraph(
      nodes: [],
      edges: [],
      diagramType: DiagramType.parse(j['diagramType'] as String?),
      direction: DiagramDirection.parse(j['direction'] as String?),
      title: j['title'] as String?,
    );
    return DiagramUINode(
      id: j['id'] as String?,
      style: _parseDiagStyle(j),
      actions: _parseDiagActions(j),
      condition: j['condition'] as String?,
      graph: emptyGraph,
      dataSourceId: j['source'] as String?,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        ..._baseDiagJson(),
        'diagramType': graph.diagramType.name,
        if (graph.title != null) 'title': graph.title,
        if (mermaidSource != null) 'mermaid': mermaidSource,
        'nodes': graph.nodes.map((n) => n.toJson()).toList(),
        'edges': graph.edges.map((e) => e.toJson()).toList(),
        if (dataSourceId != null) 'source': dataSourceId,
      };
}

// ─────────────────────────────────────────────
// DiagramPlugin — registers UINode + renderer
// ─────────────────────────────────────────────

class DiagramPlugin extends BatikPlugin {
  const DiagramPlugin({DiagramRenderer? renderer})
      : _renderer = renderer ?? const BasicDiagramRenderer();

  final DiagramRenderer _renderer;

  @override
  PluginManifest get manifest => const PluginManifest(
        id: 'batik_diagram',
        version: '0.1.0',
        capabilities: [PluginCapability.diagram],
        description:
            'Adds flowchart, sequence, mindmap, and state machine diagrams.',
      );

  @override
  Future<void> initialize(BatikRuntime runtime) async {
    UINode.registerExternal(
        'diagram', (j) => DiagramUINode.fromJson(j));
  }

  @override
  void registerNodes(UIComponentRegistry registry) {
    registry.register<DiagramUINode>((context, node, renderer) {
      return _DiagramWidget(node: node, renderer: _renderer);
    });
  }

  @override
  void registerDataSources(DataSourceRegistry registry) {}
  @override
  void registerActions(ActionRegistry registry) {}
  @override
  void registerThemes(ThemeRegistry registry) {}

  @override
  String get systemPromptSection => '''
DiagramNode: {
  "type": "diagram",
  "diagramType": "flowchart|sequence|mindmap|stateMachine",
  "direction": "TB|LR",
  "title": "optional title",
  "nodes": [{"id": "A", "label": "Start"}, {"id": "B", "label": "End"}],
  "edges": [{"from": "A", "to": "B"}]
}

Or provide a Mermaid string directly:
{
  "type": "diagram",
  "mermaid": "flowchart LR\\nA --> B"
}''';
}

// ─────────────────────────────────────────────
// Widget
// ─────────────────────────────────────────────

class _DiagramWidget extends StatelessWidget {
  const _DiagramWidget({required this.node, required this.renderer});

  final DiagramUINode node;
  final DiagramRenderer renderer;

  @override
  Widget build(BuildContext context) {
    if (node.graph.nodes.isEmpty) {
      return _emptyPlaceholder(context);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (node.graph.title != null) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(node.graph.title!,
                style: Theme.of(context).textTheme.titleSmall),
          ),
        ],
        renderer.build(context, node.graph),
      ],
    );
  }

  Widget _emptyPlaceholder(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 80,
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outline),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text('Diagram (loading…)',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      ),
    );
  }
}

// ── private helpers ────────────────────────────────────────────
UIStyle? _parseDiagStyle(Map<String, dynamic> j) {
  final s = j['style'] as Map<String, dynamic>?;
  return s == null ? null : UIStyle.fromJson(s);
}

Map<String, UIAction> _parseDiagActions(Map<String, dynamic> j) {
  final raw = j['actions'] as Map<String, dynamic>?;
  if (raw == null) return const {};
  return raw
      .map((k, v) => MapEntry(k, UIAction.fromJson(v as Map<String, dynamic>)));
}

mixin _DiagNodeJsonBase on UINode {
  Map<String, dynamic> _baseDiagJson() => {
        'type': type,
        if (id != null) 'id': id,
        if (style != null) 'style': style!.toJson(),
        if (actions.isNotEmpty)
          'actions': actions.map((k, v) => MapEntry(k, v.toJson())),
        if (condition != null) 'condition': condition,
      };
}
