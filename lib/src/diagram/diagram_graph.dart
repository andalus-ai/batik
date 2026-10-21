import 'dart:convert';

// ─────────────────────────────────────────────
// Diagram Graph — Patch 033 (Core) + Patch 034 (Mermaid Importer)
// ─────────────────────────────────────────────

/// High-level type of diagram rendered from this graph.
///
/// Drives layout engine selection and renderer hints.
enum DiagramType {
  flowchart,
  sequence,
  stateMachine,
  mindmap,
  entityRelationship,
  classDiagram,
  gitGraph;

  static DiagramType parse(String? value) => DiagramType.values.firstWhere(
        (t) => t.name == value?.toLowerCase(),
        orElse: () => DiagramType.flowchart,
      );
}

/// Edge style hint for renderers.
enum EdgeStyle {
  solid,
  dashed,
  dotted,
  thick;

  static EdgeStyle parse(String? value) => EdgeStyle.values.firstWhere(
        (s) => s.name == value?.toLowerCase(),
        orElse: () => EdgeStyle.solid,
      );
}

/// A renderer-independent graph used by flowcharts, sequence diagrams,
/// mindmaps, and future diagram plugins.
///
/// Constructed directly or via [DiagramImporter] subclasses (e.g. [MermaidParser]).
class DiagramGraph {
  DiagramGraph({
    required Iterable<DiagramNode> nodes,
    required Iterable<DiagramEdge> edges,
    this.direction = DiagramDirection.topToBottom,
    this.diagramType = DiagramType.flowchart,
    this.title,
  })  : nodes = List.unmodifiable(nodes),
        edges = List.unmodifiable(edges) {
    final ids = this.nodes.map((node) => node.id).toSet();
    for (final edge in this.edges) {
      if (!ids.contains(edge.from) || !ids.contains(edge.to)) {
        throw FormatException(
            'Diagram edge references unknown node: '
            '"${edge.from}" → "${edge.to}"');
      }
    }
  }

  final List<DiagramNode> nodes;
  final List<DiagramEdge> edges;
  final DiagramDirection direction;

  /// Semantic diagram type — drives renderer selection.
  final DiagramType diagramType;

  /// Optional diagram title shown by renderers that support it.
  final String? title;

  factory DiagramGraph.fromJson(Map<String, dynamic> json) {
    final rawNodes = json['nodes'];
    final rawEdges = json['edges'];
    if (rawNodes is! List || rawEdges is! List) {
      throw const FormatException('Diagram requires nodes and edges arrays');
    }
    return DiagramGraph(
      nodes: rawNodes.map((value) => DiagramNode.fromJson(_map(value))),
      edges: rawEdges.map((value) => DiagramEdge.fromJson(_map(value))),
      direction: DiagramDirection.parse(json['direction'] as String?),
      diagramType: DiagramType.parse(json['diagramType'] as String?),
      title: json['title'] as String?,
    );
  }

  factory DiagramGraph.fromJsonString(String source) =>
      DiagramGraph.fromJson(jsonDecode(source) as Map<String, dynamic>);

  Map<String, dynamic> toJson() => {
        'direction': direction.name,
        'diagramType': diagramType.name,
        if (title != null) 'title': title,
        'nodes': nodes.map((node) => node.toJson()).toList(),
        'edges': edges.map((edge) => edge.toJson()).toList(),
      };

  static Map<String, dynamic> _map(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return value.map((key, value) => MapEntry('$key', value));
    throw const FormatException('Diagram entries must be objects');
  }
}

// ─────────────────────────────────────────────
// Diagram node — enhanced with metadata
// ─────────────────────────────────────────────

class DiagramNode {
  const DiagramNode({
    required this.id,
    required this.label,
    this.shape = DiagramShape.rectangle,
    this.description,
    this.color,
    this.group,
    this.meta = const {},
  });

  final String id;
  final String label;
  final DiagramShape shape;

  /// Optional tooltip / description shown on hover.
  final String? description;

  /// Optional hex color override for this node.
  final String? color;

  /// Optional group/cluster identifier for layout.
  final String? group;

  /// Arbitrary metadata for plugin extensions.
  final Map<String, dynamic> meta;

  factory DiagramNode.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final label = json['label'];
    if (id is! String || id.trim().isEmpty || label is! String) {
      throw const FormatException(
          'Diagram nodes require non-empty id and label');
    }
    return DiagramNode(
      id: id.trim(),
      label: label,
      shape: DiagramShape.parse(json['shape'] as String?),
      description: json['description'] as String?,
      color: json['color'] as String?,
      group: json['group'] as String?,
      meta: json['meta'] as Map<String, dynamic>? ?? {},
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'shape': shape.name,
        if (description != null) 'description': description,
        if (color != null) 'color': color,
        if (group != null) 'group': group,
        if (meta.isNotEmpty) 'meta': meta,
      };
}

// ─────────────────────────────────────────────
// Diagram edge — enhanced with style
// ─────────────────────────────────────────────

class DiagramEdge {
  const DiagramEdge({
    required this.from,
    required this.to,
    this.label,
    this.style = EdgeStyle.solid,
    this.directed = true,
    this.color,
  });

  final String from;
  final String to;
  final String? label;

  /// Line style hint for renderers.
  final EdgeStyle style;

  /// If false, renders as an undirected line (no arrow).
  final bool directed;

  /// Optional hex color override.
  final String? color;

  factory DiagramEdge.fromJson(Map<String, dynamic> json) {
    final from = json['from'];
    final to = json['to'];
    if (from is! String || to is! String || from.isEmpty || to.isEmpty) {
      throw const FormatException('Diagram edges require from and to');
    }
    return DiagramEdge(
      from: from,
      to: to,
      label: json['label'] as String?,
      style: EdgeStyle.parse(json['style'] as String?),
      directed: json['directed'] as bool? ?? true,
      color: json['color'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'from': from,
        'to': to,
        if (label != null) 'label': label,
        'style': style.name,
        'directed': directed,
        if (color != null) 'color': color,
      };
}

// ─────────────────────────────────────────────
// Direction + Shape enums
// ─────────────────────────────────────────────

enum DiagramDirection {
  topToBottom,
  leftToRight,
  bottomToTop,
  rightToLeft;

  static DiagramDirection parse(String? value) =>
      switch (value?.toLowerCase()) {
        'lr' || 'leftright' || 'lefttoright' => leftToRight,
        'bt' || 'bottomtotop' => bottomToTop,
        'rl' || 'righttoleft' => rightToLeft,
        _ => topToBottom,
      };
}

enum DiagramShape {
  rectangle,
  rounded,
  diamond,
  circle,
  ellipse,
  parallelogram,
  hexagon,
  cylinder,
  subroutine;

  static DiagramShape parse(String? value) => DiagramShape.values.firstWhere(
        (shape) => shape.name == value?.toLowerCase(),
        orElse: () => rectangle,
      );
}

// ─────────────────────────────────────────────
// Diagram importer interface (Patch 034)
// ─────────────────────────────────────────────

/// Contract for converting external diagram formats into [DiagramGraph].
///
/// Mermaid is the primary implementation; others (PlantUML, DOT/Graphviz)
/// can be added as separate packages implementing this interface.
abstract interface class DiagramImporter {
  /// Parse [source] text and return a [DiagramGraph].
  ///
  /// Throws [FormatException] if the source cannot be parsed.
  DiagramGraph import(String source);

  /// Returns true if this importer can handle [source].
  bool canImport(String source);
}
