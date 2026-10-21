// lib/src/tenun/tenun_adapter.dart
//
// Batik — Tenun Chart Adapter (Patch 032)
// ============================================================
// Delegates chart rendering to the Tenun chart engine.
//
// Tenun is the canonical chart backend for Batik.
// This file provides:
//   • TenunChartNode   — UINode subclass for "tenun_chart" JSON
//   • TenunPlugin      — BatikPlugin that registers the node
//   • ChartSpec        — typed spec parsed from JSON
//
// JSON schema:
// {
//   "type": "tenun_chart",
//   "spec": {
//     "kind": "line|bar|pie|area|scatter|radar",
//     "series": [...],
//     "title": "...",
//     "xAxis": {...},
//     "yAxis": {...}
//   },
//   "source": "datasource_id"   // optional DataSource reference
// }
//
// Install tenun when available:
//   dependencies:
//     tenun: ^0.x.0
// ============================================================

import 'package:flutter/material.dart';
import '../schema/ui_schema.dart';
import '../core/registry.dart';
import '../plugin/batik_plugin.dart';
import '../datasource/data_source.dart';

// ─────────────────────────────────────────────
// 1. Chart spec
// ─────────────────────────────────────────────

/// Typed representation of the Tenun chart specification.
class ChartSpec {
  const ChartSpec({
    required this.kind,
    this.series = const [],
    this.title,
    this.xAxis,
    this.yAxis,
    this.legend = true,
    this.animated = true,
    this.extra = const {},
  });

  /// Chart variant: "line" | "bar" | "pie" | "area" | "scatter" | "radar"
  final String kind;

  final List<ChartSeriesSpec> series;
  final String? title;
  final ChartAxisSpec? xAxis;
  final ChartAxisSpec? yAxis;
  final bool legend;
  final bool animated;

  /// Pass-through for Tenun-specific options not yet mapped here.
  final Map<String, dynamic> extra;

  factory ChartSpec.fromJson(Map<String, dynamic> j) => ChartSpec(
        kind: j['kind'] as String? ?? 'bar',
        series: (j['series'] as List<dynamic>? ?? [])
            .map((e) => ChartSeriesSpec.fromJson(e as Map<String, dynamic>))
            .toList(),
        title: j['title'] as String?,
        xAxis: j['xAxis'] != null
            ? ChartAxisSpec.fromJson(j['xAxis'] as Map<String, dynamic>)
            : null,
        yAxis: j['yAxis'] != null
            ? ChartAxisSpec.fromJson(j['yAxis'] as Map<String, dynamic>)
            : null,
        legend: j['legend'] as bool? ?? true,
        animated: j['animated'] as bool? ?? true,
        extra: Map<String, dynamic>.from(j)
          ..removeWhere((k, _) =>
              {'kind', 'series', 'title', 'xAxis', 'yAxis', 'legend', 'animated'}
                  .contains(k)),
      );

  Map<String, dynamic> toJson() => {
        'kind': kind,
        if (series.isNotEmpty)
          'series': series.map((s) => s.toJson()).toList(),
        if (title != null) 'title': title,
        if (xAxis != null) 'xAxis': xAxis!.toJson(),
        if (yAxis != null) 'yAxis': yAxis!.toJson(),
        'legend': legend,
        'animated': animated,
        ...extra,
      };
}

class ChartSeriesSpec {
  const ChartSeriesSpec({
    required this.name,
    required this.data,
    this.color,
  });

  final String name;
  final List<dynamic> data;
  final String? color;

  factory ChartSeriesSpec.fromJson(Map<String, dynamic> j) => ChartSeriesSpec(
        name: j['name'] as String? ?? '',
        data: j['data'] as List<dynamic>? ?? [],
        color: j['color'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'data': data,
        if (color != null) 'color': color,
      };
}

class ChartAxisSpec {
  const ChartAxisSpec({this.label, this.categories = const []});

  final String? label;
  final List<String> categories;

  factory ChartAxisSpec.fromJson(Map<String, dynamic> j) => ChartAxisSpec(
        label: j['label'] as String?,
        categories: List<String>.from(j['categories'] as List? ?? []),
      );

  Map<String, dynamic> toJson() => {
        if (label != null) 'label': label,
        if (categories.isNotEmpty) 'categories': categories,
      };
}

// ─────────────────────────────────────────────
// 2. UINode subtype
// ─────────────────────────────────────────────

/// UINode for Tenun-powered charts.
///
/// Produced when the agent generates `"type": "tenun_chart"`.
class TenunChartNode extends UINode with _NodeJsonBase {
  TenunChartNode({
    super.id,
    super.style,
    super.actions,
    super.condition,
    required this.spec,
    this.dataSourceId,
  }) : super(type: 'tenun_chart', children: const []);

  final ChartSpec spec;

