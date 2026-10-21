// lib/src/adapters/wayang_assistant_adapter.dart
//
// Batik Framework - Wayang Assistant API Adapter
// ============================================================
// Integrates Batik with the Wayang Assistant backend API.
// Supports both REST and WebSocket communication.
//
// Backend API:
// - POST /api/v1/assistant/ask      - Single Q&A
// - POST /api/v1/assistant/chat     - Multi-turn chat
// - GET  /api/v1/assistant/chat/{id}/history - Conversation history
// - DELETE /api/v1/assistant/chat/{id} - Delete session
// - POST /api/v1/assistant/generate-project - Project generation
// - POST /api/v1/assistant/troubleshoot - Error troubleshooting
// - GET  /api/v1/assistant/capabilities - Feature manifest
// ============================================================

import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../schema/ui_schema.dart';
import 'agent_adapter.dart';

/// Adapter for communicating with the Wayang Assistant backend API.
///
/// Supports:
/// - Multi-turn conversations with session management
/// - Project generation from natural language
/// - Error troubleshooting
/// - Documentation search
/// - Real-time streaming via WebSocket
class WayangAssistantAdapter extends AgentAdapter {
  WayangAssistantAdapter({
    required this.baseUrl,
    this.apiKey,
    this.sessionId,
    this.enableStreaming = false,
    this.defaultModel = 'wayang-assistant-v2',
  });

  /// Base URL of the Wayang Assistant API
  final String baseUrl;

  /// Optional API key for authentication
  final String? apiKey;

  /// Session ID for multi-turn conversations
  final String? sessionId;

  /// Enable streaming responses
  final bool enableStreaming;

  /// Default model to use
  final String defaultModel;

  String? _currentSessionId;
  final _messageHistory = <AgentMessage>[];

  /// Get the current session ID
  String? get currentSessionId => _currentSessionId ?? sessionId;

  /// Get the message history
  List<AgentMessage> get messageHistory => List.unmodifiable(_messageHistory);

  @override
  Future<AgentTurnOutput> sendTurn(AgentTurnInput input) async {
    try {
      // Update session ID if provided
      _currentSessionId = input.sessionId ?? _currentSessionId;

      // Add user message to history
      _messageHistory.add(AgentMessage(
        role: 'user',
        content: input.userMessage,
      ));

      // Call the chat API
      final response = await _callChatApi(input.userMessage);

      if (response['reply'] == null) {
        throw Exception('Invalid response from Wayang Assistant API');
      }

      final reply = response['reply'] as String;
      final sessionId = response['sessionId'] as String?;
      _currentSessionId = sessionId;

      // Add assistant response to history
      _messageHistory.add(AgentMessage(
        role: 'assistant',
        content: reply,
      ));

      // Try to parse the reply as UI JSON
      final uiResponse = _tryParseUIResponse(reply);

      return AgentTurnOutput(
        uiResponse: uiResponse,
        textResponse: uiResponse == null ? reply : null,
        rawResponse: response,
      );
    } catch (e) {
      return AgentTurnOutput(error: e);
    }
  }

  @override
  AgentUIResponse? parseResponse(dynamic raw) {
    if (raw is String) {
      return _tryParseUIResponse(raw);
    }
    return null;
  }

  /// Call the Wayang Assistant chat API
  Future<Map<String, dynamic>> _callChatApi(String message) async {
    final url = Uri.parse('$baseUrl/api/v1/assistant/chat');

    final body = {
      'message': message,
      if (_currentSessionId != null) 'sessionId': _currentSessionId,
    };

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        if (apiKey != null) 'Authorization': 'Bearer $apiKey!',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Wayang Assistant API error ${response.statusCode}: ${response.body}',
      );
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Try to parse a UI response from text
  AgentUIResponse? _tryParseUIResponse(String text) {
    try {
      // Look for JSON in the text
      final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(text);
      if (jsonMatch == null) return null;

      final jsonStr = jsonMatch.group(0)!;
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;

      // Check if it's a UI response envelope
      if (json.containsKey('root') && json['root'] is Map<String, dynamic>) {
        return AgentUIResponse.fromJson(json);
      }

      // Check if it's a bare node
      if (json.containsKey('type')) {
        return AgentUIResponse(
          schemaVersion: '2.0.0',
          root: UINode.fromJson(json),
        );
      }
    } catch (_) {
      // Not a valid UI response
    }
    return null;
  }

