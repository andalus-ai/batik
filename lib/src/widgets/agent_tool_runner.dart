// lib/src/tools/agent_tool_runner.dart
//
// AgentUIKit v2 — Agent Tool-Use Loop
// ============================================================
// Implements the agentic loop where the LLM can call tools
// (functions), receive results, reason further, and eventually
// produce a UI response — all transparently.
//
// Supports both:
//  • Anthropic tool_use blocks
//  • OpenAI function_calling / tool_calls
// ============================================================

import 'dart:async';
import 'dart:convert';
import 'package:logging/logging.dart';
import 'package:http/http.dart' as http;
import '../adapters/agent_adapter.dart';
import '../schema/ui_schema.dart';

final _log = Logger('AgentUIKit.ToolRunner');

// ─────────────────────────────────────────────
// Tool definition
// ─────────────────────────────────────────────

class AgentTool {
  const AgentTool({
    required this.name,
    required this.description,
    required this.inputSchema,
    required this.handler,
    this.allowInParallel = true,
    this.timeoutMs = 10000,
  });

  final String name;
  final String description;

  /// JSON Schema for input parameters.
  final Map<String, dynamic> inputSchema;

  /// The actual function to execute.
  final Future<ToolResult> Function(Map<String, dynamic> input) handler;

  final bool allowInParallel;
  final int timeoutMs;

  Map<String, dynamic> toAnthropicSchema() => {
        'name': name,
        'description': description,
        'input_schema': inputSchema,
      };

  Map<String, dynamic> toOpenAISchema() => {
        'type': 'function',
        'function': {
          'name': name,
          'description': description,
          'parameters': inputSchema,
        },
      };
}

class ToolResult {
  const ToolResult({
    required this.toolCallId,
    required this.toolName,
    this.content,
    this.error,
    this.isError = false,
  });

  final String toolCallId;
  final String toolName;
  final dynamic content;
  final String? error;
  final bool isError;

  Map<String, dynamic> toJson() => {
        'tool_call_id': toolCallId,
        'tool_name': toolName,
        if (content != null) 'content': content,
        if (error != null) 'error': error,
        'is_error': isError,
      };
}

// ─────────────────────────────────────────────
// Tool call request (from LLM)
// ─────────────────────────────────────────────

class ToolCallRequest {
  const ToolCallRequest({
    required this.id,
    required this.name,
    required this.input,
  });

  final String id;
  final String name;
  final Map<String, dynamic> input;
}

// ─────────────────────────────────────────────
// Tool runner events
// ─────────────────────────────────────────────

sealed class ToolRunnerEvent {}

class ToolCallingEvent extends ToolRunnerEvent {
  ToolCallingEvent({required this.toolName, required this.input});
  final String toolName;
  final Map<String, dynamic> input;
}

class ToolResultEvent extends ToolRunnerEvent {
  ToolResultEvent({required this.result});
  final ToolResult result;
}

class ToolLoopIterationEvent extends ToolRunnerEvent {
  ToolLoopIterationEvent(
      {required this.iteration, required this.maxIterations});
  final int iteration;
  final int maxIterations;
}

class ToolLoopCompleteEvent extends ToolRunnerEvent {
  ToolLoopCompleteEvent({required this.output});
  final AgentTurnOutput output;
}

class ToolLoopErrorEvent extends ToolRunnerEvent {
  ToolLoopErrorEvent({required this.error});
  final Object error;
}

// ─────────────────────────────────────────────
// Tool-use adapter (wraps any AgentAdapter)
// ─────────────────────────────────────────────

abstract class ToolAwareAdapter extends AgentAdapter {
  const ToolAwareAdapter();

  /// Call LLM with tools attached. Returns raw response.
  Future<ToolAwareResponse> sendWithTools({
    required AgentTurnInput input,
    required List<AgentTool> tools,
    required List<ToolResult> previousResults,
  });
}

class ToolAwareResponse {
  const ToolAwareResponse({
    this.toolCalls = const [],
    this.finalOutput,
    this.rawContent,
  });

