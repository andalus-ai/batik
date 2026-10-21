// lib/core/websocket_agent_adapter.dart
//
// WebSocket Agent Adapter
// ============================================================
// Bridges the WayangAssistantWebSocketClient to the AgentUIChat widget.
// Converts WebSocket messages to AgentUIResponse objects for rendering.
// ============================================================

import 'package:flutter/material.dart';
import 'websocket_client.dart';
import '../schema/ui_schema.dart';

/// Adapts WebSocket responses to AgentUIResponse format.
///
/// Converts streaming chat messages from the WebSocket API into
/// structured AgentUIResponse objects that can be rendered by AgentUIChat.
class WebSocketAgentAdapter {
  final WayangAssistantWebSocketClient _client;
  final String sessionId;

  /// Accumulated response content
  String _accumulatedContent = '';

  /// Response callback
  void Function(AgentUIResponse)? onResponse;

  /// Error callback
  void Function(Object)? onError;

  WebSocketAgentAdapter({
    required WayangAssistantWebSocketClient client,
    String? sessionId,
  })  : _client = client,
        sessionId =
            sessionId ?? 'flutter-${DateTime.now().millisecondsSinceEpoch}' {
    _setupListeners();
  }

  /// Sets up listeners on the WebSocket client.
  void _setupListeners() {
    _client.onChunk((chunk) => _handleChunk(chunk));
    _client.onError((error) => _handleError(error));
  }

  /// Handles incoming chunk from WebSocket.
  void _handleChunk(ChatChunk chunk) {
    // Accumulate content
    _accumulatedContent += chunk.content;

    // Create response object
    final response = _buildResponse();
    onResponse?.call(response);
  }

  /// Handles errors from WebSocket.
  void _handleError(ChatError error) {
    onError?.call(Exception(error.message));
  }

  /// Builds AgentUIResponse from accumulated content.
  AgentUIResponse _buildResponse() {
    // Parse accumulated content as markdown/text
    // This is a simple implementation - can be enhanced to support structured responses
    final root = TextNode(
      id: 'response-${DateTime.now().millisecondsSinceEpoch}',
      text: _accumulatedContent,
    );

    return AgentUIResponse(
      schemaVersion: '1.0.0',
      root: root,
      metadata: {
        'sessionId': sessionId,
        'timestamp': DateTime.now().toIso8601String(),
        'source': 'websocket',
      },
    );
  }

  /// Sends a message through the WebSocket.
  Future<void> sendMessage(String message) async {
    _accumulatedContent = ''; // Reset for new response
    await _client.sendMessage(message);
  }

  /// Connects to the WebSocket server.
  Future<void> connect() => _client.connect();

  /// Disconnects from the WebSocket server.
  Future<void> disconnect() => _client.disconnect();

  /// Gets the current connection state.
  WebSocketState get connectionState => _client.state;

  /// Whether currently connected.
  bool get isConnected => _client.isConnected;

  /// Disposes resources.
  void dispose() {
    disconnect();
  }
}

/// Provider setup for Riverpod integration.
///
/// Usage with Riverpod:
/// ```dart
/// final webSocketAdapterProvider =
///     StateNotifierProvider<WebSocketAdapterNotifier, WebSocketState>((ref) {
///   return WebSocketAdapterNotifier(
///     sessionId: 'your-session-id',
///   );
/// });
/// ```

// Example Riverpod integration (requires riverpod package)
// Uncomment if using with Riverpod state management

/*
import 'package:flutter_riverpod/flutter_riverpod.dart';

class WebSocketAdapterNotifier extends StateNotifier<WebSocketState> {
  late WebSocketAgentAdapter _adapter;
  final String? sessionId;

  WebSocketAdapterNotifier({this.sessionId})
      : super(WebSocketState.disconnected) {
    _initAdapter();
  }

  void _initAdapter() {
    final client = WayangAssistantWebSocketClient(
      sessionId: sessionId,
    );

    _adapter = WebSocketAgentAdapter(
      client: client,
      sessionId: sessionId,
    );

    _adapter.onResponse = (response) {
      // Handle response
    };

    _adapter.onError = (error) {
      // Handle error
    };

    // Watch connection state
    client.onStateChange((state) {
      this.state = state;
    });
  }

  Future<void> connect() => _adapter.connect();
  Future<void> disconnect() => _adapter.disconnect();
  Future<void> sendMessage(String message) => _adapter.sendMessage(message);
}

final webSocketAdapterProvider = StateNotifierProvider<
    WebSocketAdapterNotifier,
    WebSocketState>((ref) => WebSocketAdapterNotifier());
*/
