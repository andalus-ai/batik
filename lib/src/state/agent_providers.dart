// lib/src/state/agent_providers.dart
//
// Batik Framework v3 — Riverpod State Management
// ============================================================
// All framework state lives in Riverpod providers.
// This enables:
//  • DevTools inspection of all state
//  • Fine-grained widget rebuilds (only what changed)
//  • Easy testing via ProviderContainer overrides
//  • Hot-reload safe state
//  • Multi-session support via family providers
// ============================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../adapters/agent_adapter.dart';
import '../utils/response_cache.dart';
import '../schema/schema_validator.dart';
import '../streaming/streaming_parser.dart';
import '../schema/ui_schema.dart';
import '../diff/ui_diff_engine.dart' show DiffResult;

// ─────────────────────────────────────────────
// 1. Variable Store Provider (per session)
// ─────────────────────────────────────────────

/// Reactive key-value store bound to a session ID.
class VariableStoreNotifier extends Notifier<Map<String, dynamic>> {
  @override
  Map<String, dynamic> build() => {};

  void set(String key, dynamic value) {
    state = {...state, key: value};
  }

  void setMany(Map<String, dynamic> values) {
    state = {...state, ...values};
  }

  void remove(String key) {
    final next = Map<String, dynamic>.from(state);
    next.remove(key);
    state = next;
  }

  void clear() => state = {};

  T? get<T>(String key) => state[key] as T?;

  bool evaluate(String? condition) {
    if (condition == null) return true;
    final val = state[condition];
    if (val == null) return false;
    if (val is bool) return val;
    if (val is String) return val.isNotEmpty;
    if (val is num) return val != 0;
    return true;
  }
}

final variableStoreProvider =
    NotifierProvider<VariableStoreNotifier, Map<String, dynamic>>(
  VariableStoreNotifier.new,
);

// Session-scoped variable store (family = one per session ID)
final sessionVariableStoreProvider = NotifierProvider.family<
    SessionVariableStoreNotifier, Map<String, dynamic>, String>(
  SessionVariableStoreNotifier.new,
);

class SessionVariableStoreNotifier
    extends FamilyNotifier<Map<String, dynamic>, String> {
  @override
  Map<String, dynamic> build(String sessionId) => {};

  void set(String key, dynamic value) => state = {...state, key: value};
  void setMany(Map<String, dynamic> values) => state = {...state, ...values};
  void remove(String key) {
    final next = Map<String, dynamic>.from(state)..remove(key);
    state = next;
  }

  void clear() => state = {};
}

// ─────────────────────────────────────────────
// 2. Agent Session State
// ─────────────────────────────────────────────

enum AgentSessionStatus {
  idle,
  thinking,
  streaming,
  callingTool,
  error,
}

class AgentSessionState {
  const AgentSessionState({
    this.status = AgentSessionStatus.idle,
    this.currentResponse,
    this.streamProgress = 0.0,
    this.history = const [],
    this.error,
    this.lastDiff,
    this.statusDetail,
    this.activeToolCall,
  });

  final AgentSessionStatus status;
  final AgentUIResponse? currentResponse;
  final double streamProgress;
  final List<ConversationTurn> history;
  final Object? error;
  final DiffResult? lastDiff;
  final String? statusDetail;
  final ToolCall? activeToolCall;

  bool get isLoading =>
      status == AgentSessionStatus.thinking ||
      status == AgentSessionStatus.streaming ||
      status == AgentSessionStatus.callingTool;

  AgentSessionState copyWith({
    AgentSessionStatus? status,
    AgentUIResponse? currentResponse,
    double? streamProgress,
    List<ConversationTurn>? history,
    Object? error,
    DiffResult? lastDiff,
    String? statusDetail,
    ToolCall? activeToolCall,
    bool clearError = false,
  }) =>
      AgentSessionState(
        status: status ?? this.status,
        currentResponse: currentResponse ?? this.currentResponse,
        streamProgress: streamProgress ?? this.streamProgress,
        history: history ?? this.history,
        error: clearError ? null : (error ?? this.error),
        lastDiff: lastDiff ?? this.lastDiff,
        statusDetail: statusDetail ?? this.statusDetail,
        activeToolCall: activeToolCall ?? this.activeToolCall,
      );
}

