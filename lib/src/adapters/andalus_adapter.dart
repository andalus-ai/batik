// lib/src/adapters/andalus_adapter.dart
//
// Batik — Andalus AI Backend Adapter
// ============================================================
// Connects Batik's agent UI pipeline to the Andalus intelligence
// engine used by the Alhambra platform.
//
// Andalus API contract:
//   POST /v1/intelligence/ui
//   Headers:
//     Authorization: Bearer <apiKey>
//     X-Organization-Id: <orgId>   (optional)
//   Body: { userMessage, history, variables, metadata,
//           schemaVersion, maxTokens, systemPrompt?, sessionId? }
//   Response:
//     { schemaVersion, root: UINode, metadata? }   — full envelope
//     OR { type: '...', ... }                      — bare UINode
//     OR { ui: { ...envelope }, text: '...' }      — Andalus wrapper
// ============================================================

import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../schema/ui_schema.dart';
import 'agent_adapter.dart';

/// Batik [AgentAdapter] for the Andalus AI backend (Alhambra platform).
///
/// Usage:
/// ```dart
/// final adapter = AndalusAdapter(
///   baseUrl: 'https://andalus.example.com',
///   apiKey: secretKey,
///   organizationId: orgContext.organizationId,
/// );
/// ```
///
/// The adapter participates fully in Batik's adapter ecosystem:
/// streaming, history, variables, mock overrides all work as-is.
class AndalusAdapter extends AgentAdapter {
  const AndalusAdapter({
    required this.baseUrl,
    required this.apiKey,
    this.organizationId,
    this.workspaceId,
    this.schemaVersion = '1.0.0',
    this.maxTokens = 4096,
    this.systemPrompt,
    this.appContext,
    http.Client? httpClient,
  }) : _http = httpClient;

  final String baseUrl;
  final String apiKey;
  final String? organizationId;
  final String? workspaceId;
  final String schemaVersion;
  final int maxTokens;
  final String? systemPrompt;
  final String? appContext;

  // ignore: prefer_final_fields
  final http.Client? _http;

  http.Client get _client => _http ?? http.Client();

  @override
  Future<AgentTurnOutput> sendTurn(AgentTurnInput input) async {
    try {
      final body = json.encode({
        'userMessage': input.userMessage,
        'history': input.history
            .map((m) => {'role': m.role, 'content': m.content})
            .toList(),
        'variables': input.variables,
        'metadata': {
          ...input.metadata,
          if (organizationId != null) 'organizationId': organizationId,
          if (workspaceId != null) 'workspaceId': workspaceId,
        },
        'schemaVersion': schemaVersion,
        'maxTokens': maxTokens,
        'systemPrompt': systemPrompt ??
            UISystemPromptBuilder.build(
              appContext: appContext,
              schemaVersion: schemaVersion,
            ),
        if (input.sessionId != null) 'sessionId': input.sessionId,
      });

      final response = await _client.post(
        Uri.parse('$baseUrl/v1/intelligence/ui'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
          if (organizationId != null) 'X-Organization-Id': organizationId!,
        },
        body: body,
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(
          'Andalus API error ${response.statusCode}: ${response.body}',
        );
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      final uiResponse = _parseMap(data);

      return AgentTurnOutput(
        uiResponse: uiResponse,
        textResponse: data['text'] as String?,
        rawResponse: data,
      );
    } catch (e) {
      return AgentTurnOutput(error: e);
    }
  }

  @override
  AgentUIResponse? parseResponse(dynamic raw) {
    if (raw is Map<String, dynamic>) return _parseMap(raw);
    if (raw is String) {
      try {
        return _parseMap(json.decode(raw) as Map<String, dynamic>);
      } catch (_) {}
    }
    return null;
  }

  AgentUIResponse? _parseMap(Map<String, dynamic> data) {
    try {
      // 1. Full AgentUIResponse envelope: { schemaVersion, root, ... }
      if (data.containsKey('root')) {
        return AgentUIResponse.fromJson(data);
      }
      // 2. Bare UINode: { type: '...', ... }
      if (data.containsKey('type')) {
        return AgentUIResponse(
          schemaVersion: schemaVersion,
          root: UINode.fromJson(data),
          metadata: const {},
        );
      }
      // 3. Andalus wrapper: { ui: { ...envelope }, text: '...' }
      if (data.containsKey('ui')) {
        final ui = data['ui'];
        if (ui is Map<String, dynamic>) return AgentUIResponse.fromJson(ui);
      }
    } catch (_) {}
    return null;
  }
}
