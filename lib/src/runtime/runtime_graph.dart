// lib/src/runtime/runtime_graph.dart
//
// Batik — Runtime Graph (Patch 030)
// ============================================================
// Replaces the simple widget-tree model with a full graph where
// Widget, Chart, Diagram, Workflow, DataSource, and future node
// types are all first-class graph nodes connected by typed edges.
// ============================================================

/// Base class for every node in the Batik runtime graph.
abstract class RuntimeNode {
  RuntimeNode({required this.id, String? label}) : label = label ?? id;

  /// Stable, unique identifier within the graph.
  final String id;

  /// Human-readable label (defaults to [id]).
  final String label;

  /// Arbitrary metadata map for plugin extensions.
  Map<String, dynamic> meta = {};

  @override
  String toString() => '$runtimeType($id)';
}

// ── Concrete node types ────────────────────────────────────────

/// A node backed by a Flutter widget subtree (UINode tree).
class WidgetRuntimeNode extends RuntimeNode {
  WidgetRuntimeNode({required super.id, super.label, this.nodeType = ''});

  /// The JSON schema `type` field of the UINode root (e.g. "card", "column").
  final String nodeType;
}

/// A node that drives a chart (delegates to the active chart plugin).
class ChartRuntimeNode extends RuntimeNode {
  ChartRuntimeNode({
    required super.id,
    super.label,
    required this.chartType,
    this.dataSourceId,
  });

  /// Chart variant — "line", "bar", "pie", "area", etc.
  final String chartType;

  /// Optional reference to a registered [DataSource] id.
  final String? dataSourceId;
}

/// A node holding a [DiagramGraph] (flowchart, sequence, mindmap…).
class DiagramRuntimeNode extends RuntimeNode {
  DiagramRuntimeNode({
    required super.id,
    super.label,
    required this.diagramType,
    this.dataSourceId,
  });

  final String diagramType; // "flowchart" | "sequence" | "mindmap" | "stateMachine"
  final String? dataSourceId;
}

/// A node representing an executable workflow graph.
class WorkflowRuntimeNode extends RuntimeNode {
  WorkflowRuntimeNode({required super.id, super.label, this.dataSourceId});

  final String? dataSourceId;
}

/// A node for live documents (markdown, rich-text, embedded charts/diagrams).
class DocumentRuntimeNode extends RuntimeNode {
  DocumentRuntimeNode({required super.id, super.label});
}

/// A node linked to a data source (REST, GraphQL, MCP, SQLite…).
class DataSourceRuntimeNode extends RuntimeNode {
  DataSourceRuntimeNode({
    required super.id,
    super.label,
    required this.sourceType,
  });

  final String sourceType; // "rest" | "graphql" | "mcp" | "sqlite" | "memory"
}

/// A node representing an agent instance.
class AgentRuntimeNode extends RuntimeNode {
  AgentRuntimeNode({required super.id, super.label, this.agentId});

  final String? agentId;
}

// ── Edges ──────────────────────────────────────────────────────

/// A directed edge from [source] to [target], optionally typed.
///
/// Edge types:
///   "data"      — source provides data to target
///   "triggers"  — source event triggers target
///   "renders"   — target renders output of source
///   "depends"   — target depends on source
class RuntimeEdge {
  const RuntimeEdge({
    required this.source,
    required this.target,
    this.type = 'data',
    this.label,
  });

  final String source;
  final String target;

  /// Semantic relationship between nodes.
  final String type;

  /// Human-readable edge label (shown in inspector/debugger).
  final String? label;

  Map<String, dynamic> toJson() => {
        'source': source,
        'target': target,
        'type': type,
        if (label != null) 'label': label,
      };
}

// ── Graph ──────────────────────────────────────────────────────

/// A directed graph of [RuntimeNode]s connected by [RuntimeEdge]s.
///
/// The graph is the single source of truth for a Batik application.
/// UI, charts, diagrams, workflows, and data sources are all nodes;
/// their relationships are edges.
class RuntimeGraph {
  RuntimeGraph({
    Map<String, RuntimeNode>? nodes,
    List<RuntimeEdge>? edges,
  })  : nodes = nodes ?? {},
        edges = edges ?? [];

  final Map<String, RuntimeNode> nodes;
  final List<RuntimeEdge> edges;

  // ── Mutation helpers ─────────────────────────────────────────

  void addNode(RuntimeNode node) {
    nodes[node.id] = node;
  }

  void removeNode(String id) {
    nodes.remove(id);
    edges.removeWhere((e) => e.source == id || e.target == id);
  }

  void addEdge(RuntimeEdge edge) {
    if (!nodes.containsKey(edge.source)) {
      throw ArgumentError('Unknown source node: ${edge.source}');
    }
    if (!nodes.containsKey(edge.target)) {
      throw ArgumentError('Unknown target node: ${edge.target}');
    }
    edges.add(edge);
  }

  // ── Query helpers ─────────────────────────────────────────────

  T? nodeById<T extends RuntimeNode>(String id) {
    final n = nodes[id];
    return n is T ? n : null;
  }

  List<RuntimeNode> successors(String id) => edges
      .where((e) => e.source == id)
      .map((e) => nodes[e.target])
      .whereType<RuntimeNode>()
      .toList();

  List<RuntimeNode> predecessors(String id) => edges
      .where((e) => e.target == id)
      .map((e) => nodes[e.source])
      .whereType<RuntimeNode>()
      .toList();

  List<T> nodesOfType<T extends RuntimeNode>() =>
      nodes.values.whereType<T>().toList();

  // ── Serialisation ─────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
        'nodes': nodes.values.map((n) => {'id': n.id, 'type': n.runtimeType.toString(), 'label': n.label}).toList(),
        'edges': edges.map((e) => e.toJson()).toList(),
      };
}
