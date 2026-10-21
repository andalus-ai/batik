// lib/src/orchestration/multi_agent_orchestrator.dart
//
// AgentUIKit v2 — Multi-Agent Orchestration
// ============================================================
// Routes requests to specialized agents and merges their
// responses into a unified UI tree.
//
// Patterns supported:
//  • Router  — intent classifier routes to best-fit agent
//  • Pipeline — sequential chain (agent A → agent B → UI)
//  • Parallel — concurrent calls, merge results
//  • Fallback — try primary, fall back on error/timeout
//  • Race     — fire all, use first to respond
// ============================================================

import 'dart:async';
import 'dart:convert' show jsonDecode;
import 'package:logging/logging.dart';

import '../adapters/agent_adapter.dart';
import '../schema/ui_schema.dart';

final _log = Logger('AgentUIKit.Orchestrator');

// ─────────────────────────────────────────────
// Agent registration
// ─────────────────────────────────────────────

class RegisteredAgent {
  const RegisteredAgent({
    required this.id,
    required this.adapter,
    required this.description,
    this.capabilities = const [],
    this.priority = 0,
    this.timeoutMs = 30000,
  });

  final String id;
  final AgentAdapter adapter;
  final String description;
  final List<String> capabilities; // e.g. ['search', 'calendar', 'payments']
  final int priority; // higher = preferred on tie
  final int timeoutMs;
}

// ─────────────────────────────────────────────
// Intent routing
// ─────────────────────────────────────────────

/// Determines which agent(s) should handle a given input.
abstract class IntentRouter {
  /// Returns ordered list of agent IDs to try.
  Future<List<String>> route(
      AgentTurnInput input, List<RegisteredAgent> agents);
}

/// Simple keyword-based router (no LLM call needed).
class KeywordIntentRouter implements IntentRouter {
  const KeywordIntentRouter(this.rules);

  /// Map of keyword → agent ID.
  final Map<String, String> rules;

  @override
  Future<List<String>> route(
      AgentTurnInput input, List<RegisteredAgent> agents) async {
    final msg = input.userMessage.toLowerCase();
    final scored = <String, int>{};

    for (final entry in rules.entries) {
      if (msg.contains(entry.key.toLowerCase())) {
        scored[entry.value] = (scored[entry.value] ?? 0) + 1;
      }
    }

    if (scored.isEmpty) {
      // Return all agents sorted by priority
      final sorted = List<RegisteredAgent>.from(agents)
        ..sort((a, b) => b.priority.compareTo(a.priority));
      return sorted.map((a) => a.id).toList();
    }

    return scored.entries.map((entry) => entry.key).toList();
  }
}

/// LLM-powered router — calls a lightweight model to classify intent.
class LLMIntentRouter implements IntentRouter {
  LLMIntentRouter({required this.routerAdapter, this.systemPrompt});

  final AgentAdapter routerAdapter;
  final String? systemPrompt;

  @override
  Future<List<String>> route(
      AgentTurnInput input, List<RegisteredAgent> agents) async {
    final agentList =
        agents.map((a) => '• ${a.id}: ${a.description}').join('\n');

    final prompt = '''
Available agents:
$agentList

User message: "${input.userMessage}"

Respond with ONLY a JSON array of agent IDs in priority order.
Example: ["search_agent", "calendar_agent"]
''';

    try {
      final result = await routerAdapter.sendTurn(
        AgentTurnInput(userMessage: prompt),
      );
      final text = result.textResponse ?? '';
      final match = RegExp(r'\[.*?\]', dotAll: true).firstMatch(text);
      if (match != null) {
        final ids = (List<dynamic>.from(
          jsonDecode(match.group(0)!) as List,
        )).cast<String>();
        return ids;
      }
    } catch (e) {
      _log.warning('LLMIntentRouter failed: $e');
    }

    // Fallback: all agents by priority
    final sorted = List<RegisteredAgent>.from(agents)
      ..sort((a, b) => b.priority.compareTo(a.priority));
    return sorted.map((a) => a.id).toList();
  }
}

// ─────────────────────────────────────────────
// Response merger
// ─────────────────────────────────────────────