class ConversationTurn {
  const ConversationTurn({
    required this.id,
    required this.role,
    required this.content,
    this.uiResponse,
    this.timestamp,
    this.toolCalls = const [],
  });

  final String id;
  final String role; // 'user' or 'assistant'
  final String content;
  final AgentUIResponse? uiResponse;
  final DateTime? timestamp;
  final List<ToolCall> toolCalls;

  factory ConversationTurn.user(String content) => ConversationTurn(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        role: 'user',
        content: content,
        timestamp: DateTime.now(),
      );

  factory ConversationTurn.assistant(
    String content, {
    AgentUIResponse? uiResponse,
    List<ToolCall> toolCalls = const [],
  }) =>
      ConversationTurn(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        role: 'assistant',
        content: content,
        uiResponse: uiResponse,
        toolCalls: toolCalls,
        timestamp: DateTime.now(),
      );
}

class ToolCall {
  const ToolCall({
    required this.id,
    required this.name,
    this.arguments,
  });

  final String id;
  final String name;
  final Map<String, dynamic>? arguments;
}

class AgentSessionConfig {
  const AgentSessionConfig({
    required this.sessionId,
    this.adapter,
    this.initialMessages = const [],
    this.maxHistoryTurns = 20,
    this.enableStreaming = true,
    this.cacheResponses = false,
    this.validatorConfig,
  });

  final String sessionId;
  final AgentAdapter? adapter;
  final List<ConversationTurn> initialMessages;
  final int maxHistoryTurns;
  final bool enableStreaming;
  final bool cacheResponses;
  final ValidatorConfig? validatorConfig;
}

// ─────────────────────────────────────────────
// 3. Simple State Providers
// ─────────────────────────────────────────────

// Session-based response tracking
final agentSessionStateProvider = NotifierProvider.family<AgentSessionNotifier,
    AgentSessionState, AgentSessionConfig>(
  AgentSessionNotifier.new,
);

// Alias for backward compatibility
final agentSessionProvider = agentSessionStateProvider;

class AgentSessionNotifier
    extends FamilyNotifier<AgentSessionState, AgentSessionConfig> {
  late AgentSessionConfig config;
  late final UISchemaValidator _validator;

  @override
  AgentSessionState build(AgentSessionConfig config) {
    this.config = config;
    _validator = UISchemaValidator(
      config: config.validatorConfig ?? const ValidatorConfig(),
    );
    return AgentSessionState(history: config.initialMessages);
  }

  void updateStatus(AgentSessionStatus status, {String? detail}) {
    state = state.copyWith(status: status, statusDetail: detail);
  }

  Future<void> sendMessage(String message) async {
    if (config.adapter == null) return;

    updateStatus(AgentSessionStatus.thinking);

    try {
      final userTurn = ConversationTurn.user(message);
      state = state.copyWith(history: [...state.history, userTurn]);

      final output = await config.adapter!.sendTurn(
        AgentTurnInput(
          userMessage: message,
          history: state.history
              .map((t) => AgentMessage(role: t.role, content: t.content))
              .toList(),
        ),
      );

      if (output.hasError) {
        state = state.copyWith(
            error: output.error, status: AgentSessionStatus.error);
        return;
      }

      final assistantTurn = ConversationTurn.assistant(
        output.textResponse ?? '',
        uiResponse: output.uiResponse,
      );

      final newHistory = [...state.history, assistantTurn];
      final trimmedHistory = newHistory.length > config.maxHistoryTurns
          ? newHistory.sublist(newHistory.length - config.maxHistoryTurns)
          : newHistory;

      state = state.copyWith(
        history: trimmedHistory,
        currentResponse: output.uiResponse,
        status: AgentSessionStatus.idle,
      );
    } catch (e) {
      state = state.copyWith(error: e, status: AgentSessionStatus.error);
    }
  }

  Future<void> sendMessageStreaming(String message) async {
    // Simplified streaming implementation
    await sendMessage(message);
  }
}
