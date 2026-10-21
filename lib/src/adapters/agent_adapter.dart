// lib/src/adapters/agent_adapter.dart
//
// AgentUIKit — Agent Adapter Interface
// ============================================================
// Abstract layer between your app and any LLM / rules engine.
// Implement [AgentAdapter] to connect any backend.
//
// Bundled adapters:
//  • [AnthropicAdapter]  — Claude via tool_use / text streaming
//  • [OpenAIAdapter]     — GPT-4o via structured outputs / tool_use
//  • [MockAdapter]       — for testing, demos, and offline dev
// ============================================================

import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../schema/ui_schema.dart';

// ─────────────────────────────────────────────
// Core interface
// ─────────────────────────────────────────────

/// Input context passed to the agent each turn.
class AgentTurnInput {
  const AgentTurnInput({
    required this.userMessage,
    this.history = const [],
    this.variables = const {},
    this.metadata = const {},
    this.sessionId,
  });

  final String userMessage;
  final List<AgentMessage> history;
  final Map<String, dynamic> variables;
  final Map<String, dynamic> metadata;
  final String? sessionId;
}

class AgentMessage {
  const AgentMessage({required this.role, required this.content});
  final String role; // "user" | "assistant" | "system"
  final String content;
}

/// Result of an agent turn.
class AgentTurnOutput {
  const AgentTurnOutput({
    this.uiResponse,
    this.textResponse,
    this.rawResponse,
    this.error,
    this.isStreaming = false,
  });

  final AgentUIResponse? uiResponse;
  final String? textResponse;
  final dynamic rawResponse;
  final Object? error;
  final bool isStreaming;

  bool get hasUI => uiResponse != null;
  bool get hasError => error != null;
}

/// Stream events for progressive / streaming responses.
sealed class AgentStreamEvent {}

class AgentInferenceChunk extends AgentStreamEvent {
  AgentInferenceChunk(this.text);
  final String text;
}

class AgentStreamUI extends AgentStreamEvent {
  AgentStreamUI(this.response);
  final AgentUIResponse response;
}

class AgentStreamError extends AgentStreamEvent {
  AgentStreamError(this.error);
  final Object error;
}

class AgentStreamDone extends AgentStreamEvent {}

/// The main adapter interface. Implement this to connect any LLM or backend.
abstract class AgentAdapter {
  const AgentAdapter();

  /// Single-shot turn (non-streaming).
  Future<AgentTurnOutput> sendTurn(AgentTurnInput input);

  /// Optional streaming turn. Default throws [UnimplementedError].
  Stream<AgentStreamEvent> streamTurn(AgentTurnInput input) {
    throw UnimplementedError('${runtimeType} does not support streaming.');
  }

  /// Parse raw LLM response JSON/text into [AgentUIResponse].
  /// Override to add custom extraction logic.
  AgentUIResponse? parseResponse(dynamic raw);
}

// ─────────────────────────────────────────────
// System prompt builder
// ─────────────────────────────────────────────

/// Generates a system prompt that instructs the LLM to produce
/// AgentUIKit-compatible JSON trees.
class UISystemPromptBuilder {
  static String build({
    String? appContext,
    String? schemaVersion,
    List<String>? allowedComponents,
  }) {
    final version = schemaVersion ?? '1.0.0';
    final components = allowedComponents?.join(', ') ??
        'container, row, column, stack, text, richText, image, icon, button, '
            'iconButton, textField, switch, slider, dropdown, card, list, listItem, '
            'grid, form, scaffold, appBar, bottomNav, fab, dialog, snackbar, '
            'divider, spacer, badge, chip, avatar, progressBar, chart, custom';

    return '''
You are an AI agent that generates Flutter UI trees for the AgentUIKit framework (schema v$version).

${appContext != null ? 'App context: $appContext\n' : ''}
## Output Format

Always respond with a SINGLE valid JSON object matching this envelope:
```json
{
  "schemaVersion": "$version",
  "root": <UINode>,
  "metadata": {}
}
```

## Node Structure

Every UINode must have:
- "type": one of [$components]
- "id": optional stable identifier
- "style": optional UIStyle object
- "actions": optional map of event → UIAction
- "children": optional array of UINodes
- "condition": optional variable key for conditional rendering

## UIStyle Properties
backgroundColor, foregroundColor, borderColor, borderRadius, borderWidth,
padding (top/right/bottom/left/all), margin, width, height, opacity, elevation,
fontSize, fontWeight (normal/bold/w100-w900), fontFamily, letterSpacing,
lineHeight, textAlign (left/center/right/justify), overflow (ellipsis/clip/fade),
flex, alignment (topLeft/center/bottomRight etc.), shadow, gradient

## UIAction Types
- "agentMessage": {"key": "...", "message": "..."} — sends user message
- "navigate": {"route": "..."} — navigation
- "setVariable": {"key": "...", "value": ...} — stores to VariableStore
- "openUrl": {"url": "..."}
- "dismiss": {}
- "submitForm": {"formId": "..."}
- "custom": {"handler": "...", ...}

## Rules
1. Return ONLY the JSON object — no markdown, no explanation
2. All string values must be properly escaped
3. Color values: hex (#RRGGBB/#RGB) or named (red, blue, primary, secondary…)
4. Icon names: home, search, settings, person, star, add, close, edit, delete, etc.
5. For empty/loading states use progressBar with null value
6. Prefer column/row/card composition over complex nesting
7. Use "condition" + "setVariable" actions for dynamic visibility
8. Use "variableBinding" on inputs to bind to VariableStore

## Example
User: "Show a login form"
```json
{
  "schemaVersion": "$version",
  "root": {
    "type": "scaffold",
    "body": {
      "type": "column",
      "style": {"padding": {"all": 24}},
      "mainAxisAlignment": "center",
      "children": [
        {"type": "text", "text": "Welcome Back", "variant": "headlineMedium"},
        {"type": "spacer", "height": 24},
        {"type": "textField", "label": "Email", "inputType": "email", "variableBinding": "email"},
        {"type": "spacer", "height": 16},
        {"type": "textField", "label": "Password", "obscureText": true, "variableBinding": "password"},
        {"type": "spacer", "height": 24},
        {
          "type": "button",
          "label": "Sign In",
          "variant": "filled",
          "style": {"width": 300},
          "actions": {"onTap": {"type": "agentMessage", "payload": {"message": "User signed in with email: {{email}}"}}}
        }
      ]
    }
  }
}
```
''';
  }
}

