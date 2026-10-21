// lib/src/persistence/session_persistence.dart
//
// AgentUIKit v3 — Session Persistence
// ============================================================
// Persists conversation history and session state to disk
// so conversations survive app restarts and agents retain
// full context on re-launch.
//
// Storage: Hive (already a dep from cache layer).
// Separate box from the response cache.
//
// Features:
//  • Save / load conversation turns per sessionId
//  • Max-turns cap (rolling window) to control storage growth
//  • Export conversation as JSON
//  • Clear individual or all sessions
//  • Session metadata (title, created, last active, model)
// ============================================================

import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:logging/logging.dart';
import '../state/agent_providers.dart';
import '../schema/ui_schema.dart';

final _log = Logger('AgentUIKit.Persistence');

// ─────────────────────────────────────────────
// Session metadata
// ─────────────────────────────────────────────

class SessionMeta {
  SessionMeta({
    required this.sessionId,
    required this.createdAt,
    required this.lastActiveAt,
    this.title,
    this.model,
    this.turnCount = 0,
  });

  final String sessionId;
  DateTime createdAt;
  DateTime lastActiveAt;
  String? title; // auto-generated from first message
  String? model;
  int turnCount;

  Map<String, dynamic> toMap() => {
        'sessionId': sessionId,
        'createdAt': createdAt.toIso8601String(),
        'lastActiveAt': lastActiveAt.toIso8601String(),
        if (title != null) 'title': title,
        if (model != null) 'model': model,
        'turnCount': turnCount,
      };

  factory SessionMeta.fromMap(Map<String, dynamic> m) => SessionMeta(
        sessionId: m['sessionId'] as String,
        createdAt: DateTime.parse(m['createdAt'] as String),
        lastActiveAt: DateTime.parse(m['lastActiveAt'] as String),
        title: m['title'] as String?,
        model: m['model'] as String?,
        turnCount: m['turnCount'] as int? ?? 0,
      );
}

// ─────────────────────────────────────────────
// Persistence config
// ─────────────────────────────────────────────

class PersistenceConfig {
  const PersistenceConfig({
    this.enabled = true,
    this.boxName = 'agent_sessions',
    this.metaBoxName = 'agent_session_meta',
    this.maxTurnsPerSession = 200,
    this.maxSessions = 50,
    this.persistUIResponses = true,
    this.persistVariables = false,
  });

  final bool enabled;
  final String boxName;
  final String metaBoxName;
  final int maxTurnsPerSession;
  final int maxSessions;

  /// Store the full UIResponse JSON per turn (may be large).
  final bool persistUIResponses;

  /// Store variable store snapshots per turn.
  final bool persistVariables;
}

// ─────────────────────────────────────────────
// Persisted turn
// ─────────────────────────────────────────────

class PersistedTurn {
  const PersistedTurn({
    required this.id,
    required this.role,
    required this.content,
    required this.timestamp,
    this.uiResponseJson,
    this.variableSnapshot,
    this.toolCallSummary,
  });

  final String id;
  final String role;
  final String content;
  final DateTime timestamp;
  final String? uiResponseJson;
  final Map<String, dynamic>? variableSnapshot;
  final String? toolCallSummary;

