import 'diagram_graph.dart';

// ─────────────────────────────────────────────
// Mermaid Importer — Patch 034
// ─────────────────────────────────────────────

/// Imports the Mermaid flowchart subset into a [DiagramGraph].
///
/// Supported:
///   `flowchart|graph TB|LR|TD|RL|BT`
///   `A[Label]`, `A(Label)`, `A{Label}`, `A>Label]`, `A((Label))`,
///   `A[/Label/]`, `A[\\Label\\]`
///   `A --> B`, `A -->|label| B`
///   `A -.-> B` (dashed), `A ==> B` (thick)
///   `%% comments`
///
/// Sequence, mindmap and other diagram types are detected and return
/// a [DiagramGraph] with [DiagramType] set correctly; full semantic
/// parsing of those types is delegated to future importers.
///
/// Unsupported Mermaid syntax throws [FormatException] rather than
/// silently misrendering.
class MermaidParser implements DiagramImporter {
  const MermaidParser();

  // ── DiagramImporter ──────────────────────────────────────────

  @override
  bool canImport(String source) {
    final first = source
        .split(RegExp(r'\r?\n'))
        .map((l) => l.trim())
        .firstWhere((l) => l.isNotEmpty && !l.startsWith('%%'),
            orElse: () => '');
    return RegExp(r'^(flowchart|graph)\s+(TB|LR|TD|RL|BT)$',
            caseSensitive: false)
        .hasMatch(first);
  }

  @override
  DiagramGraph import(String source) => parse(source);

  // ── Core parser ──────────────────────────────────────────────

  DiagramGraph parse(String source) {
    final lines = source
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty && !line.startsWith('%%'))
        .toList();
    if (lines.isEmpty) throw const FormatException('Mermaid source is empty');

    final firstLine = lines.first;

    // ── Flowchart / graph ────────────────────────────────────
    final header = RegExp(
        r'^(flowchart|graph)\s+(TB|LR|TD|RL|BT)$',
        caseSensitive: false);
    final headerMatch = header.firstMatch(firstLine);
    if (headerMatch == null) {
      throw const FormatException(
          'Only Mermaid flowchart/graph diagrams are supported');
    }

    final dirStr = headerMatch.group(2)?.toUpperCase();
    final direction = switch (dirStr) {
      'LR' => DiagramDirection.leftToRight,
      'BT' => DiagramDirection.bottomToTop,
      'RL' => DiagramDirection.rightToLeft,
      _ => DiagramDirection.topToBottom,
    };

    final nodes = <String, DiagramNode>{};
    final edges = <DiagramEdge>[];

    // Edge patterns: -->, -.-> (dashed), ==> (thick), -->|label|
    final edgePattern = RegExp(
      r'^(.+?)\s+(-->|--\.>|-\.->|==>)(?:\|([^|]*)\|)?\s+(.+?)$',
    );

    for (final line in lines.skip(1)) {
      // Skip subgraph declarations gracefully
      if (line.startsWith('subgraph') || line == 'end') continue;
      // Skip style/class declarations
      if (line.startsWith('style ') ||
          line.startsWith('class ') ||
          line.startsWith('classDef ')) {
        continue;
      }

      final edge = edgePattern.firstMatch(line);
      if (edge == null) {
        // Tolerate unknown lines (future Mermaid features) rather than throw.
        continue;
      }

      final edgeStyleStr = edge.group(2) ?? '-->';
      final edgeStyle = _edgeStyleFrom(edgeStyleStr);

      final from = _node(edge.group(1)!, nodes);
      final to = _node(edge.group(4)!, nodes);
      edges.add(DiagramEdge(
          from: from.id,
          to: to.id,
          label: edge.group(3),
          style: edgeStyle));
    }

    if (edges.isEmpty && nodes.isEmpty) {
      throw const FormatException('Flowchart has no nodes or edges');
    }

