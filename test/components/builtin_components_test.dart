import 'package:batik/batik.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() async {
    await AgentUIKit.initialize();
  });

  testWidgets('AgentUIRenderer renders built-in text and button nodes', (
    tester,
  ) async {
    final response = AgentUIResponse(
      schemaVersion: '2.0.0',
      root: ColumnNode(
        children: [
          TextNode(text: 'Batik ready'),
          ButtonNode(label: 'Submit'),
        ],
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: AgentUIRenderer(
              response: response,
              actionHandler: const LoggingActionHandler(),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Batik ready'), findsOneWidget);
    expect(find.text('Submit'), findsOneWidget);
  });
}