  final List<ToolCallRequest> toolCalls;
  final AgentTurnOutput? finalOutput;
  final dynamic rawContent;

  bool get hasToolCalls => toolCalls.isNotEmpty;
  bool get isComplete => finalOutput != null;
}

// ─────────────────────────────────────────────
// Anthropic tool-aware adapter
// ─────────────────────────────────────────────

class AnthropicToolAdapter extends ToolAwareAdapter {
  AnthropicToolAdapter({
    required this.apiKey,
    this.model = 'claude-opus-4-6',
    this.maxTokens = 4096,
    this.systemPrompt,
    this.baseUrl = 'https://api.anthropic.com/v1',
  });

  final String apiKey;
  final String model;
  final int maxTokens;
  final String? systemPrompt;
  final String baseUrl;

  @override
  Future<AgentTurnOutput> sendTurn(AgentTurnInput input) async {
    // Delegate to tool-free path
    final runner = AgentToolRunner(adapter: this, tools: []);
    final events = <ToolRunnerEvent>[];
    await runner.run(input).forEach(events.add);
    final complete = events.whereType<ToolLoopCompleteEvent>().firstOrNull;
    return complete?.output ?? AgentTurnOutput(error: Exception('No output'));
  }

  @override
  Future<ToolAwareResponse> sendWithTools({
    required AgentTurnInput input,
    required List<AgentTool> tools,
    required List<ToolResult> previousResults,
  }) async {
    final messages = _buildMessages(input, previousResults);
    final toolSchemas = tools.map((t) => t.toAnthropicSchema()).toList();

    final body = json.encode({
      'model': model,
      'max_tokens': maxTokens,
      if (systemPrompt != null) 'system': systemPrompt,
      'messages': messages,
      if (toolSchemas.isNotEmpty) 'tools': toolSchemas,
    });

    final response = await http.post(
      Uri.parse('$baseUrl/messages'),
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': apiKey,
        'anthropic-version': '2023-06-01',
      },
      body: body,
    );

    if (response.statusCode != 200) {
      throw Exception(
          'Anthropic API error ${response.statusCode}: ${response.body}');
    }

    final data = json.decode(response.body) as Map<String, dynamic>;
    final content = (data['content'] as List<dynamic>?) ?? [];
    final stopReason = data['stop_reason'] as String?;

    if (stopReason == 'tool_use') {
      // Extract tool calls
      final toolUseBlocks = content
          .whereType<Map>()
          .where((b) => b['type'] == 'tool_use')
          .toList();

      final calls = toolUseBlocks
          .map((b) => ToolCallRequest(
                id: b['id'] as String,
                name: b['name'] as String,
                input: (b['input'] as Map<String, dynamic>?) ?? {},
              ))
          .toList();

      return ToolAwareResponse(toolCalls: calls, rawContent: content);
    }

    // Final response — extract UI
    final text = content
        .whereType<Map>()
        .where((b) => b['type'] == 'text')
        .map((b) => b['text'] as String)
        .join('\n');

    return ToolAwareResponse(
      finalOutput: AgentTurnOutput(
        uiResponse: _extractUI(text),
        textResponse: text,
      ),
    );
  }

  List<Map<String, dynamic>> _buildMessages(
      AgentTurnInput input, List<ToolResult> results) {
    final messages = <Map<String, dynamic>>[];

    for (final h in input.history) {
      messages.add({'role': h.role, 'content': h.content});
    }
    messages.add({'role': 'user', 'content': input.userMessage});

    // Append tool results as a tool_result content block
    if (results.isNotEmpty) {
      final toolResultContent = results
          .map((r) => {
                'type': 'tool_result',
                'tool_use_id': r.toolCallId,
                'content':
                    r.isError ? 'Error: ${r.error}' : json.encode(r.content),
                'is_error': r.isError,
              })
          .toList();
      messages.add({'role': 'user', 'content': toolResultContent});
    }

    return messages;
  }

  AgentUIResponse? _extractUI(String text) {
    final trimmed = text.trim();
    if (trimmed.startsWith('{')) {
      try {
        final j = json.decode(trimmed) as Map<String, dynamic>;
        if (j.containsKey('root')) return AgentUIResponse.fromJson(j);
      } catch (_) {}
    }
    final match =
        RegExp(r'```(?:json)?\s*(\{[\s\S]*?\})\s*```').firstMatch(text);
    if (match != null) {
      try {
        final j = json.decode(match.group(1)!) as Map<String, dynamic>;
        if (j.containsKey('root')) return AgentUIResponse.fromJson(j);
      } catch (_) {}
    }
    return null;
  }

  @override
  AgentUIResponse? parseResponse(dynamic raw) => null;
}