// ─────────────────────────────────────────────
// Mock adapter (testing / offline)
// ─────────────────────────────────────────────

class MockAdapter extends AgentAdapter {
  MockAdapter({
    this.delay = const Duration(milliseconds: 300),
    this.responseFactory,
  });

  final Duration delay;
  final AgentUIResponse Function(AgentTurnInput)? responseFactory;

  @override
  Future<AgentTurnOutput> sendTurn(AgentTurnInput input) async {
    await Future.delayed(delay);
    final response = responseFactory?.call(input) ?? _defaultResponse(input);
    return AgentTurnOutput(uiResponse: response);
  }

  @override
  AgentUIResponse? parseResponse(dynamic raw) => null;

  AgentUIResponse _defaultResponse(AgentTurnInput input) {
    return AgentUIResponse(
      schemaVersion: '1.0.0',
      root: CardNode(
        style: UIStyle(padding: const UIInsets(all: 16)),
        children: [
          ColumnNode(
            children: [
              TextNode(text: 'Agent Response', variant: 'titleMedium'),
              SpacerNode(height: 8),
              TextNode(
                text: 'You said: "${input.userMessage}"',
                style: const UIStyle(foregroundColor: 'grey'),
              ),
            ],
          ),
        ],
      ),
      sessionId: input.sessionId,
    );
  }
}

// ─────────────────────────────────────────────
// Anthropic adapter (Claude)
// ─────────────────────────────────────────────

/// Connects to the Anthropic Messages API.
/// The agent returns UI JSON via a `generate_ui` tool call.
class AnthropicAdapter extends AgentAdapter {
  AnthropicAdapter({
    required this.apiKey,
    this.model = 'claude-opus-4-6',
    this.maxTokens = 4096,
    this.systemPrompt,
    this.baseUrl = 'https://api.anthropic.com/v1',
    this.appContext,
    this.schemaVersion = '1.0.0',
  });

  final String apiKey;
  final String model;
  final int maxTokens;
  final String? systemPrompt;
  final String baseUrl;
  final String? appContext;
  final String schemaVersion;

  String get _system =>
      systemPrompt ??
      UISystemPromptBuilder.build(
        appContext: appContext,
        schemaVersion: schemaVersion,
      );

  @override
  Future<AgentTurnOutput> sendTurn(AgentTurnInput input) async {
    try {
      final messages = [
        ...input.history.map((m) => {'role': m.role, 'content': m.content}),
        {'role': 'user', 'content': input.userMessage},
      ];

      final body = json.encode({
        'model': model,
        'max_tokens': maxTokens,
        'system': _system,
        'messages': messages,
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
          'Anthropic API error ${response.statusCode}: ${response.body}',
        );
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      final content = (data['content'] as List<dynamic>?) ?? [];
      final text = content
          .whereType<Map>()
          .where((b) => b['type'] == 'text')
          .map((b) => b['text'] as String)
          .join('\n');

      final uiResponse = _extractUI(text);
      return AgentTurnOutput(
        uiResponse: uiResponse,
        textResponse: text,
        rawResponse: data,
      );
    } catch (e) {
      return AgentTurnOutput(error: e);
    }
  }

  @override
  AgentUIResponse? parseResponse(dynamic raw) {
    if (raw is String) return _extractUI(raw);
    return null;
  }

  AgentUIResponse? _extractUI(String text) {
    // Try direct JSON parse first.
    final trimmed = text.trim();
    if (trimmed.startsWith('{')) {
      return _tryParseJson(trimmed);
    }
    // Extract JSON from markdown code blocks.
    final pattern = RegExp(r'```(?:json)?\s*(\{[\s\S]*?\})\s*```');
    final match = pattern.firstMatch(text);
    if (match != null) return _tryParseJson(match.group(1)!);
    // Last resort: find first { ... }
    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start >= 0 && end > start) {
      return _tryParseJson(text.substring(start, end + 1));
    }
    return null;
  }