  ConversationTurn toConversationTurn() {
    AgentUIResponse? uiResponse;
    if (uiResponseJson != null) {
      try {
        uiResponse = AgentUIResponse.fromJsonString(uiResponseJson!);
      } catch (_) {}
    }
    return ConversationTurn(
      id: id,
      role: role,
      content: content,
      uiResponse: uiResponse,
      timestamp: timestamp,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'role': role,
        'content': content,
        'timestamp': timestamp.toIso8601String(),
        if (uiResponseJson != null) 'uiResponseJson': uiResponseJson,
        if (variableSnapshot != null) 'variableSnapshot': variableSnapshot,
        if (toolCallSummary != null) 'toolCallSummary': toolCallSummary,
      };

  factory PersistedTurn.fromMap(Map<String, dynamic> m) => PersistedTurn(
        id: m['id'] as String,
        role: m['role'] as String,
        content: m['content'] as String,
        timestamp: DateTime.parse(m['timestamp'] as String),
        uiResponseJson: m['uiResponseJson'] as String?,
        variableSnapshot: m['variableSnapshot'] != null
            ? Map<String, dynamic>.from(m['variableSnapshot'] as Map)
            : null,
        toolCallSummary: m['toolCallSummary'] as String?,
      );

  factory PersistedTurn.fromConversationTurn(
    ConversationTurn turn, {
    bool persistUI = true,
    Map<String, dynamic>? variables,
  }) =>
      PersistedTurn(
        id: turn.id,
        role: turn.role,
        content: turn.content,
        timestamp: turn.timestamp ?? DateTime.now(),
        uiResponseJson: persistUI ? turn.uiResponse?.toJsonString() : null,
        variableSnapshot: variables,
        toolCallSummary: turn.toolCalls.isNotEmpty
            ? turn.toolCalls.map((t) => t.name).join(', ')
            : null,
      );
}

// ─────────────────────────────────────────────
// Session store
// ─────────────────────────────────────────────

class SessionPersistenceStore {
  SessionPersistenceStore({this.config = const PersistenceConfig()});

  final PersistenceConfig config;
  Box<String>? _turnsBox;
  Box<String>? _metaBox;

  Future<void> init() async {
    if (!config.enabled) return;
    _turnsBox = await Hive.openBox<String>(config.boxName);
    _metaBox = await Hive.openBox<String>(config.metaBoxName);
    _log.info(
      'Persistence opened: ${_turnsBox!.length} stored turn keys, '
      '${_metaBox!.length} sessions',
    );
  }

  Future<void> _ensureOpen() async {
    if (_turnsBox == null) await init();
  }

  // ── Save turn ─────────────────────────────────

  Future<void> saveTurn(
    String sessionId,
    ConversationTurn turn, {
    Map<String, dynamic>? variables,
  }) async {
    if (!config.enabled) return;
    await _ensureOpen();

    final persisted = PersistedTurn.fromConversationTurn(
      turn,
      persistUI: config.persistUIResponses,
      variables: config.persistVariables ? variables : null,
    );

    final key = '${sessionId}__${turn.id}';
    await _turnsBox!.put(key, json.encode(persisted.toMap()));

    await _updateMeta(sessionId, turn);
    await _pruneIfNeeded(sessionId);
  }

  Future<void> saveTurns(
    String sessionId,
    List<ConversationTurn> turns, {
    Map<String, dynamic>? variables,
  }) async {
    for (final turn in turns) {
      await saveTurn(sessionId, turn, variables: variables);
    }
  }

  // ── Load turns ────────────────────────────────

  Future<List<ConversationTurn>> loadTurns(String sessionId) async {
    if (!config.enabled) return [];
    await _ensureOpen();

    final prefix = '${sessionId}__';
    final keys = _turnsBox!.keys
        .whereType<String>()
        .where((k) => k.startsWith(prefix))
        .toList()
      ..sort();

    final turns = <ConversationTurn>[];
    for (final key in keys) {
      final raw = _turnsBox!.get(key);
      if (raw == null) continue;
      try {
        final map = Map<String, dynamic>.from(json.decode(raw) as Map);
        turns.add(PersistedTurn.fromMap(map).toConversationTurn());
      } catch (e) {
        _log.warning('Failed to deserialize turn $key: $e');
      }
    }

    // Respect rolling window
    if (turns.length > config.maxTurnsPerSession) {
      return turns.sublist(turns.length - config.maxTurnsPerSession);
    }

    _log.fine('Loaded ${turns.length} turns for session $sessionId');
    return turns;
  }

  // ── Session list ──────────────────────────────