// ─────────────────────────────────────────────
// Tool runner — the agentic loop
// ─────────────────────────────────────────────

class AgentToolRunner {
  AgentToolRunner({
    required this.adapter,
    required this.tools,
    this.maxIterations = 10,
    this.onEvent,
  });

  final ToolAwareAdapter adapter;
  final List<AgentTool> tools;
  final int maxIterations;
  final void Function(ToolRunnerEvent)? onEvent;

  final _toolMap = <String, AgentTool>{};

  Stream<ToolRunnerEvent> run(AgentTurnInput input) async* {
    // Build tool map
    for (final t in tools) {
      _toolMap[t.name] = t;
    }

    final results = <ToolResult>[];
    int iteration = 0;

    while (iteration < maxIterations) {
      iteration++;
      _log.info('Tool loop iteration $iteration/$maxIterations');

      yield ToolLoopIterationEvent(
          iteration: iteration, maxIterations: maxIterations);

      ToolAwareResponse response;
      try {
        response = await adapter.sendWithTools(
          input: input,
          tools: tools,
          previousResults: results,
        );
      } catch (e) {
        yield ToolLoopErrorEvent(error: e);
        return;
      }

      if (response.isComplete) {
        yield ToolLoopCompleteEvent(output: response.finalOutput!);
        return;
      }

      if (!response.hasToolCalls) {
        yield ToolLoopCompleteEvent(
          output: AgentTurnOutput(
            error:
                Exception('Agent returned no tool calls and no final response'),
          ),
        );
        return;
      }

      // Execute tool calls
      final callsToExecute = response.toolCalls;
      final parallelCalls = callsToExecute
          .where(
            (c) => _toolMap[c.name]?.allowInParallel == true,
          )
          .toList();
      final sequentialCalls = callsToExecute
          .where(
            (c) => _toolMap[c.name]?.allowInParallel != true,
          )
          .toList();

      // Run parallel tools concurrently
      if (parallelCalls.isNotEmpty) {
        final parallelResults = await Future.wait(
          parallelCalls.map((call) => _executeToolCall(call)),
        );
        for (final res in parallelResults) {
          yield ToolResultEvent(result: res);
          results.add(res);
        }
      }

      // Run sequential tools one by one
      for (final call in sequentialCalls) {
        yield ToolCallingEvent(toolName: call.name, input: call.input);
        final res = await _executeToolCall(call);
        yield ToolResultEvent(result: res);
        results.add(res);
      }
    }

    yield ToolLoopErrorEvent(
      error: Exception(
          'Max iterations ($maxIterations) reached without completion'),
    );
  }

  Future<ToolResult> _executeToolCall(ToolCallRequest call) async {
    final tool = _toolMap[call.name];
    if (tool == null) {
      return ToolResult(
        toolCallId: call.id,
        toolName: call.name,
        error: 'Unknown tool: ${call.name}',
        isError: true,
      );
    }

    try {
      _log.info('Executing tool: ${call.name} with ${call.input}');
      final result = await tool.handler(call.input).timeout(
            Duration(milliseconds: tool.timeoutMs),
            onTimeout: () => ToolResult(
              toolCallId: call.id,
              toolName: call.name,
              error: 'Tool timed out after ${tool.timeoutMs}ms',
              isError: true,
            ),
          );
      return result;
    } catch (e) {
      _log.warning('Tool ${call.name} threw: $e');
      return ToolResult(
        toolCallId: call.id,
        toolName: call.name,
        error: e.toString(),
        isError: true,
      );
    }
  }
}