  AgentUIResponse? _tryParseJson(String raw) {
    try {
      final j = json.decode(raw) as Map<String, dynamic>;
      if (j.containsKey('root')) return AgentUIResponse.fromJson(j);
      // Bare node (no envelope) — wrap it.
      if (j.containsKey('type')) {
        return AgentUIResponse(
          schemaVersion: schemaVersion,
          root: UINode.fromJson(j),
        );
      }
    } catch (_) {}
    return null;
  }
}

// ─────────────────────────────────────────────
// OpenAI adapter (GPT-4o / GPT-4 Turbo)
// ─────────────────────────────────────────────

class OpenAIAdapter extends AgentAdapter {
  OpenAIAdapter({
    required this.apiKey,
    this.model = 'gpt-4o',
    this.maxTokens = 4096,
    this.systemPrompt,
    this.baseUrl = 'https://api.openai.com/v1',
    this.appContext,
    this.schemaVersion = '1.0.0',
  });

  final String apiKey;
  final String model;
  final int maxTokens;
  final String? systemPrompt;
  final String baseUrl;
  final String? appContext;
  final String schemaVersion;

  @override
  Future<AgentTurnOutput> sendTurn(AgentTurnInput input) async {
    try {
      final messages = [
        {
          'role': 'system',
          'content': systemPrompt ??
              UISystemPromptBuilder.build(
                appContext: appContext,
                schemaVersion: schemaVersion,
              ),
        },
        ...input.history.map((m) => {'role': m.role, 'content': m.content}),
        {'role': 'user', 'content': input.userMessage},
      ];

      final body = json.encode({
        'model': model,
        'max_tokens': maxTokens,
        'messages': messages,
        'response_format': {'type': 'json_object'},
      });

      final response = await http.post(
        Uri.parse('$baseUrl/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: body,
      );

      if (response.statusCode != 200) {
        throw Exception(
          'OpenAI API error ${response.statusCode}: ${response.body}',
        );
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      final text = data['choices']?[0]?['message']?['content'] as String? ?? '';

      return AgentTurnOutput(
        uiResponse: parseResponse(text),
        textResponse: text,
        rawResponse: data,
      );
    } catch (e) {
      return AgentTurnOutput(error: e);
    }
  }

  @override
  AgentUIResponse? parseResponse(dynamic raw) {
    if (raw is! String) return null;
    try {
      final j = json.decode(raw) as Map<String, dynamic>;
      if (j.containsKey('root')) return AgentUIResponse.fromJson(j);
      if (j.containsKey('type')) {
        return AgentUIResponse(
          schemaVersion: schemaVersion,
          root: UINode.fromJson(j),
        );
      }
    } catch (_) {}
    return null;
  }
}

// ─────────────────────────────────────────────
// Generic REST adapter
// ─────────────────────────────────────────────

/// For any REST API that accepts a prompt and returns AgentUIKit JSON.
class GenericRestAdapter extends AgentAdapter {
  GenericRestAdapter({
    required this.endpoint,
    required this.requestBuilder,
    required this.responseExtractor,
    this.headers = const {},
  });

  final String endpoint;
  final Map<String, String> headers;

  /// Builds the request body from the turn input.
  final Map<String, dynamic> Function(AgentTurnInput) requestBuilder;

  /// Extracts [AgentUIResponse] from the raw HTTP response body.
  final AgentUIResponse? Function(String body) responseExtractor;

  @override
  Future<AgentTurnOutput> sendTurn(AgentTurnInput input) async {
    try {
      final response = await http.post(
        Uri.parse(endpoint),
        headers: {'Content-Type': 'application/json', ...headers},
        body: json.encode(requestBuilder(input)),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
      return AgentTurnOutput(
        uiResponse: responseExtractor(response.body),
        rawResponse: response.body,
      );
    } catch (e) {
      return AgentTurnOutput(error: e);
    }
  }

  @override
  AgentUIResponse? parseResponse(dynamic raw) =>
      raw is String ? responseExtractor(raw) : null;
}