/// Merges multiple agent UI responses into one tree.
abstract class ResponseMerger {
  AgentUIResponse merge(List<AgentTurnOutput> outputs);
}

/// Stacks responses vertically in a column.
class VerticalMerger implements ResponseMerger {
  const VerticalMerger();

  @override
  AgentUIResponse merge(List<AgentTurnOutput> outputs) {
    final children = <UINode>[];

    for (final output in outputs) {
      if (output.uiResponse != null) {
        children.add(output.uiResponse!.root);
        children.add(DividerNode());
      } else if (output.textResponse != null) {
        children.add(TextNode(text: output.textResponse!));
      }
    }

    return AgentUIResponse(
      schemaVersion: '2.0.0',
      root: ColumnNode(
        style: const UIStyle(padding: UIInsets(all: 8)),
        children: children,
      ),
    );
  }
}

/// Uses the first successful response.
class FirstSuccessfulMerger implements ResponseMerger {
  const FirstSuccessfulMerger();

  @override
  AgentUIResponse merge(List<AgentTurnOutput> outputs) {
    for (final output in outputs) {
      if (!output.hasError && output.uiResponse != null) {
        return output.uiResponse!;
      }
    }
    return AgentUIResponse(
      schemaVersion: '2.0.0',
      root: TextNode(text: 'No agent could handle this request.'),
    );
  }
}

// ─────────────────────────────────────────────
// Orchestrator
// ─────────────────────────────────────────────

class MultiAgentOrchestrator extends AgentAdapter {
  MultiAgentOrchestrator({
    required this.agents,
    required this.router,
    this.merger = const FirstSuccessfulMerger(),
    this.strategy = OrchestratorStrategy.router,
    this.maxParallel = 3,
    this.globalTimeoutMs = 45000,
  }) : assert(agents.isNotEmpty, 'At least one agent required');

  final List<RegisteredAgent> agents;
  final IntentRouter router;
  final ResponseMerger merger;
  final OrchestratorStrategy strategy;
  final int maxParallel;
  final int globalTimeoutMs;

  final _agentMap = <String, RegisteredAgent>{};

  void _init() {
    if (_agentMap.isEmpty) {
      for (final a in agents) {
        _agentMap[a.id] = a;
      }
    }
  }

  @override
  Future<AgentTurnOutput> sendTurn(AgentTurnInput input) async {
    _init();
    try {
      return await _dispatch(input).timeout(
        Duration(milliseconds: globalTimeoutMs),
        onTimeout: () => AgentTurnOutput(
          error: TimeoutException(
              'Orchestrator timed out after ${globalTimeoutMs}ms'),
        ),
      );
    } catch (e) {
      return AgentTurnOutput(error: e);
    }
  }

  Future<AgentTurnOutput> _dispatch(AgentTurnInput input) async {
    switch (strategy) {
      case OrchestratorStrategy.router:
        return _routerStrategy(input);
      case OrchestratorStrategy.parallel:
        return _parallelStrategy(input);
      case OrchestratorStrategy.race:
        return _raceStrategy(input);
      case OrchestratorStrategy.pipeline:
        return _pipelineStrategy(input);
      case OrchestratorStrategy.fallback:
        return _fallbackStrategy(input);
    }
  }

  // ── Router: route → call best agent ──────────

  Future<AgentTurnOutput> _routerStrategy(AgentTurnInput input) async {
    final agentIds = await router.route(input, agents);
    _log.info('Router selected: $agentIds');

    for (final id in agentIds) {
      final agent = _agentMap[id];
      if (agent == null) continue;

      try {
        final result = await agent.adapter
            .sendTurn(input)
            .timeout(Duration(milliseconds: agent.timeoutMs));

        if (!result.hasError) {
          _log.info('Handled by agent: $id');
          return result;
        }
        _log.warning('Agent $id failed: ${result.error}');
      } catch (e) {
        _log.warning('Agent $id threw: $e');
      }
    }

    return AgentTurnOutput(
      error: Exception('All routed agents failed for: "${input.userMessage}"'),
    );
  }

  // ── Parallel: call all, merge ─────────────────

