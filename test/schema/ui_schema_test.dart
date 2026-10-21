import 'package:batik/batik.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() async {
    await AgentUIKit.initialize();
  });

  group('UI schema serialization', () {
    test('TextNode round-trips through JSON', () {
      final node = TextNode(
        text: 'Hello world',
        variant: 'titleMedium',
        id: 'greeting',
      );

      final decoded = UINode.fromJson(node.toJson()) as TextNode;

      expect(decoded.text, 'Hello world');
      expect(decoded.variant, 'titleMedium');
      expect(decoded.id, 'greeting');
    });

    test('ButtonNode preserves actions', () {
      final node = ButtonNode(
        label: 'Continue',
        actions: {
          'onTap': const UIAction(
            type: ActionTypes.navigate,
            payload: {'route': '/next'},
          ),
        },
      );

      final json = node.toJson();

      expect(json['type'], 'button');
      expect((json['actions'] as Map<String, dynamic>)['onTap'], isNotNull);
    });

    test('AgentUIResponse serializes and deserializes', () {
      final response = AgentUIResponse(
        schemaVersion: '2.0.0',
        sessionId: 'session-7',
        metadata: const {'turn': 2},
        root: ColumnNode(
          children: [
            TextNode(text: 'Summary'),
            TextNode(text: 'Ready'),
          ],
        ),
      );

      final restored = AgentUIResponse.fromJson(response.toJson());

      expect(restored.schemaVersion, '2.0.0');
      expect(restored.sessionId, 'session-7');
      expect(restored.metadata['turn'], 2);
      expect(restored.root, isA<ColumnNode>());
    });

    test('unknown node types become UnknownNode', () {
      final node = UINode.fromJson(const {
        'type': 'experimentalWidget',
        'foo': 'bar',
      });

      expect(node, isA<UnknownNode>());
    });
  });
}