  /// Get conversation history from the server
  Future<List<ConversationTurn>> getHistory() async {
    if (_currentSessionId == null) return [];

    final url = Uri.parse('$baseUrl/api/v1/assistant/chat/$_currentSessionId/history');

    final response = await http.get(
      url,
      headers: {
        if (apiKey != null) 'Authorization': 'Bearer $apiKey!',
      },
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to get history: ${response.statusCode}',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final history = data['history'] as List<dynamic>;

    return history
        .map((item) => ConversationTurn.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  /// Clear the current conversation session
  Future<bool> clearSession() async {
    if (_currentSessionId == null) return false;

    final url = Uri.parse('$baseUrl/api/v1/assistant/chat/$_currentSessionId');

    final response = await http.delete(
      url,
      headers: {
        if (apiKey != null) 'Authorization': 'Bearer $apiKey!',
      },
    );

    if (response.statusCode == 200) {
      _currentSessionId = null;
      _messageHistory.clear();
      return true;
    }

    return false;
  }

  /// Generate a project from natural language intent
  Future<ProjectGenerationResult> generateProject({
    required String intent,
    String? name,
    String? description,
  }) async {
    final url = Uri.parse('$baseUrl/api/v1/assistant/generate-project');

    final body = {
      'intent': intent,
      if (name != null) 'name': name,
      if (description != null) 'description': description,
    };

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        if (apiKey != null) 'Authorization': 'Bearer $apiKey!',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to generate project: ${response.statusCode}',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return ProjectGenerationResult.fromJson(data);
  }

  /// Troubleshoot an error
  Future<ErrorTroubleshootingResult> troubleshootError({
    required String errorMessage,
    String? context,
  }) async {
    final url = Uri.parse('$baseUrl/api/v1/assistant/troubleshoot');

    final body = {
      'errorMessage': errorMessage,
      if (context != null) 'context': context,
    };

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        if (apiKey != null) 'Authorization': 'Bearer $apiKey!',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to troubleshoot error: ${response.statusCode}',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return ErrorTroubleshootingResult.fromJson(data);
  }

  /// Get assistant capabilities
  Future<Map<String, dynamic>> getCapabilities() async {
    final url = Uri.parse('$baseUrl/api/v1/assistant/capabilities');

    final response = await http.get(
      url,
      headers: {
        if (apiKey != null) 'Authorization': 'Bearer $apiKey!',
      },
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to get capabilities: ${response.statusCode}',
      );
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Search documentation
  Future<List<DocSearchResult>> searchDocumentation(String query) async {
    final url = Uri.parse('$baseUrl/api/v1/assistant/ask');

    final body = {'question': query};

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        if (apiKey != null) 'Authorization': 'Bearer $apiKey!',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to search documentation: ${response.statusCode}',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final results = data['documentationResults'] as List<dynamic>;

    return results
        .map((item) => DocSearchResult.fromJson(item as Map<String, dynamic>))
        .toList();
  }
}

/// Result from project generation
class ProjectGenerationResult {
  ProjectGenerationResult({
    required this.success,
    required this.project,
    required this.summary,
    this.nextSteps = const [],
  });

  final bool success;
  final Map<String, dynamic> project;
  final String summary;
  final List<String> nextSteps;

  factory ProjectGenerationResult.fromJson(Map<String, dynamic> json) {
    return ProjectGenerationResult(
      success: json['success'] as bool,
      project: json['project'] as Map<String, dynamic>,
      summary: json['summary'] as String,
      nextSteps: (json['nextSteps'] as List<dynamic>?)?.cast<String>() ?? [],
    );
  }
}

/// Result from error troubleshooting
class ErrorTroubleshootingResult {
  ErrorTroubleshootingResult({
    required this.errorMessage,
    required this.advice,
    this.documentationResults = const [],
    this.additionalHelp = const [],
  });

  final String errorMessage;
  final String advice;
  final List<DocSearchResult> documentationResults;
  final List<String> additionalHelp;

  factory ErrorTroubleshootingResult.fromJson(Map<String, dynamic> json) {
    return ErrorTroubleshootingResult(
      errorMessage: json['errorMessage'] as String,
      advice: json['advice'] as String,
      documentationResults: (json['documentationResults'] as List<dynamic>?)
              ?.map((item) => DocSearchResult.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
      additionalHelp: (json['additionalHelp'] as List<dynamic>?)?.cast<String>() ?? [],
    );
  }
}

/// Documentation search result
class DocSearchResult {
  DocSearchResult({
    required this.title,
    required this.snippet,
    required this.url,
    this.score = 0.0,
  });

  final String title;
  final String snippet;
  final String url;
  final double score;

  factory DocSearchResult.fromJson(Map<String, dynamic> json) {
    return DocSearchResult(
      title: json['title'] as String,
      snippet: json['snippet'] as String,
      url: json['url'] as String,
      score: (json['score'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// Conversation turn for history
class ConversationTurn {
  ConversationTurn({
    required this.role,
    required this.content,
    this.timestamp,
  });

  final String role;
  final String content;
  final DateTime? timestamp;

  factory ConversationTurn.fromJson(Map<String, dynamic> json) {
    return ConversationTurn(
      role: json['role'] as String,
      content: json['content'] as String,
      timestamp: json['timestamp'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['timestamp'] as int)
          : null,
    );
  }
}
