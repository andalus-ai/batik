// lib/src/adapters/wayang_assistant_websocket_adapter.dart
//
// Batik Framework - Wayang Assistant WebSocket Adapter
// ============================================================
// Real-time streaming adapter using WebSocket connection
// to the Wayang Assistant backend.
//
// WebSocket Endpoint: ws://host/api/v1/assistant/ws
// ============================================================

import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../schema/ui_schema.dart';
import 'agent_adapter.dart';
import 'wayang_assistant_adapter.dart';

/// WebSocket-based adapter for real-time streaming with Wayang Assistant.
///
/// Features:
/// - Real-time streaming responses
/// - Bi-directional communication
/// - Session management
/// - Automatic reconnection
/// - Connection state monitoring
class WayangAssistantWebSocketAdapter extends AgentAdapter {
  WayangAssistantWebSocketAdapter({
    required this.wsUrl,
    this.apiKey,
    this.sessionId,
    this.autoReconnect = true,
    this.reconnectDelay = const Duration(seconds: 3),
    this.maxReconnectAttempts = 5,
  });

  /// WebSocket URL (e.g., 'ws://localhost:8080/api/v1/assistant/ws')
  final String wsUrl;

  /// Optional API key for authentication
  final String? apiKey;

  /// Session ID for multi-turn conversations
  final String? sessionId;

  /// Automatically reconnect on connection loss
  final bool autoReconnect;

  /// Delay between reconnection attempts
  final Duration reconnectDelay;

  /// Maximum number of reconnection attempts
  final int maxReconnectAttempts;

  WebSocketChannel? _channel;
  String? _currentSessionId;
  int _reconnectAttempts = 0;
  bool _isConnected = false;
  bool _isConnecting = false;

  final _messageController = StreamController<AgentStreamEvent>.broadcast();
  final _connectionController = StreamController<bool>.broadcast();

  /// Stream of connection state changes
  Stream<bool> get connectionState => _connectionController.stream;

  /// Whether currently connected
  bool get isConnected => _isConnected;

  /// Current session ID
  String? get currentSessionId => _currentSessionId ?? sessionId;

  @override
  Future<AgentTurnOutput> sendTurn(AgentTurnInput input) async {
    try {
      // Ensure connected
      await _ensureConnected();

      if (!_isConnected) {
        throw Exception('Not connected to Wayang Assistant WebSocket');
      }

      // Update session ID
      _currentSessionId = input.sessionId ?? _currentSessionId;

      // Send message
      final message = {
        'type': 'chat',
        'message': input.userMessage,
        if (_currentSessionId != null) 'sessionId': _currentSessionId,
        if (apiKey != null) 'apiKey': apiKey,
      };

      _channel!.sink.add(jsonEncode(message));

      // Wait for response with timeout
      final response = await _waitForResponse();

      if (response['error'] != null) {
        throw Exception(response['error'] as String);
      }

      final reply = response['reply'] as String? ?? '';
      _currentSessionId = response['sessionId'] as String?;

      // Try to parse UI response
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
  Stream<AgentStreamEvent> streamTurn(AgentTurnInput input) {
    _sendChatRequest(input);
    return _messageController.stream;
  }

  @override
  AgentUIResponse? parseResponse(dynamic raw) {
    if (raw is String) {
      return _tryParseUIResponse(raw);
    }
    return null;
  }

  /// Connect to the WebSocket server
  Future<void> connect() async {
    if (_isConnected || _isConnecting) return;

    _isConnecting = true;

    try {
      final url = Uri.parse(wsUrl);
      _channel = WebSocketChannel.connect(url);

      // Listen for messages
      _channel!.stream.listen(
        _handleMessage,
        onError: _handleError,
        onDone: _handleDisconnect,
      );

      // Wait for connection confirmation
      await _waitForConnection();

      _isConnected = true;
      _isConnecting = false;
      _reconnectAttempts = 0;
      _connectionController.add(true);
    } catch (e) {
      _isConnecting = false;
      _connectionController.add(false);
      rethrow;
    }
  }

  /// Disconnect from the WebSocket server
  Future<void> disconnect() async {
    _isConnected = false;
    _isConnecting = false;
    await _channel?.sink.close();
    _channel = null;
    _connectionController.add(false);
  }

  /// Send a chat request
  void _sendChatRequest(AgentTurnInput input) {
    if (!_isConnected) {
      _messageController.add(AgentStreamError('Not connected'));
      return;
    }

    final message = {
      'type': 'chat',
      'message': input.userMessage,
      if (input.sessionId != null) 'sessionId': input.sessionId,
      if (apiKey != null) 'apiKey': apiKey,
    };

    _channel!.sink.add(jsonEncode(message));
  }

  /// Wait for a response from the server
  Future<Map<String, dynamic>> _waitForResponse() async {
    final completer = Completer<Map<String, dynamic>>();
    StreamSubscription? subscription;

    subscription = _messageController.stream.listen(
      (event) {
        if (event is AgentStreamUI) {
          completer.complete({
            'reply': event.response.toJsonString(),
            'sessionId': _currentSessionId,
          });
          subscription?.cancel();
        } else if (event is AgentInferenceChunk) {
          // Accumulate chunks
        } else if (event is AgentStreamError) {
          completer.completeError(event.error);
          subscription?.cancel();
        }
      },
      onError: (error) {
        completer.completeError(error);
        subscription?.cancel();
      },
    );

    // Timeout after 30 seconds
    return completer.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        subscription?.cancel();
        throw Exception('Response timeout');
      },
    );
  }

