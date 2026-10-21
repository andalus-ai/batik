// lib/src/workflow/workflow_runtime.dart
//
// Batik — Workflow Runtime (Patch 035)
// ============================================================
// Declarative workflow graphs that are executable by an agent
// or triggered by UI events.
//
// JSON schema:
// {
//   "type": "workflow",
//   "id": "onboarding_flow",
//   "graph": {
//     "nodes": [
//       {"id": "start",    "nodeType": "start"},
//       {"id": "validate", "nodeType": "task", "label": "Validate input"},
//       {"id": "decide",   "nodeType": "condition", "label": "Valid?"},
//       {"id": "success",  "nodeType": "end"},
//       {"id": "failure",  "nodeType": "end"}
//     ],
//     "edges": [
//       {"from": "start",    "to": "validate"},
//       {"from": "validate", "to": "decide"},
//       {"from": "decide",   "to": "success", "label": "yes"},
//       {"from": "decide",   "to": "failure", "label": "no"}
//     ]
//   }
// }
// ============================================================

import 'package:flutter/material.dart';
import '../schema/ui_schema.dart';
import '../plugin/batik_plugin.dart';
import '../core/registry.dart';
import '../datasource/data_source.dart';

// ─────────────────────────────────────────────
// 1. Workflow node types
// ─────────────────────────────────────────────

/// The kind of a workflow node, analogous to BPMN element types.
enum WorkflowNodeType {
  start,
  end,
  task,
  condition,
  agent,
  tool,
  loop,
  parallel,
}

/// A single node in a [WorkflowGraph].
class WorkflowNode {
  const WorkflowNode({
    required this.id,
    required this.nodeType,
    this.label,
    this.description,
    this.config = const {},
  });

  final String id;
  final WorkflowNodeType nodeType;
  final String? label;
  final String? description;

  /// Node-specific configuration (tool name, agent id, condition expr…).
  final Map<String, dynamic> config;

  factory WorkflowNode.fromJson(Map<String, dynamic> j) {
    final typeStr = j['nodeType'] as String? ?? 'task';
    return WorkflowNode(
      id: j['id'] as String,
      nodeType: WorkflowNodeType.values.firstWhere(
        (t) => t.name == typeStr,
        orElse: () => WorkflowNodeType.task,
      ),
      label: j['label'] as String?,
      description: j['description'] as String?,
      config: j['config'] as Map<String, dynamic>? ?? {},
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'nodeType': nodeType.name,
        if (label != null) 'label': label,
        if (description != null) 'description': description,
        if (config.isNotEmpty) 'config': config,
      };
}

// ─────────────────────────────────────────────
// 2. Workflow edges
// ─────────────────────────────────────────────

class WorkflowEdge {
  const WorkflowEdge({
    required this.from,
    required this.to,
    this.label,
    this.condition,
  });

  final String from;
  final String to;

  /// Optional edge label (e.g. "yes" / "no" on a condition node).
  final String? label;

  /// Optional condition expression that must evaluate true for this edge.
  final String? condition;

  factory WorkflowEdge.fromJson(Map<String, dynamic> j) => WorkflowEdge(
        from: j['from'] as String,
        to: j['to'] as String,
        label: j['label'] as String?,
        condition: j['condition'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'from': from,
        'to': to,
        if (label != null) 'label': label,
        if (condition != null) 'condition': condition,
      };
}

// ─────────────────────────────────────────────
// 3. Workflow graph
// ─────────────────────────────────────────────

class WorkflowGraph {
  WorkflowGraph({
    required Iterable<WorkflowNode> nodes,
    required Iterable<WorkflowEdge> edges,
  })  : nodes = Map.fromIterable(nodes, key: (n) => (n as WorkflowNode).id),
        edges = List.unmodifiable(edges);

  final Map<String, WorkflowNode> nodes;
  final List<WorkflowEdge> edges;

  WorkflowNode? get startNode => nodes.values.cast<WorkflowNode?>().firstWhere(
      (n) => n?.nodeType == WorkflowNodeType.start,
      orElse: () => null);

  List<WorkflowEdge> edgesFrom(String nodeId) =>
      edges.where((e) => e.from == nodeId).toList();

  factory WorkflowGraph.fromJson(Map<String, dynamic> j) {
    final rawNodes = (j['nodes'] as List<dynamic>? ?? [])
        .map((e) => WorkflowNode.fromJson(e as Map<String, dynamic>));
    final rawEdges = (j['edges'] as List<dynamic>? ?? [])
        .map((e) => WorkflowEdge.fromJson(e as Map<String, dynamic>));
    return WorkflowGraph(nodes: rawNodes, edges: rawEdges);
  }

