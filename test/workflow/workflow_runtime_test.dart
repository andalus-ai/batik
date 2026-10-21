import 'package:batik/batik.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Workflow Runtime (Patch 035)', () {
    test('executes a sequential workflow and collects node outputs', () async {
      final graph = WorkflowGraph(
        nodes: [
          const WorkflowNode(id: 'start', nodeType: WorkflowNodeType.start),
          const WorkflowNode(
            id: 'fetch_user',
            nodeType: WorkflowNodeType.task,
            label: 'Fetch user',
          ),
          const WorkflowNode(id: 'end', nodeType: WorkflowNodeType.end),
        ],
        edges: const [
          WorkflowEdge(from: 'start', to: 'fetch_user'),
          WorkflowEdge(from: 'fetch_user', to: 'end'),
        ],
      );

      final executor = WorkflowExecutor(
        taskHandler: (node, ctx) async {
          if (node.id == 'fetch_user') {
            return {'user': 'kayys'};
          }
          return {};
        },
      );

      final result = await executor.execute(graph);

      expect(result.completed, isTrue);
      expect(result.isOk, isTrue);
      expect(result.executedNodes, ['start', 'fetch_user', 'end']);
      expect(result.outputs['fetch_user'], {'user': 'kayys'});
      expect(result.outputs['user'], 'kayys');
    });

    test('evaluates condition branching', () async {
      final graph = WorkflowGraph(
        nodes: [
          const WorkflowNode(id: 'start', nodeType: WorkflowNodeType.start),
          const WorkflowNode(
            id: 'check_role',
            nodeType: WorkflowNodeType.condition,
            config: {'expr': 'isAdmin'},
          ),
          const WorkflowNode(id: 'admin_panel', nodeType: WorkflowNodeType.end),
          const WorkflowNode(id: 'guest_panel', nodeType: WorkflowNodeType.end),
        ],
        edges: const [
          WorkflowEdge(from: 'start', to: 'check_role'),
          WorkflowEdge(from: 'check_role', to: 'admin_panel', label: 'yes'),
          WorkflowEdge(from: 'check_role', to: 'guest_panel', label: 'no'),
        ],
      );

      final executor = WorkflowExecutor(
        conditionEvaluator: (expr, ctx) => ctx.get(expr) == true,
      );

      // Branch 1: isAdmin = true
      final adminResult = await executor.execute(graph, initialVars: {'isAdmin': true});
      expect(adminResult.completed, isTrue);
      expect(adminResult.executedNodes, ['start', 'check_role', 'admin_panel']);

      // Branch 2: isAdmin = false
      final guestResult = await executor.execute(graph, initialVars: {'isAdmin': false});
      expect(guestResult.completed, isTrue);
      expect(guestResult.executedNodes, ['start', 'check_role', 'guest_panel']);
    });
  });
}