  /// Wait for connection confirmation
  Future<void> _waitForConnection() async {
    final completer = Completer<void>();
    StreamSubscription? subscription;

    subscription = _connectionController.stream.listen(
      (connected) {
        if (connected) {
          completer.complete();
          subscription?.cancel();
        } else if (!_isConnecting) {
          completer.completeError(Exception('Connection failed'));
          subscription?.cancel();
        }
      },
      onError: (error) {
        completer.completeError(error);
        subscription?.cancel();
      },
    );

    // Timeout after 10 seconds
    return completer.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        subscription?.cancel();
        throw Exception('Connection timeout');
      },
    );
  }

  /// Handle incoming WebSocket messages
  void _handleMessage(dynamic message) {
    try {
      final data = jsonDecode(message as String) as Map<String, dynamic>;
      final type = data['type'] as String?;

      switch (type) {
        case 'connected':
          _isConnected = true;
          _isConnecting = false;
          _connectionController.add(true);
          break;

        case 'chunk':
          final chunk = data['chunk'] as String;
          _messageController.add(AgentInferenceChunk(chunk));
          break;

        case 'reply':
          final reply = data['reply'] as String;
          final sessionId = data['sessionId'] as String?;
          _currentSessionId = sessionId;

          final uiResponse = _tryParseUIResponse(reply);
          if (uiResponse != null) {
            _messageController.add(AgentStreamUI(uiResponse));
          } else {
            _messageController.add(AgentInferenceChunk(reply));
            _messageController.add(AgentStreamDone());
          }
          break;

        case 'error':
          final error = data['error'] as String;
          _messageController.add(AgentStreamError(error));
          break;

        case 'status':
          final status = data['status'] as String;
          _messageController.add(
            AgentInferenceChunk(
              '[status:${_parseStatus(status)}] ${data['detail'] ?? ''}'.trim(),
            ),
          );
          break;
      }
    } catch (e) {
      _messageController.add(AgentStreamError('Failed to parse message: $e'));
    }
  }

  /// Handle WebSocket errors
  void _handleError(dynamic error) {
    _messageController.add(AgentStreamError(error.toString()));
    _handleDisconnect();
  }

  /// Handle WebSocket disconnect
  void _handleDisconnect() {
    _isConnected = false;
    _isConnecting = false;
    _connectionController.add(false);

    if (autoReconnect && _reconnectAttempts < maxReconnectAttempts) {
      _reconnectAttempts++;
      Future.delayed(reconnectDelay, () {
        connect();
      });
    }
  }

  /// Ensure connected before sending
  Future<void> _ensureConnected() async {
    if (!_isConnected && !_isConnecting) {
      await connect();
    } else if (_isConnecting) {
      await _waitForConnection();
    }
  }

  /// Try to parse UI response from text
  AgentUIResponse? _tryParseUIResponse(String text) {
    try {
      final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(text);
      if (jsonMatch == null) return null;

      final jsonStr = jsonMatch.group(0)!;
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;

      if (json.containsKey('root') && json['root'] is Map<String, dynamic>) {
        return AgentUIResponse.fromJson(json);
      }

      if (json.containsKey('type')) {
        return AgentUIResponse(
          schemaVersion: '2.0.0',
          root: UINode.fromJson(json),
        );
      }
    } catch (_) {}
    return null;
  }

  /// Parse streaming status
  String _parseStatus(String status) {
    switch (status.toLowerCase()) {
      case 'thinking':
        return 'thinking';
      case 'calling_tool':
        return 'callingTool';
      case 'processing':
        return 'processingResult';
      case 'generating':
        return 'generating';
      default:
        return 'done';
    }
  }

  /// Dispose resources
  void dispose() {
    disconnect();
    _messageController.close();
    _connectionController.close();
  }
}