  Map<String, dynamic> toJson() => {
        'nodes': nodes.values.map((n) => n.toJson()).toList(),
        'edges': edges.map((e) => e.toJson()).toList(),
      };
}

// ─────────────────────────────────────────────
// 4. Execution engine
// ─────────────────────────────────────────────

/// Outcome of a workflow step or full execution.
class WorkflowResult {
  const WorkflowResult({
    required this.completed,
    this.outputs = const {},
    this.error,
    this.executedNodes = const [],
  });

  final bool completed;
  final Map<String, dynamic> outputs;
  final Object? error;
  final List<String> executedNodes;

  bool get isOk => error == null;
}

/// Context passed to task handlers during execution.
class WorkflowContext {
  WorkflowContext({Map<String, dynamic>? initialVars})
      : variables = Map.of(initialVars ?? {});

  final Map<String, dynamic> variables;

  void set(String key, dynamic value) => variables[key] = value;
  dynamic get(String key) => variables[key];
}

/// Callback for executing a single [WorkflowNode].
typedef WorkflowTaskHandler = Future<Map<String, dynamic>> Function(
  WorkflowNode node,
  WorkflowContext context,
);

/// Simple sequential executor for [WorkflowGraph].
///
/// Condition nodes evaluate the `"expr"` field in [WorkflowNode.config]
/// against context variables. Implementors can inject a real expression
/// evaluator via [conditionEvaluator].
class WorkflowExecutor {
  WorkflowExecutor({
    this.taskHandler,
    bool Function(String expr, WorkflowContext ctx)? conditionEvaluator,
  }) : _conditionEvaluator =
            conditionEvaluator ?? ((expr, ctx) => ctx.get(expr) == true);

  final WorkflowTaskHandler? taskHandler;
  final bool Function(String expr, WorkflowContext ctx) _conditionEvaluator;

  Future<WorkflowResult> execute(
    WorkflowGraph graph, {
    Map<String, dynamic>? initialVars,
  }) async {
    final ctx = WorkflowContext(initialVars: initialVars);
    final executedNodes = <String>[];
    final outputs = <String, dynamic>{};

    try {
      var current = graph.startNode;
      while (current != null) {
        executedNodes.add(current.id);

        switch (current.nodeType) {
          case WorkflowNodeType.start:
            break; // no-op

          case WorkflowNodeType.end:
            return WorkflowResult(
              completed: true,
              outputs: {...outputs, ...ctx.variables},
              executedNodes: executedNodes,
            );

          case WorkflowNodeType.task:
          case WorkflowNodeType.agent:
          case WorkflowNodeType.tool:
            if (taskHandler != null) {
              final result = await taskHandler!(current, ctx);
              outputs[current.id] = result;
              result.forEach((k, v) => ctx.set(k, v));
            }

          case WorkflowNodeType.condition:
            final expr = current.config['expr'] as String? ?? current.id;
            final conditionResult = _conditionEvaluator(expr, ctx);
            ctx.set('${current.id}.result', conditionResult);

          case WorkflowNodeType.loop:
          case WorkflowNodeType.parallel:
            // TODO(patch-035+): implement loop / parallel execution.
            break;
        }

        // Advance to next node
        current = _nextNode(graph, current, ctx);
      }

      return WorkflowResult(
        completed: false,
        outputs: {...outputs, ...ctx.variables},
        error: 'Workflow ended without reaching an end node',
        executedNodes: executedNodes,
      );
    } catch (e) {
      return WorkflowResult(
        completed: false,
        outputs: {...outputs, ...ctx.variables},
        error: e,
        executedNodes: executedNodes,
      );
    }
  }

  WorkflowNode? _nextNode(
      WorkflowGraph graph, WorkflowNode current, WorkflowContext ctx) {
    final edges = graph.edgesFrom(current.id);
    if (edges.isEmpty) return null;

    // For condition nodes, find matching branch.
    if (current.nodeType == WorkflowNodeType.condition) {
      final condResult = ctx.get('${current.id}.result') as bool? ?? false;
      final branch = edges.firstWhere(
        (e) => e.label == (condResult ? 'yes' : 'no'),
        orElse: () => edges.first,
      );
      return graph.nodes[branch.to];
    }

    // Otherwise take the first (or only) edge.
    return graph.nodes[edges.first.to];
  }
}

// ─────────────────────────────────────────────
// 5. UINode for workflows
// ─────────────────────────────────────────────

/// UINode that embeds an executable workflow.
///
/// The renderer shows the workflow graph visually and optionally
/// allows the user to trigger execution.
class WorkflowNode2 extends UINode with _WfNodeJsonBase {
  WorkflowNode2({
    super.id,
    super.style,
    super.actions,
    super.condition,
    required this.graph,
    this.autoExecute = false,
    this.showVisual = true,
  }) : super(type: 'workflow', children: const []);

  final WorkflowGraph graph;

  /// If true, execution starts automatically when the node is rendered.
  final bool autoExecute;

  /// If true, renders a visual diagram of the graph.
  final bool showVisual;