// ─────────────────────────────────────────────
// Built-in tools
// ─────────────────────────────────────────────

/// Tools that the framework provides out-of-the-box.
class BuiltinTools {
  /// Returns the current variable store snapshot.
  static AgentTool variableReader(Map<String, dynamic> Function() getVars) =>
      AgentTool(
        name: 'get_variables',
        description: 'Read current UI variable store values',
        inputSchema: {
          'type': 'object',
          'properties': {
            'keys': {
              'type': 'array',
              'items': {'type': 'string'},
              'description': 'Variable keys to read (empty = all)',
            },
          },
        },
        handler: (input) async {
          final keys = (input['keys'] as List<dynamic>?)?.cast<String>();
          final vars = getVars();
          final filtered = keys != null && keys.isNotEmpty
              ? Map.fromEntries(vars.entries.where((e) => keys.contains(e.key)))
              : vars;
          return ToolResult(
            toolCallId: '',
            toolName: 'get_variables',
            content: filtered,
          );
        },
      );

  /// Sets variables in the store.
  static AgentTool variableWriter(void Function(String, dynamic) setVar) =>
      AgentTool(
        name: 'set_variable',
        description: 'Write a value to the UI variable store',
        inputSchema: {
          'type': 'object',
          'required': ['key', 'value'],
          'properties': {
            'key': {'type': 'string'},
            'value': {'description': 'Any JSON value'},
          },
        },
        handler: (input) async {
          final key = input['key'] as String;
          final value = input['value'];
          setVar(key, value);
          return ToolResult(
            toolCallId: '',
            toolName: 'set_variable',
            content: {'set': key, 'value': value},
          );
        },
      );

  /// HTTP GET fetch tool.
  static AgentTool httpGet({List<String> allowedDomains = const []}) =>
      AgentTool(
        name: 'http_get',
        description: 'Fetch JSON data from a URL',
        inputSchema: {
          'type': 'object',
          'required': ['url'],
          'properties': {
            'url': {'type': 'string', 'description': 'https:// URL to fetch'},
            'headers': {
              'type': 'object',
              'description': 'Optional HTTP headers',
            },
          },
        },
        handler: (input) async {
          final url = input['url'] as String;

          // Domain whitelist check
          if (allowedDomains.isNotEmpty) {
            final uri = Uri.tryParse(url);
            if (uri == null ||
                !allowedDomains.any((d) => uri.host.endsWith(d))) {
              return ToolResult(
                toolCallId: '',
                toolName: 'http_get',
                error: 'Domain not in allowed list: ${uri?.host}',
                isError: true,
              );
            }
          }

          final headers = (input['headers'] as Map<String, dynamic>?)
                  ?.cast<String, String>() ??
              {};
          final response = await http.get(Uri.parse(url), headers: headers);
          dynamic body;
          try {
            body = json.decode(response.body);
          } catch (_) {
            body = response.body;
          }
          return ToolResult(
            toolCallId: '',
            toolName: 'http_get',
            content: {
              'status': response.statusCode,
              'body': body,
            },
            isError: response.statusCode >= 400,
          );
        },
      );

  /// Current date/time tool.
  static AgentTool dateTime() => AgentTool(
        name: 'get_datetime',
        description: 'Get the current date and time',
        inputSchema: {'type': 'object', 'properties': {}},
        handler: (input) async {
          final now = DateTime.now();
          return ToolResult(
            toolCallId: '',
            toolName: 'get_datetime',
            content: {
              'iso8601': now.toIso8601String(),
              'timestamp': now.millisecondsSinceEpoch,
              'date':
                  '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
              'time':
                  '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
              'timezone': now.timeZoneName,
            },
          );
        },
      );
}