  /// If set, data is fetched from [DataSourceRegistry] instead of [spec.series].
  final String? dataSourceId;

  factory TenunChartNode.fromJson(Map<String, dynamic> j) => TenunChartNode(
        id: j['id'] as String?,
        style: _parseStyle(j),
        actions: _parseActions(j),
        condition: j['condition'] as String?,
        spec: ChartSpec.fromJson(
            j['spec'] as Map<String, dynamic>? ?? const {'kind': 'bar'}),
        dataSourceId: j['source'] as String?,
      );

  @override
  Map<String, dynamic> toJson() => {
        ..._baseJson(),
        'spec': spec.toJson(),
        if (dataSourceId != null) 'source': dataSourceId,
      };
}

// ─────────────────────────────────────────────
// 3. Renderer
// ─────────────────────────────────────────────

/// Renders a Tenun chart from a [TenunChartNode].
///
/// When the tenun package is available, this is replaced by a real
/// Tenun renderer. Until then it shows an informative placeholder.
class TenunChartRenderer extends StatelessWidget {
  const TenunChartRenderer({
    super.key,
    required this.node,
    this.data,
  });

  final TenunChartNode node;
  final dynamic data; // resolved from DataSource if any

  @override
  Widget build(BuildContext context) {
    // TODO(patch-032): replace stub with real Tenun widget once
    // `package:tenun` is added to pubspec.yaml.
    return _TenunPlaceholder(spec: node.spec);
  }
}

class _TenunPlaceholder extends StatelessWidget {
  const _TenunPlaceholder({required this.spec});
  final ChartSpec spec;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bar_chart_rounded,
              size: 48, color: theme.colorScheme.primary),
          const SizedBox(height: 8),
          Text(
            '${spec.kind.toUpperCase()} chart',
            style: theme.textTheme.titleMedium,
          ),
          if (spec.title != null)
            Text(spec.title!, style: theme.textTheme.bodySmall),
          const SizedBox(height: 4),
          Text(
            'Add package:tenun to render this chart',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// 4. TenunPlugin
// ─────────────────────────────────────────────

/// Batik plugin that wires Tenun chart rendering.
///
/// ```dart
/// await BatikRuntime.instance.loadPlugin(TenunPlugin());
/// await BatikRuntime.instance.initialize();
/// ```
class TenunPlugin extends BatikPlugin {
  const TenunPlugin();

  @override
  PluginManifest get manifest => const PluginManifest(
        id: 'batik_tenun',
        version: '0.1.0',
        capabilities: [PluginCapability.chart],
        description: 'Delegates chart rendering to the Tenun chart engine.',
      );

  @override
  Future<void> initialize(BatikRuntime runtime) async {
    // Register the UINode type into the JSON parse registry.
    UINode.registerExternal(
        'tenun_chart', (j) => TenunChartNode.fromJson(j));
  }

  @override
  void registerNodes(UIComponentRegistry registry) {
    registry.register<TenunChartNode>((context, node, renderer) {
      return TenunChartRenderer(node: node);
    });
  }

  @override
  void registerDataSources(DataSourceRegistry registry) {}
  @override
  void registerActions(ActionRegistry registry) {}
  @override
  void registerThemes(ThemeRegistry registry) {}

  @override
  Map<String, dynamic> get schemaExtensions => const {
        'tenun_chart': {
          'type': 'tenun_chart',
          'spec': {'kind': 'string', 'series': 'array'},
        }
      };

  @override
  String get systemPromptSection => '''
TenunChartNode: {
  "type": "tenun_chart",
  "spec": {
    "kind": "bar|line|pie|area|scatter|radar",
    "title": "optional title",
    "series": [{"name": "A", "data": [1, 2, 3]}],
    "xAxis": {"label": "Month", "categories": ["Jan","Feb","Mar"]},
    "yAxis": {"label": "Value"}
  },
  "source": "optional_datasource_id"
}''';
}

// ── private helpers mirroring ui_schema.dart internals ────────
UIStyle? _parseStyle(Map<String, dynamic> j) {
  final s = j['style'] as Map<String, dynamic>?;
  return s == null ? null : UIStyle.fromJson(s);
}

Map<String, UIAction> _parseActions(Map<String, dynamic> j) {
  final raw = j['actions'] as Map<String, dynamic>?;
  if (raw == null) return const {};
  return raw
      .map((k, v) => MapEntry(k, UIAction.fromJson(v as Map<String, dynamic>)));
}

mixin _NodeJsonBase on UINode {
  Map<String, dynamic> _baseJson() => {
        'type': type,
        if (id != null) 'id': id,
        if (style != null) 'style': style!.toJson(),
        if (actions.isNotEmpty)
          'actions': actions.map((k, v) => MapEntry(k, v.toJson())),
        if (condition != null) 'condition': condition,
      };
}