  Future<AgentTurnOutput> _parallelStrategy(AgentTurnInput input) async {
    final targets = agents.take(maxParallel).toList();
    _log.info('Parallel: calling ${targets.length} agents');

    final futures = targets.map((a) async {
      try {
        return await a.adapter
            .sendTurn(input)
            .timeout(Duration(milliseconds: a.timeoutMs));
      } catch (e) {
        return AgentTurnOutput(error: e);
      }
    });

    final results = await Future.wait(futures);
    final merged = merger.merge(results);
    return AgentTurnOutput(uiResponse: merged);
  }

  // ── Race: first to complete wins ──────────────

  Future<AgentTurnOutput> _raceStrategy(AgentTurnInput input) async {
    _log.info('Race: ${agents.length} agents competing');

    final completer = Completer<AgentTurnOutput>();

    for (final agent in agents) {
      agent.adapter
          .sendTurn(input)
          .timeout(Duration(milliseconds: agent.timeoutMs))
          .then((result) {
        if (!result.hasError && !completer.isCompleted) {
          _log.info('Race won by: ${agent.id}');
          completer.complete(result);
        }
      }).catchError((_) {});
    }

    // Fallback if no one wins
    Future.delayed(Duration(milliseconds: globalTimeoutMs), () {
      if (!completer.isCompleted) {
        completer.complete(
          AgentTurnOutput(error: TimeoutException('Race timed out')),
        );
      }
    });

    return completer.future;
  }

  // ── Pipeline: sequential, each sees previous ─

  Future<AgentTurnOutput> _pipelineStrategy(AgentTurnInput input) async {
    _log.info('Pipeline: ${agents.length} stages');
    AgentTurnOutput? last;

    var currentInput = input;
    for (final agent in agents) {
      try {
        last = await agent.adapter
            .sendTurn(currentInput)
            .timeout(Duration(milliseconds: agent.timeoutMs));

        if (last.hasError) {
          _log.warning('Pipeline stage ${agent.id} failed: ${last.error}');
          break;
        }

        // Pass result as context to next agent
        currentInput = AgentTurnInput(
          userMessage: currentInput.userMessage,
          history: [
            ...currentInput.history,
            if (last.textResponse != null)
              AgentMessage(role: 'assistant', content: last.textResponse!),
          ],
          variables: currentInput.variables,
          metadata: {
            ...currentInput.metadata,
            'previousStage': agent.id,
            'previousResult': last.uiResponse?.toJson(),
          },
        );
      } catch (e) {
        _log.warning('Pipeline stage ${agent.id} threw: $e');
      }
    }

    return last ??
        AgentTurnOutput(error: Exception('Pipeline produced no output'));
  }

  // ── Fallback: primary, then secondary ────────

  Future<AgentTurnOutput> _fallbackStrategy(AgentTurnInput input) async {
    for (final agent in agents) {
      _log.info('Fallback: trying ${agent.id}');
      try {
        final result = await agent.adapter
            .sendTurn(input)
            .timeout(Duration(milliseconds: agent.timeoutMs));
        if (!result.hasError) return result;
      } catch (e) {
        _log.warning('Fallback: ${agent.id} failed: $e');
      }
    }
    return AgentTurnOutput(
      error: Exception('All fallback agents exhausted'),
    );
  }

  @override
  AgentUIResponse? parseResponse(dynamic raw) => null;

  @override
  Stream<AgentStreamEvent> streamTurn(AgentTurnInput input) async* {
    // Streaming orchestration — route to first available streaming agent
    _init();
    final agentIds = await router.route(input, agents);
    for (final id in agentIds) {
      final agent = _agentMap[id];
      if (agent == null) continue;
      try {
        yield* agent.adapter.streamTurn(input);
        return;
      } catch (e) {
        _log.warning('Streaming agent $id failed: $e');
      }
    }
    yield AgentStreamError(Exception('No streaming agent available'));
  }
}

enum OrchestratorStrategy {
  router, // route to best-fit agent
  parallel, // call all, merge
  race, // first to respond wins
  pipeline, // sequential chain
  fallback, // try in order
}