  factory WorkflowNode2.fromJson(Map<String, dynamic> j) => WorkflowNode2(
        id: j['id'] as String?,
        style: _parseWfStyle(j),
        actions: _parseWfActions(j),
        condition: j['condition'] as String?,
        graph:
            WorkflowGraph.fromJson(j['graph'] as Map<String, dynamic>? ?? {}),
        autoExecute: j['autoExecute'] as bool? ?? false,
        showVisual: j['showVisual'] as bool? ?? true,
      );

  @override
  Map<String, dynamic> toJson() => {
        ..._baseWfJson(),
        'graph': graph.toJson(),
        'autoExecute': autoExecute,
        'showVisual': showVisual,
      };
}

// ─────────────────────────────────────────────
// 6. WorkflowPlugin
// ─────────────────────────────────────────────

class WorkflowPlugin extends BatikPlugin {
  const WorkflowPlugin({this.taskHandler});

  final WorkflowTaskHandler? taskHandler;

  @override
  PluginManifest get manifest => const PluginManifest(
        id: 'batik_workflow',
        version: '0.1.0',
        capabilities: [PluginCapability.workflow],
        description: 'Adds executable workflow graphs to the Batik runtime.',
      );

  @override
  Future<void> initialize(BatikRuntime runtime) async {
    UINode.registerExternal('workflow', (j) => WorkflowNode2.fromJson(j));
  }

  @override
  void registerNodes(UIComponentRegistry registry) {
    registry.register<WorkflowNode2>((context, node, renderer) {
      return _WorkflowVisual(node: node, taskHandler: taskHandler);
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
WorkflowNode: {
  "type": "workflow",
  "showVisual": true,
  "autoExecute": false,
  "graph": {
    "nodes": [
      {"id": "start",   "nodeType": "start"},
      {"id": "step1",   "nodeType": "task", "label": "Do something"},
      {"id": "decide",  "nodeType": "condition", "label": "Check result", "config": {"expr": "step1.ok"}},
      {"id": "success", "nodeType": "end"},
      {"id": "failure", "nodeType": "end"}
    ],
    "edges": [
      {"from": "start",  "to": "step1"},
      {"from": "step1",  "to": "decide"},
      {"from": "decide", "to": "success", "label": "yes"},
      {"from": "decide", "to": "failure", "label": "no"}
    ]
  }
}''';
}

// ─────────────────────────────────────────────
// 7. Workflow visual widget (minimal)
// ─────────────────────────────────────────────

class _WorkflowVisual extends StatelessWidget {
  const _WorkflowVisual({required this.node, this.taskHandler});

  final WorkflowNode2 node;
  final WorkflowTaskHandler? taskHandler;

  @override
  Widget build(BuildContext context) {
    if (!node.showVisual) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outline),
        borderRadius: BorderRadius.circular(10),
        color: theme.colorScheme.surface,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.account_tree_outlined,
                color: theme.colorScheme.primary, size: 18),
            const SizedBox(width: 6),
            Text('Workflow', style: theme.textTheme.titleSmall),
            const Spacer(),
            Text('${node.graph.nodes.length} nodes',
                style: theme.textTheme.bodySmall),
          ]),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: node.graph.nodes.values
                .map((n) => Chip(
                      label: Text(n.label ?? n.id,
                          style: const TextStyle(fontSize: 11)),
                      avatar: Icon(_iconFor(n.nodeType), size: 14),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }

  IconData _iconFor(WorkflowNodeType t) => switch (t) {
        WorkflowNodeType.start => Icons.play_circle_outline,
        WorkflowNodeType.end => Icons.stop_circle_outlined,
        WorkflowNodeType.condition => Icons.call_split,
        WorkflowNodeType.agent => Icons.smart_toy_outlined,
        WorkflowNodeType.tool => Icons.build_outlined,
        WorkflowNodeType.loop => Icons.loop,
        WorkflowNodeType.parallel => Icons.fork_right,
        _ => Icons.circle_outlined,
      };
}

// ── private helpers ────────────────────────────────────────────
UIStyle? _parseWfStyle(Map<String, dynamic> j) {
  final s = j['style'] as Map<String, dynamic>?;
  return s == null ? null : UIStyle.fromJson(s);
}

Map<String, UIAction> _parseWfActions(Map<String, dynamic> j) {
  final raw = j['actions'] as Map<String, dynamic>?;
  if (raw == null) return const {};
  return raw
      .map((k, v) => MapEntry(k, UIAction.fromJson(v as Map<String, dynamic>)));
}

mixin _WfNodeJsonBase on UINode {
  Map<String, dynamic> _baseWfJson() => {
        'type': type,
        if (id != null) 'id': id,
        if (style != null) 'style': style!.toJson(),
        if (actions.isNotEmpty)
          'actions': actions.map((k, v) => MapEntry(k, v.toJson())),
        if (condition != null) 'condition': condition,
      };
}
