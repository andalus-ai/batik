import 'package:batik/batik.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Design Tokens & Tenun Theme Adapter', () {
    test('BatikSpacing and BatikRadius define consistent scale', () {
      expect(BatikSpacing.sm, 8.0);
      expect(BatikSpacing.md, 12.0);
      expect(BatikSpacing.lg, 16.0);
      expect(BatikRadius.md, 12.0);
    });

    test('TenunThemeAdapter maps light and dark theme palettes', () {
      final light = TenunThemeAdapter.fromTheme(BatikTheme.light);
      final dark = TenunThemeAdapter.fromTheme(BatikTheme.dark);

      expect(light.palette.isNotEmpty, isTrue);
      expect(dark.palette.isNotEmpty, isTrue);

      final spec = light.toChartThemeSpec();
      expect(spec['palette'], isA<List>());
      expect(spec['backgroundColor'], isA<String>());
    });
  });

  group('Component Composition Engine (Patch 048)', () {
    testWidgets('CustomerCard renders correctly with props', (tester) async {
      final comp = const CustomerCardComponent();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => comp.build(BatikComponentContext(
                props: const {
                  'name': 'Jane Doe',
                  'role': 'Lead Architect',
                  'status': 'Active',
                  'email': 'jane@example.com',
                },
                context: ctx,
                renderer: const _TestNodeRenderer(),
              )),
            ),
          ),
        ),
      );

      expect(find.text('Jane Doe'), findsOneWidget);
      expect(find.text('Lead Architect'), findsOneWidget);
      expect(find.text('Active'), findsOneWidget);
      expect(find.text('jane@example.com'), findsOneWidget);
    });

    testWidgets('MetricsCard renders label, value and delta', (tester) async {
      final comp = const MetricsCardComponent();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => comp.build(BatikComponentContext(
                props: const {
                  'label': 'Total Revenue',
                  'value': '\$48,500',
                  'delta': '+18%',
                  'positive': true,
                },
                context: ctx,
                renderer: const _TestNodeRenderer(),
              )),
            ),
          ),
        ),
      );

      expect(find.text('Total Revenue'), findsOneWidget);
      expect(find.text('\$48,500'), findsOneWidget);
      expect(find.text('+18%'), findsOneWidget);
      expect(find.byIcon(Icons.trending_up), findsOneWidget);
    });

    test('ComponentNode serializes and deserializes', () {
      final json = {
        'type': 'component',
        'component': 'CustomerCard',
        'props': {'name': 'Alice'},
      };
      final node = ComponentNode.fromJson(json);
      expect(node.componentName, 'CustomerCard');
      expect(node.props['name'], 'Alice');
      expect(node.toJson()['component'], 'CustomerCard');
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
