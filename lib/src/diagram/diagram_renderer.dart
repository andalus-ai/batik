import 'package:flutter/material.dart';
import 'diagram_graph.dart';

/// Rendering boundary for diagram plugins. Layout and painting can be
/// replaced without changing the graph or Mermaid importer.
abstract interface class DiagramRenderer {
  Widget build(BuildContext context, DiagramGraph graph);
}

class BasicDiagramRenderer implements DiagramRenderer {
  const BasicDiagramRenderer();

  @override
  Widget build(BuildContext context, DiagramGraph graph) => CustomPaint(
      size: const Size(double.infinity, 240),
      painter: _DiagramPainter(graph, Theme.of(context)));
}

class _DiagramPainter extends CustomPainter {
  const _DiagramPainter(this.graph, this.theme);
  final DiagramGraph graph;
  final ThemeData theme;

  @override
  void paint(Canvas canvas, Size size) {
    final horizontal = graph.direction == DiagramDirection.leftToRight;
    final columns = horizontal ? graph.nodes.length : 1;
    final gap = horizontal
        ? size.width / (columns + 1)
        : size.height / (graph.nodes.length + 1);
    final positions = <String, Offset>{};
    for (var i = 0; i < graph.nodes.length; i++) {
      positions[graph.nodes[i].id] = horizontal
          ? Offset(gap * (i + 1), size.height / 2)
          : Offset(size.width / 2, gap * (i + 1));
    }
    final edgePaint = Paint()..color = theme.colorScheme.outline;
    for (final edge in graph.edges) {
      canvas.drawLine(positions[edge.from]!, positions[edge.to]!, edgePaint);
    }
    final fill = Paint()..color = theme.colorScheme.primaryContainer;
    final text = TextPainter(textDirection: TextDirection.ltr);
    for (final node in graph.nodes) {
      final center = positions[node.id]!;
      final rect = Rect.fromCenter(center: center, width: 120, height: 42);
      canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(8)), fill);
      text.text = TextSpan(text: node.label, style: theme.textTheme.bodySmall);
      text.layout(maxWidth: 108);
      text.paint(canvas, center - Offset(text.width / 2, text.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant _DiagramPainter oldDelegate) =>
      oldDelegate.graph != graph || oldDelegate.theme != theme;
}
