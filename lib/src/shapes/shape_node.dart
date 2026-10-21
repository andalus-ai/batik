// lib/src/shapes/shape_node.dart
//
// Batik — Shape Engine (Patch 034 / Section 4)
// ============================================================
// Vector shape nodes for diagrams, floorplans, CAD overlays,
// process maps, and custom graphic visualizations.
//
// JSON schema:
// {
//   "type": "shape",
//   "shape": "circle|ellipse|polygon|rect|path|arc|group",
//   "points": [{"x": 10, "y": 20}, ...],
//   "radius": 40,
//   "width": 100,
//   "height": 50,
//   "fill": "#E2B062",
//   "stroke": "#3E2723",
//   "strokeWidth": 2.0
// }
// ============================================================

import 'package:flutter/material.dart';
import '../schema/ui_schema.dart';
import '../core/registry.dart';
import '../plugin/batik_plugin.dart';

/// Supported geometric shape types.
enum ShapeType {
  circle,
  ellipse,
  polygon,
  rect,
  path,
  arc,
  group;

  static ShapeType parse(String? value) => ShapeType.values.firstWhere(
        (s) => s.name == value?.toLowerCase(),
        orElse: () => ShapeType.rect,
      );
}

/// Simple 2D point representation.
class ShapePoint {
  const ShapePoint(this.x, this.y);

  final double x;
  final double y;

  factory ShapePoint.fromJson(Map<String, dynamic> j) => ShapePoint(
        (j['x'] as num?)?.toDouble() ?? 0.0,
        (j['y'] as num?)?.toDouble() ?? 0.0,
      );

  Map<String, dynamic> toJson() => {'x': x, 'y': y};

  Offset toOffset() => Offset(x, y);
}

/// UINode representing a vector shape.
class ShapeNode extends UINode with _ShapeNodeJsonBase {
  ShapeNode({
    super.id,
    super.style,
    super.actions,
    super.condition,
    super.children,
    required this.shapeType,
    this.points = const [],
    this.radius,
    this.width,
    this.height,
    this.fillColor,
    this.strokeColor,
    this.strokeWidth = 1.0,
    this.startAngle = 0.0,
    this.sweepAngle = 3.14159,
  }) : super(type: 'shape');

  final ShapeType shapeType;
  final List<ShapePoint> points;
  final double? radius;
  final double? width;
  final double? height;
  final String? fillColor;
  final String? strokeColor;
  final double strokeWidth;
  final double startAngle;
  final double sweepAngle;

  factory ShapeNode.fromJson(Map<String, dynamic> j) => ShapeNode(
        id: j['id'] as String?,
        style: _parseShapeStyle(j),
        actions: _parseShapeActions(j),
        condition: j['condition'] as String?,
        shapeType: ShapeType.parse(j['shape'] as String?),
        points: (j['points'] as List<dynamic>? ?? [])
            .map((p) => ShapePoint.fromJson(p as Map<String, dynamic>))
            .toList(),
        radius: (j['radius'] as num?)?.toDouble(),
        width: (j['width'] as num?)?.toDouble(),
        height: (j['height'] as num?)?.toDouble(),
        fillColor: j['fill'] as String?,
        strokeColor: j['stroke'] as String?,
        strokeWidth: (j['strokeWidth'] as num?)?.toDouble() ?? 1.0,
        startAngle: (j['startAngle'] as num?)?.toDouble() ?? 0.0,
        sweepAngle: (j['sweepAngle'] as num?)?.toDouble() ?? 3.14159,
        children: (j['children'] as List<dynamic>? ?? [])
            .map((c) => UINode.fromJson(c as Map<String, dynamic>))
            .toList(),
      );

  @override
  Map<String, dynamic> toJson() => {
        ..._baseShapeJson(),
        'shape': shapeType.name,
        if (points.isNotEmpty)
          'points': points.map((p) => p.toJson()).toList(),
        if (radius != null) 'radius': radius,
        if (width != null) 'width': width,
        if (height != null) 'height': height,
        if (fillColor != null) 'fill': fillColor,
        if (strokeColor != null) 'stroke': strokeColor,
        'strokeWidth': strokeWidth,
        if (shapeType == ShapeType.arc) ...{
          'startAngle': startAngle,
          'sweepAngle': sweepAngle,
        },
        if (children.isNotEmpty)
          'children': children.map((c) => c.toJson()).toList(),
      };
}

/// Renderer widget for ShapeNode.
class ShapeRendererWidget extends StatelessWidget {
  const ShapeRendererWidget({super.key, required this.node});

  final ShapeNode node;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final w = node.width ?? (node.radius != null ? node.radius! * 2 : 100.0);
    final h = node.height ?? (node.radius != null ? node.radius! * 2 : 100.0);

    return SizedBox(
      width: w,
      height: h,
      child: CustomPaint(
        painter: _ShapePainter(node: node, theme: theme),
      ),
    );
  }
}

