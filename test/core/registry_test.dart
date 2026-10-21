import 'package:batik/batik.dart';
import 'package:flutter/material.dart' hide ActionDispatcher;
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UIComponentRegistry', () {
    test('supports custom registration lookup and removal', () {
      final registry = UIComponentRegistry.instance;
      registry.unregister<CustomNode>();
      registry.unregisterCustom('test-banner');

      registry.registerCustom(
        'test-banner',
        (context, node, renderer) => Text(node.componentId),
      );

      final builder = registry.builderFor(
        CustomNode(componentId: 'test-banner', props: const {}),
      );

      expect(builder, isNotNull);
      expect(registry.isCustomRegistered('test-banner'), isTrue);

      registry.unregisterCustom('test-banner');
      expect(registry.isCustomRegistered('test-banner'), isFalse);
    });
  });

  group('VariableStore and dispatcher', () {
    testWidgets(
      'setVariable actions update the store before handler execution',
      (tester) async {
        final store = VariableStore();
        final handler = _RecordingActionHandler();
        final dispatcher = ActionDispatcher(
          handler: handler,
          variableStore: store,
        );

        await tester.pumpWidget(const MaterialApp(home: SizedBox()));
        final context = tester.element(find.byType(SizedBox));

        await dispatcher.dispatch(
          context,
          const UIAction(
            type: ActionTypes.setVariable,
            payload: {'key': 'status', 'value': 'ready'},
          ),
        );

        expect(store.get<String>('status'), 'ready');
        expect(handler.handledActions, isEmpty);
      },
    );

    testWidgets('non-framework actions are forwarded to the handler', (
      tester,
    ) async {
      final store = VariableStore()..set('user', 'Alya');
      final handler = _RecordingActionHandler();
      final dispatcher = ActionDispatcher(
        handler: handler,
        variableStore: store,
      );

      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      final context = tester.element(find.byType(SizedBox));

      await dispatcher.dispatch(
        context,
        const UIAction(
          type: ActionTypes.agentMessage,
          payload: {'message': 'hello'},
        ),
      );

      expect(handler.handledActions.single.type, ActionTypes.agentMessage);
      expect(handler.lastVariables['user'], 'Alya');
    });
  });
}

class _RecordingActionHandler implements ActionHandler {
  final handledActions = <UIAction>[];
  Map<String, dynamic> lastVariables = const {};

  @override
  Future<void> handle(
    BuildContext context,
    UIAction action,
    Map<String, dynamic> variables,
  ) async {
    handledActions.add(action);
    lastVariables = variables;
  }
}
