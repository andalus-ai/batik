// lib/core/websocket_client.dart
//
// Wayang Assistant WebSocket Client
// ============================================================
// Real-time streaming chat connection to Wayang Assistant API.
// Handles message serialization, session management, and streaming.
// ============================================================

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';

/// Represents a chunk of streamed response from the assistant.
class ChatChunk {
  final String content;
  final String? sessionId;
  final DateTime timestamp;

  ChatChunk({
    required this.content,
    this.sessionId,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  factory ChatChunk.fromJson(Map<String, dynamic> json) {
    return ChatChunk(
      content: json['content'] as String? ?? '',
      sessionId: json['sessionId'] as String?,
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'content': content,
        'sessionId': sessionId,
        'timestamp': timestamp.toIso8601String(),
      };
}

/// Error response from the server.
class ChatError {
  final String message;
  final String? code;
  final DateTime timestamp;

  ChatError({
    required this.message,
    this.code,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  factory ChatError.fromJson(Map<String, dynamic> json) {
    return ChatError(
      message: json['error'] as String? ?? 'Unknown error',
      code: json['code'] as String?,
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : DateTime.now(),
    );
  }

  @override
  String toString() => 'ChatError($message${code != null ? ' [$code]' : ''})';
}

/// Callback for incoming message chunks.
typedef OnChunk = void Function(ChatChunk chunk);

/// Callback for errors.
typedef OnError = void Function(ChatError error);

/// Callback for connection state changes.
typedef OnStateChange = void Function(WebSocketState state);

/// WebSocket connection states.
enum WebSocketState { disconnected, connecting, connected, closing, closed, error }

/// WebSocket client for Wayang Assistant API.
///
/// Features:
/// - Automatic reconnection with exponential backoff
/// - Session persistence across reconnections
/// - Real-time streaming of responses
/// - Proper error handling and reporting
/// - Clean resource management
class WayangAssistantWebSocketClient extends ChangeNotifier {
  static const String _defaultUrl = 'ws://localhost:8080/api/v1/assistant/chat-stream';
  static const int _reconnectMaxAttempts = 5;
  static const Duration _reconnectBaseDelay = Duration(milliseconds: 500);

  final String url;
  final String? sessionId;

  WebSocketState _state = WebSocketState.disconnected;
  int _reconnectAttempts = 0;
  Timer? _reconnectTimer;
  
  // ignore: avoid_private_typedef_functions
  final List<OnChunk> _onChunkCallbacks = [];
  final List<OnError> _onErrorCallbacks = [];
  final List<OnStateChange> _onStateCallbacks = [];

  /// WebSocket connection stream.
  dynamic _webSocket;

  WayangAssistantWebSocketClient({
    String? url,
    this.sessionId,
  }) : url = url ?? _defaultUrl;

  /// Current connection state.
  WebSocketState get state => _state;

  /// Whether the client is connected.
  bool get isConnected => _state == WebSocketState.connected;

  /// Registers a callback for incoming chunks.
  void onChunk(OnChunk callback) => _onChunkCallbacks.add(callback);

  /// Registers a callback for errors.
  void onError(OnError callback) => _onErrorCallbacks.add(callback);

  /// Registers a callback for state changes.
  void onStateChange(OnStateChange callback) => _onStateCallbacks.add(callback);

  /// Removes a chunk callback.
  void removeOnChunk(OnChunk callback) => _onChunkCallbacks.remove(callback);

  /// Removes an error callback.
  void removeOnError(OnError callback) => _onErrorCallbacks.remove(callback);

  /// Removes a state change callback.
  void removeOnStateChange(OnStateChange callback) =>
      _onStateCallbacks.remove(callback);

  /// Connects to the WebSocket server.
  Future<void> connect() async {
    if (_state == WebSocketState.connected || _state == WebSocketState.connecting) {
      return;
    }

    _setState(WebSocketState.connecting);

    try {
      if (kIsWeb) {
        // Web implementation using dart:html
        _connectWeb();
      } else {
        // Mobile implementation using web_socket_channel
        _connectMobile();
      }
      _reconnectAttempts = 0;
    } catch (e) {
      _handleError(ChatError(message: 'Connection failed: $e'));
      _scheduleReconnect();
    }
  }

  void _connectWeb() {
    // For web platform - uses native WebSocket
    // Implementation depends on dart:html availability
    throw UnimplementedError('Web platform not yet implemented');
  }

  void _connectMobile() {
    // Mobile implementation would use web_socket_channel package
    // For now, this is a placeholder
    throw UnimplementedError('Mobile platform requires web_socket_channel dependency');
  }

  /// Sends a message to the assistant.
  Future<void> sendMessage(String message) async {
    if (!isConnected) {
      _handleError(ChatError(message: 'Not connected to assistant'));
      return;
    }

    try {
      final payload = {
        'sessionId': sessionId ?? 'flutter-${DateTime.now().millisecondsSinceEpoch}',
        'message': message,
      };

      final jsonString = jsonEncode(payload);
      _webSocket.sink.add(jsonString);
    } catch (e) {
      _handleError(ChatError(message: 'Failed to send message: $e'));
    }
  }

  /// Disconnects from the WebSocket server.
  Future<void> disconnect() async {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;

    if (_webSocket != null) {
      _setState(WebSocketState.closing);
      try {
        await _webSocket.sink.close();
      } catch (e) {
        if (kDebugMode) print('Error closing WebSocket: $e');
      }
    }

    _setState(WebSocketState.closed);
    _webSocket = null;
  }

  /// Handles incoming message from server.
  void _handleMessage(String rawData) {
    try {
      // Try to parse as JSON error response
      try {
        final json = jsonDecode(rawData) as Map<String, dynamic>;
        if (json.containsKey('error')) {
          _handleError(ChatError.fromJson(json));
          return;
        }
      } catch (_) {
        // Not JSON, treat as raw chunk content
      }

      // Treat as chunk content
      final chunk = ChatChunk(
        content: rawData,
        sessionId: sessionId,
      );

      for (final callback in _onChunkCallbacks) {
        callback(chunk);
      }
    } catch (e) {
      _handleError(ChatError(message: 'Failed to process message: $e'));
    }
  }

  /// Handles errors from the connection.
  void _handleError(ChatError error) {
    _setState(WebSocketState.error);

    for (final callback in _onErrorCallbacks) {
      callback(error);
    }

    if (kDebugMode) print('WebSocket error: $error');
  }

  /// Schedules a reconnection attempt with exponential backoff.
  void _scheduleReconnect() {
    if (_reconnectAttempts >= _reconnectMaxAttempts) {
      _handleError(ChatError(
        message: 'Max reconnection attempts reached',
        code: 'MAX_RECONNECT_ATTEMPTS',
      ));
      _setState(WebSocketState.error);
      return;
    }

    _reconnectAttempts++;
    final delay = _reconnectBaseDelay * (2 ^ (_reconnectAttempts - 1));

    _reconnectTimer = Timer(delay, () {
      if (kDebugMode) print('Attempting to reconnect... (attempt $_reconnectAttempts)');
      connect();
    });
  }

  /// Updates the connection state and notifies listeners.
  void _setState(WebSocketState newState) {
    if (_state != newState) {
      _state = newState;
      notifyListeners();

      for (final callback in _onStateCallbacks) {
        callback(_state);
      }

      if (kDebugMode) print('WebSocket state changed: $_state');
    }
  }

  /// Cleans up resources.
  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}