class _ShapePainter extends CustomPainter {
  _ShapePainter({required this.node, required this.theme});

  final ShapeNode node;
  final ThemeData theme;

  Color _parseColor(String? hex, Color fallback) {
    if (hex == null || hex.isEmpty) return fallback;
    final clean = hex.replaceAll('#', '');
    final val = int.tryParse(clean.length == 6 ? 'FF$clean' : clean, radix: 16);
    return val != null ? Color(val) : fallback;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final fillPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = _parseColor(node.fillColor, theme.colorScheme.primaryContainer);

    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = node.strokeWidth
      ..color = _parseColor(node.strokeColor, theme.colorScheme.outline);

    final hasFill = node.fillColor != null;
    final hasStroke = node.strokeColor != null || !hasFill;

    switch (node.shapeType) {
      case ShapeType.circle:
        final r = node.radius ?? (size.shortestSide / 2);
        final center = Offset(size.width / 2, size.height / 2);
        if (hasFill) canvas.drawCircle(center, r, fillPaint);
        if (hasStroke) canvas.drawCircle(center, r, strokePaint);

      case ShapeType.ellipse:
        final rect = Rect.fromLTWH(0, 0, size.width, size.height);
        if (hasFill) canvas.drawOval(rect, fillPaint);
        if (hasStroke) canvas.drawOval(rect, strokePaint);

      case ShapeType.rect:
        final rect = Rect.fromLTWH(0, 0, size.width, size.height);
        final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(8));
        if (hasFill) canvas.drawRRect(rrect, fillPaint);
        if (hasStroke) canvas.drawRRect(rrect, strokePaint);

      case ShapeType.polygon:
        if (node.points.length >= 2) {
          final path = Path()..moveTo(node.points.first.x, node.points.first.y);
          for (var i = 1; i < node.points.length; i++) {
            path.lineTo(node.points[i].x, node.points[i].y);
          }
          path.close();
          if (hasFill) canvas.drawPath(path, fillPaint);
          if (hasStroke) canvas.drawPath(path, strokePaint);
        }

      case ShapeType.path:
        if (node.points.length >= 2) {
          final path = Path()..moveTo(node.points.first.x, node.points.first.y);
          for (var i = 1; i < node.points.length; i++) {
            path.lineTo(node.points[i].x, node.points[i].y);
          }
          canvas.drawPath(path, strokePaint);
        }

      case ShapeType.arc:
        final rect = Rect.fromLTWH(0, 0, size.width, size.height);
        if (hasFill) {
          canvas.drawArc(rect, node.startAngle, node.sweepAngle, true, fillPaint);
        }
        if (hasStroke) {
          canvas.drawArc(rect, node.startAngle, node.sweepAngle, false, strokePaint);
        }

      case ShapeType.group:
        // Group shapes render in children traversal
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _ShapePainter oldDelegate) => true;
}

/// Plugin registering ShapeNode into Batik.
class ShapePlugin extends BatikPlugin {
  const ShapePlugin();

  @override
  PluginManifest get manifest => const PluginManifest(
        id: 'batik_shapes',
        version: '0.1.0',
        capabilities: [PluginCapability.diagram],
        description: 'Provides 2D vector shapes (circle, polygon, rect, path, arc).',
      );

  @override
  Future<void> initialize(BatikRuntime runtime) async {
    UINode.registerExternal('shape', (j) => ShapeNode.fromJson(j));
  }

  @override
  void registerNodes(UIComponentRegistry registry) {
    registry.register<ShapeNode>((context, node, renderer) {
      return ShapeRendererWidget(node: node);
    });
  }

  @override
  String get systemPromptSection => '''
ShapeNode: {
  "type": "shape",
  "shape": "circle|ellipse|polygon|rect|path|arc",
  "width": 100,
  "height": 100,
  "fill": "#hexColor",
  "stroke": "#hexColor",
  "strokeWidth": 2.0,
  "points": [{"x": 0, "y": 0}, {"x": 50, "y": 100}, {"x": 100, "y": 0}] // for polygon/path
}''';
}

// ── Private serialization helpers ─────────────────────────────
UIStyle? _parseShapeStyle(Map<String, dynamic> j) {
  final s = j['style'] as Map<String, dynamic>?;
  return s == null ? null : UIStyle.fromJson(s);
}

Map<String, UIAction> _parseShapeActions(Map<String, dynamic> j) {
  final raw = j['actions'] as Map<String, dynamic>?;
  if (raw == null) return const {};
  return raw
      .map((k, v) => MapEntry(k, UIAction.fromJson(v as Map<String, dynamic>)));
}

mixin _ShapeNodeJsonBase on UINode {
  Map<String, dynamic> _baseShapeJson() => {
        'type': type,
        if (id != null) 'id': id,
        if (style != null) 'style': style!.toJson(),
        if (actions.isNotEmpty)
          'actions': actions.map((k, v) => MapEntry(k, v.toJson())),
        if (condition != null) 'condition': condition,
      };
}
