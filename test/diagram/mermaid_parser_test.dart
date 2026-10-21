import 'package:batik/batik.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('imports a Mermaid left-to-right flowchart', () {
    final graph = const MermaidParser().parse('''
flowchart LR
  A[Start] -->|valid| B{Validate}
  B --> C[Done]
''');

    expect(graph.direction, DiagramDirection.leftToRight);
    expect(
        graph.nodes.map((node) => node.label), ['Start', 'Validate', 'Done']);
    expect(graph.edges.first.label, 'valid');
    expect(graph.edges.length, 2);
    expect(graph.nodes[1].shape, DiagramShape.diamond);
  });

  test('rejects unsupported Mermaid syntax', () {
    expect(
      () => const MermaidParser().parse('sequenceDiagram\nA->>B: hello'),
      throwsA(isA<FormatException>()),
    );
  });

  test('rejects edges that reference unknown JSON nodes', () {
    expect(
      () => DiagramGraph.fromJson({
        'nodes': [
          {'id': 'A', 'label': 'A'},
        ],
        'edges': [
          {'from': 'A', 'to': 'B'},
        ],
      }),
      throwsA(isA<FormatException>()),
    );
  });
}