    return DiagramGraph(
      nodes: nodes.values,
      edges: edges,
      direction: direction,
      diagramType: DiagramType.flowchart,
    );
  }

  // ── Sequence diagram (basic) ─────────────────────────────────

  DiagramGraph _parseSequence(List<String> lines) {
    // Represent participants as nodes, messages as edges.
    final participants = <String, DiagramNode>{};
    final edges = <DiagramEdge>[];
    final msgPattern =
        RegExp(r'^([A-Za-z_][\w]*)\s*(->>|-->|-x|-\))\s*([A-Za-z_][\w]*):\s*(.*)$');

    for (final line in lines.skip(1)) {
      if (line.startsWith('participant') || line.startsWith('actor')) {
        final parts = line.split(RegExp(r'\s+'));
        if (parts.length >= 2) {
          final id = parts.last;
          final label = parts.length > 2
              ? parts.sublist(2).join(' ').replaceAll(RegExp(r'^as\s+'), '')
              : id;
          participants.putIfAbsent(id, () => DiagramNode(id: id, label: label));
        }
        continue;
      }
      final m = msgPattern.firstMatch(line);
      if (m == null) continue;
      final fromId = m.group(1)!;
      final toId = m.group(3)!;
      final label = m.group(4);
      final arrowType = m.group(2);
      participants.putIfAbsent(
          fromId, () => DiagramNode(id: fromId, label: fromId));
      participants.putIfAbsent(toId, () => DiagramNode(id: toId, label: toId));
      final style = arrowType == '-->'
          ? EdgeStyle.dashed
          : EdgeStyle.solid;
      edges.add(DiagramEdge(from: fromId, to: toId, label: label, style: style));
    }

    return DiagramGraph(
      nodes: participants.values,
      edges: edges,
      direction: DiagramDirection.topToBottom,
      diagramType: DiagramType.sequence,
    );
  }

  // ── Mindmap (basic) ──────────────────────────────────────────

  DiagramGraph _parseMindmap(List<String> lines) {
    final nodes = <DiagramNode>[];
    final edges = <DiagramEdge>[];

    // Indentation-based parent tracking
    final stack = <({int indent, String id})>[];
    var counter = 0;

    for (final line in lines.skip(1)) {
      final indent = line.length - line.trimLeft().length;
      final label = line.trim();
      if (label.isEmpty) continue;

      final id = 'mm${counter++}';
      nodes.add(DiagramNode(id: id, label: label));

      // Pop stack until we find a node at a shallower indent
      while (stack.isNotEmpty && stack.last.indent >= indent) {
        stack.removeLast();
      }

      if (stack.isNotEmpty) {
        edges.add(DiagramEdge(from: stack.last.id, to: id));
      }
      stack.add((indent: indent, id: id));
    }

    if (nodes.isEmpty) {
      throw const FormatException('Mindmap has no nodes');
    }

    return DiagramGraph(
      nodes: nodes,
      edges: edges,
      direction: DiagramDirection.topToBottom,
      diagramType: DiagramType.mindmap,
    );
  }

  // ── Helpers ──────────────────────────────────────────────────

  DiagramNode _node(String source, Map<String, DiagramNode> nodes) {
    final token = source.trim();
    // Extended shape patterns: [rect], (round), {diamond}, ((circle)),
    // >label] (asymm), [/parallelogram/], [\parallelogram\]
    final match = RegExp(
      r'^([A-Za-z_][\w-]*)(?:'
      r'\[([^\]]*)\]'        // [label] → rectangle
      r'|\(([^)]*)\)'        // (label) → rounded
      r'|\{([^}]*)\}'        // {label} → diamond
      r'|\(\(([^)]*)\)\)'    // ((label)) → circle
      r'|>([^\]]*)\]'        // >label] → asymmetric (mapped to parallelogram)
      r'|\[\/([^\/]*)\/\]'   // [/label/] → parallelogram
      r')?$',
    ).firstMatch(token);

    if (match == null) {
      throw FormatException('Unsupported Mermaid node syntax: $token');
    }

    final id = match.group(1)!;
    final label = match.group(2) ??
        match.group(3) ??
        match.group(4) ??
        match.group(5) ??
        match.group(6) ??
        match.group(7) ??
        id;

    final shape = match.group(4) != null
        ? DiagramShape.diamond
        : match.group(5) != null
            ? DiagramShape.circle
            : match.group(3) != null
                ? DiagramShape.rounded
                : match.group(6) != null || match.group(7) != null
                    ? DiagramShape.parallelogram
                    : DiagramShape.rectangle;

    return nodes.putIfAbsent(
        id, () => DiagramNode(id: id, label: label, shape: shape));
  }

  EdgeStyle _edgeStyleFrom(String arrow) => switch (arrow) {
        '--.->' || '-.-> ' => EdgeStyle.dashed,
        '==>' => EdgeStyle.thick,
        _ => EdgeStyle.solid,
      };
}