  Future<List<SessionMeta>> listSessions() async {
    if (!config.enabled) return [];
    await _ensureOpen();

    final metas = <SessionMeta>[];
    for (final key in _metaBox!.keys) {
      final raw = _metaBox!.get(key as String);
      if (raw == null) continue;
      try {
        metas.add(
          SessionMeta.fromMap(
            Map<String, dynamic>.from(json.decode(raw) as Map),
          ),
        );
      } catch (_) {}
    }

    metas.sort((a, b) => b.lastActiveAt.compareTo(a.lastActiveAt));
    return metas;
  }

  Future<SessionMeta?> getSession(String sessionId) async {
    await _ensureOpen();
    final raw = _metaBox!.get(sessionId);
    if (raw == null) return null;
    return SessionMeta.fromMap(
      Map<String, dynamic>.from(json.decode(raw) as Map),
    );
  }

  // ── Delete ────────────────────────────────────

  Future<void> deleteSession(String sessionId) async {
    if (!config.enabled) return;
    await _ensureOpen();

    final prefix = '${sessionId}__';
    final keys = _turnsBox!.keys
        .whereType<String>()
        .where((k) => k.startsWith(prefix))
        .toList();
    await _turnsBox!.deleteAll(keys);
    await _metaBox!.delete(sessionId);
    _log.info('Deleted session $sessionId (${keys.length} turns)');
  }

  Future<void> deleteAllSessions() async {
    if (!config.enabled) return;
    await _ensureOpen();
    await _turnsBox!.clear();
    await _metaBox!.clear();
    _log.info('All sessions deleted');
  }

  // ── Export ────────────────────────────────────

  Future<Map<String, dynamic>> exportSession(String sessionId) async {
    final meta = await getSession(sessionId);
    final turns = await loadTurns(sessionId);

    return {
      'sessionId': sessionId,
      'meta': meta?.toMap(),
      'turns': turns
          .map(
            (t) => {
              'id': t.id,
              'role': t.role,
              'content': t.content,
              'timestamp': t.timestamp?.toIso8601String(),
            },
          )
          .toList(),
      'exportedAt': DateTime.now().toIso8601String(),
    };
  }

  String exportSessionAsJson(Map<String, dynamic> exported) =>
      const JsonEncoder.withIndent('  ').convert(exported);

  // ── Internals ─────────────────────────────────

  Future<void> _updateMeta(String sessionId, ConversationTurn turn) async {
    final existing = await getSession(sessionId);
    final now = DateTime.now();

    // Auto-title from first user message
    String? title = existing?.title;
    if (title == null && turn.role == 'user') {
      final msg = turn.content.trim();
      title = msg.length > 40 ? '${msg.substring(0, 40)}…' : msg;
    }

    final meta = SessionMeta(
      sessionId: sessionId,
      createdAt: existing?.createdAt ?? now,
      lastActiveAt: now,
      title: title,
      turnCount: (existing?.turnCount ?? 0) + 1,
    );

    await _metaBox!.put(sessionId, json.encode(meta.toMap()));
  }

  Future<void> _pruneIfNeeded(String sessionId) async {
    final prefix = '${sessionId}__';
    final keys = _turnsBox!.keys
        .whereType<String>()
        .where((k) => k.startsWith(prefix))
        .toList()
      ..sort();

    if (keys.length > config.maxTurnsPerSession) {
      final toDelete = keys.sublist(0, keys.length - config.maxTurnsPerSession);
      await _turnsBox!.deleteAll(toDelete);
      _log.fine('Pruned ${toDelete.length} old turns from session $sessionId');
    }

    // Also prune total sessions if needed
    final sessions = await listSessions();
    if (sessions.length > config.maxSessions) {
      final toRemove = sessions.sublist(config.maxSessions);
      for (final s in toRemove) {
        await deleteSession(s.sessionId);
      }
    }
  }

  Future<void> close() async {
    await _turnsBox?.close();
    await _metaBox?.close();
  }
}

// ─────────────────────────────────────────────
// Riverpod provider
// ─────────────────────────────────────────────

final sessionPersistenceProvider = Provider<SessionPersistenceStore>((ref) {
  return SessionPersistenceStore();
});
