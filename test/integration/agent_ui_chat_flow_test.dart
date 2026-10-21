import 'package:batik/batik.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() async {
    await AgentUIKit.initialize();
  });

  testWidgets('AgentUIChat sends a message and renders the returned UI', (
    tester,
  ) async {
    final adapter = MockAdapter(
      delay: Duration.zero,
      responseFactory: (input) => AgentUIResponse(
        schemaVersion: '2.0.0',
        root: ColumnNode(
          children: [
            TextNode(text: 'Echo'),
            TextNode(text: input.userMessage),
          ],
        ),
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: AgentUIChat(
              config: AgentSessionConfig(
                sessionId: 'integration-session',
                adapter: adapter,
              ),
              actionHandler: const LoggingActionHandler(),
              useStreaming: false,
            ),
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'Build approval flow');
    await tester.tap(find.byKey(const ValueKey('send')));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Build approval flow'), findsWidgets);
    expect(find.text('Echo'), findsOneWidget);
  });
}
