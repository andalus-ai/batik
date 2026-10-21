import 'package:batik/batik.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AgentUIKit.initialize is safe to call multiple times', () async {
    await AgentUIKit.initialize();
    await AgentUIKit.initialize();

    expect(UIComponentRegistry.instance.isRegistered<TextNode>(), isTrue);
    expect(UIComponentRegistry.instance.isRegistered<ButtonNode>(), isTrue);
  });
}
