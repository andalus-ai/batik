import 'package:batik/batik.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Batik Plugin API v2 & Runtime', () {
    test('BatikRuntime registers and initializes plugins in dependency order', () async {
      final runtime = BatikRuntime.instance;
      final tenun = const TenunPlugin();
      final diagram = const DiagramPlugin();

      runtime.loadPlugin(tenun);
      runtime.loadPlugin(diagram);
      await runtime.initialize();

      expect(runtime.hasPlugin('batik_tenun'), isTrue);
      expect(runtime.hasPlugin('batik_diagram'), isTrue);
      expect(runtime.pluginsWithCapability(PluginCapability.chart).length, 1);
      expect(runtime.pluginsWithCapability(PluginCapability.diagram).length, 1);
      expect(runtime.pluginSystemPrompt.contains('TenunChartNode'), isTrue);
      expect(runtime.pluginSystemPrompt.contains('DiagramNode'), isTrue);
    });
  });

  group('Runtime Graph (Patch 030)', () {
    test('constructs nodes and edges and allows querying successors/predecessors', () {
      final graph = RuntimeGraph();

      final dsNode = DataSourceRuntimeNode(
        id: 'sales_ds',
        label: 'Sales API',
        sourceType: 'rest',
      );
      final chartNode = ChartRuntimeNode(
        id: 'chart_1',
        label: 'Monthly Revenue',
        chartType: 'bar',
        dataSourceId: 'sales_ds',
      );

      graph.addNode(dsNode);
      graph.addNode(chartNode);
      graph.addEdge(const RuntimeEdge(
        source: 'sales_ds',
        target: 'chart_1',
        type: 'data',
      ));

      expect(graph.nodes.length, 2);
      expect(graph.edges.length, 1);
      expect(graph.nodeById<ChartRuntimeNode>('chart_1')?.chartType, 'bar');
      expect(graph.successors('sales_ds').first.id, 'chart_1');
      expect(graph.predecessors('chart_1').first.id, 'sales_ds');
    });

    test('validates edge targets exist', () {
      final graph = RuntimeGraph();
      graph.addNode(WidgetRuntimeNode(id: 'w1'));

      expect(
        () => graph.addEdge(const RuntimeEdge(source: 'w1', target: 'unknown')),
        throwsArgumentError,
      );
    });
  });
}
