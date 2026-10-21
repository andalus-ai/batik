import 'package:batik/batik.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Shape Engine (Patch 034 / Section 4)', () {
    test('ShapeNode deserializes circle, polygon, and rect', () {
      final circle = ShapeNode.fromJson({
        'type': 'shape',
        'shape': 'circle',
        'radius': 30.0,
        'fill': '#FF0000',
      });
      expect(circle.shapeType, ShapeType.circle);
      expect(circle.radius, 30.0);

      final poly = ShapeNode.fromJson({
        'type': 'shape',
        'shape': 'polygon',
        'points': [{'x': 0, 'y': 0}, {'x': 10, 'y': 20}],
      });
      expect(poly.shapeType, ShapeType.polygon);
      expect(poly.points.length, 2);
      expect(poly.points[1].y, 20.0);
    });

    testWidgets('ShapeRendererWidget pumps without error', (tester) async {
      final node = ShapeNode(
        shapeType: ShapeType.rect,
        width: 80,
        height: 40,
        fillColor: '#E2B062',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ShapeRendererWidget(node: node),
          ),
        ),
      );
      expect(find.byType(ShapeRendererWidget), findsOneWidget);
    });
  });

  group('Runtime Templates (Patch 049)', () {
    test('TemplateNode deserializes dashboard and crm specs', () {
      final dash = TemplateNode.fromJson({
        'type': 'template',
        'template': 'dashboard',
        'title': 'KPI Overview',
        'metrics': [{'label': 'Users', 'value': '10k'}],
      });
      expect(dash.templateName, 'dashboard');
      expect(dash.title, 'KPI Overview');
      expect(dash.data['metrics'], isA<List>());
    });

    testWidgets('DashboardTemplate renders title and metrics', (tester) async {
      final node = TemplateNode(
        templateName: 'dashboard',
        title: 'Sales Dashboard',
        data: const {
          'metrics': [
            {'label': 'MRR', 'value': '\$12,000'},
          ],
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => const DashboardTemplate().build(
                ctx,
                node,
                const _TestNodeRenderer(),
              ),
            ),
          ),
        ),
      );
      expect(find.text('Sales Dashboard'), findsOneWidget);
      expect(find.text('MRR'), findsOneWidget);
      expect(find.text('\$12,000'), findsOneWidget);
    });
  });

  group('Live Document Runtime (Patch 036)', () {
    test('DocumentNode parses heading, paragraph, and code blocks', () {
      final doc = DocumentNode.fromJson({
        'type': 'document',
        'title': 'Sprint Review',
        'blocks': [
          {'type': 'heading', 'level': 1, 'text': 'Goals'},
          {'type': 'paragraph', 'text': 'Completed all sprint backlog items.'},
          {'type': 'code', 'language': 'dart', 'code': 'void main() {}'},
        ],
      });
      expect(doc.title, 'Sprint Review');
      expect(doc.blocks.length, 3);
      expect(doc.blocks[0], isA<HeadingBlock>());
      expect((doc.blocks[0] as HeadingBlock).text, 'Goals');
      expect(doc.blocks[2], isA<CodeBlock>());
    });
  });

  group('Agent Workspace Runtime (Patch 039)', () {
    testWidgets('WorkspaceRendererWidget switches active tab', (tester) async {
      final ws = WorkspaceNode(
        panes: const [
          ChatWorkspacePane(title: 'Chat Pane'),
          DocumentWorkspacePane(title: 'Doc Pane', content: 'Doc content body'),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WorkspaceRendererWidget(node: ws),
          ),
        ),
      );

      expect(find.text('Chat Pane'), findsOneWidget);
      expect(find.text('Doc Pane'), findsOneWidget);
      expect(find.text('Agent Chat Active Session'), findsOneWidget);

      // Tap on second tab
      await tester.tap(find.text('Doc Pane'));
      await tester.pumpAndSettle();

      expect(find.text('Doc content body'), findsOneWidget);
    });
  });
}

class _TestNodeRenderer implements NodeRenderer {
  const _TestNodeRenderer();

  @override
  Widget render(BuildContext context, UINode node) => const SizedBox.shrink();

  @override
  List<Widget> renderChildren(BuildContext context, List<UINode> children) => const [];
}
