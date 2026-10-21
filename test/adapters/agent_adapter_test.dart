import 'package:batik/batik.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Agent adapter primitives', () {
    test('AgentTurnInput keeps optional context', () {
      const input = AgentTurnInput(
        userMessage: 'hello',
        history: [AgentMessage(role: 'user', content: 'before')],
        variables: {'count': 1},
        metadata: {'source': 'test'},
        sessionId: 'session-1',
      );

      expect(input.userMessage, 'hello');
      expect(input.history.single.content, 'before');
      expect(input.variables['count'], 1);
      expect(input.metadata['source'], 'test');
      expect(input.sessionId, 'session-1');
    });

    test('MockAdapter returns the default card response', () async {
      final adapter = MockAdapter(delay: Duration.zero);
      final output = await adapter.sendTurn(
        const AgentTurnInput(userMessage: 'build a card'),
      );

      expect(output.hasError, isFalse);
      expect(output.hasUI, isTrue);
      expect(output.uiResponse?.root, isA<CardNode>());
    });

    test('MockAdapter supports responseFactory overrides', () async {
      final expected = AgentUIResponse(
        schemaVersion: '2.0.0',
        root: TextNode(text: 'Custom response'),
      );
      final adapter = MockAdapter(
        delay: Duration.zero,
        responseFactory: (_) => expected,
      );

      final output = await adapter.sendTurn(
        const AgentTurnInput(userMessage: 'custom'),
      );

      expect(output.uiResponse, same(expected));
    });
  });

  group('UISystemPromptBuilder', () {
    test('includes app context and allowed components', () {
      final prompt = UISystemPromptBuilder.build(
        appContext: 'Procurement app',
        schemaVersion: '2.0.0',
        allowedComponents: const ['text', 'button'],
      );

      expect(prompt, contains('Procurement app'));
      expect(prompt, contains('schema v2.0.0'));
      expect(prompt, contains('text'));
      expect(prompt, contains('button'));
    });
  });
}
