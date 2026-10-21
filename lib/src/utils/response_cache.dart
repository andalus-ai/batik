// lib/src/cache/response_cache.dart
//
// AgentUIKit v2 — Offline-First Response Cache
// ============================================================
// Caches agent responses to disk (Hive) so the app works
// offline and repeat queries are instant.
//
// Cache key = SHA-256(prompt + relevant variables + sessionConfig).
// TTL-based invalidation with configurable per-entry overrides.
// LRU eviction when storage limit is reached.
// ============================================================

import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:logging/logging.dart';
import '../schema/ui_schema.dart';

final _log = Logger('AgentUIKit.Cache');

// ─────────────────────────────────────────────
// Cache entry
// ─────────────────────────────────────────────

class CacheEntry {
  CacheEntry({
    required this.key,
    required this.responseJson,
    required this.createdAt,
    required this.expiresAt,
    this.hitCount = 0,
    this.lastAccessedAt,
  });

  final String key;
  final String responseJson; // serialised AgentUIResponse
  DateTime createdAt;
  DateTime expiresAt;
  int hitCount;
  DateTime? lastAccessedAt;

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  AgentUIResponse? get response {
    try {
      return AgentUIResponse.fromJsonString(responseJson);
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> toMap() => {
    'key': key,
    'responseJson': responseJson,
    'createdAt': createdAt.toIso8601String(),
    'expiresAt': expiresAt.toIso8601String(),
    'hitCount': hitCount,
    'lastAccessedAt': lastAccessedAt?.toIso8601String(),
  };

  factory CacheEntry.fromMap(Map<String, dynamic> m) => CacheEntry(
    key: m['key'] as String,
    responseJson: m['responseJson'] as String,
    createdAt: DateTime.parse(m['createdAt'] as String),
    expiresAt: DateTime.parse(m['expiresAt'] as String),
    hitCount: m['hitCount'] as int? ?? 0,
    lastAccessedAt: m['lastAccessedAt'] != null
        ? DateTime.parse(m['lastAccessedAt'] as String)
        : null,
  );
}

// ─────────────────────────────────────────────
// Cache config
// ─────────────────────────────────────────────

class CacheConfig {
  const CacheConfig({
    this.defaultTtl = const Duration(hours: 24),
    this.maxEntries = 500,
    this.maxSizeBytes = 50 * 1024 * 1024, // 50 MB
    this.boxName = 'agent_ui_cache',
    this.variableKeysToIncludeInCacheKey = const [],
    this.enabled = true,
    this.staleWhileRevalidate = false,
  });

  final Duration defaultTtl;
  final int maxEntries;
  final int maxSizeBytes;
  final String boxName;

  /// Only these variable keys affect the cache key.
  /// An empty list means no variables affect the cache key.
  final List<String> variableKeysToIncludeInCacheKey;

  final bool enabled;

  /// If true, return stale data immediately and revalidate in background.
  final bool staleWhileRevalidate;

  static const noCache = CacheConfig(enabled: false);
  static const aggressive = CacheConfig(
    defaultTtl: Duration(days: 7),
    maxEntries: 2000,
    staleWhileRevalidate: true,
  );
}

// ─────────────────────────────────────────────
// Cache stats
// ─────────────────────────────────────────────

class CacheStats {
  const CacheStats({
    required this.hits,
    required this.misses,
    required this.evictions,
    required this.entryCount,
    required this.estimatedSizeBytes,
  });

  final int hits;
  final int misses;
  final int evictions;
  final int entryCount;
  final int estimatedSizeBytes;

  double get hitRate => (hits + misses) == 0 ? 0 : hits / (hits + misses);

  @override
  String toString() =>
      'CacheStats(hits=$hits, misses=$misses, rate=${(hitRate * 100).toStringAsFixed(1)}%, '
      'entries=$entryCount)';
}

// ─────────────────────────────────────────────
// ResponseCache
// ─────────────────────────────────────────────

abstract class ResponseCache {
  Future<AgentUIResponse?> get(String prompt, Map<String, dynamic> variables);
  Future<void> put(
    String prompt,
    Map<String, dynamic> variables,
    AgentUIResponse response, {
    Duration? ttl,
  });
  Future<void> invalidate(String prompt, Map<String, dynamic> variables);
  Future<void> invalidateAll();
  Future<CacheStats> stats();
}

class HiveResponseCache implements ResponseCache {
  HiveResponseCache({this.config = const CacheConfig()});

  final CacheConfig config;
  Box<Map>? _box;

  int _hits = 0;
  int _misses = 0;
  int _evictions = 0;

  Future<void> init() async {
    if (!config.enabled) return;
    await Hive.initFlutter();
    _box = await Hive.openBox<Map>(config.boxName);
    _log.info('Cache opened: ${_box!.length} existing entries');
  }

  Future<void> _ensureOpen() async {
    if (_box == null || !_box!.isOpen) await init();
  }

  // ── Cache key ─────────────────────────────────

  String _buildKey(String prompt, Map<String, dynamic> variables) {
    final relevantVars = <String, dynamic>{};
    for (final key in config.variableKeysToIncludeInCacheKey) {
      if (variables.containsKey(key)) {
        relevantVars[key] = variables[key];
      }
    }

    final payload = '${prompt.trim()}|${json.encode(relevantVars)}';
    return sha256.convert(utf8.encode(payload)).toString();
  }

  // ── Get ───────────────────────────────────────

  @override
  Future<AgentUIResponse?> get(
    String prompt,
    Map<String, dynamic> variables,
  ) async {
    if (!config.enabled) return null;
    await _ensureOpen();

    final key = _buildKey(prompt, variables);
    final raw = _box!.get(key);

    if (raw == null) {
      _misses++;
      _log.fine('Cache MISS: ${key.substring(0, 8)}…');
      return null;
    }

    final entry = CacheEntry.fromMap(Map<String, dynamic>.from(raw));

    if (entry.isExpired && !config.staleWhileRevalidate) {
      _misses++;
      await _box!.delete(key);
      _log.fine('Cache EXPIRED: ${key.substring(0, 8)}…');
      return null;
    }

    // Update hit metadata
    entry.hitCount++;
    entry.lastAccessedAt = DateTime.now();
    await _box!.put(key, entry.toMap());

    _hits++;
    _log.fine('Cache HIT: ${key.substring(0, 8)}… (hits=${entry.hitCount})');

    return entry.response;
  }

  // ── Put ───────────────────────────────────────

  @override
  Future<void> put(
    String prompt,
    Map<String, dynamic> variables,
    AgentUIResponse response, {
    Duration? ttl,
  }) async {
    if (!config.enabled) return;
    await _ensureOpen();

    final key = _buildKey(prompt, variables);
    final now = DateTime.now();
    final effectiveTtl = ttl ?? config.defaultTtl;

    final entry = CacheEntry(
      key: key,
      responseJson: response.toJsonString(),
      createdAt: now,
      expiresAt: now.add(effectiveTtl),
    );

    // Evict if over limit
    if (_box!.length >= config.maxEntries) {
      await _evictLRU();
    }

    await _box!.put(key, entry.toMap());
    _log.fine(
      'Cache PUT: ${key.substring(0, 8)}… (ttl=${effectiveTtl.inMinutes}min)',
    );
  }

  // ── Invalidation ──────────────────────────────

  @override
  Future<void> invalidate(String prompt, Map<String, dynamic> variables) async {
    if (!config.enabled) return;
    await _ensureOpen();
    final key = _buildKey(prompt, variables);
    await _box!.delete(key);
  }

  @override
  Future<void> invalidateAll() async {
    if (!config.enabled) return;
    await _ensureOpen();
    await _box!.clear();
    _log.info('Cache cleared');
  }

  // ── Stats ─────────────────────────────────────

  @override
  Future<CacheStats> stats() async {
    await _ensureOpen();
    int totalSize = 0;
    for (final raw in _box!.values) {
      totalSize += json.encode(raw).length;
    }
    return CacheStats(
      hits: _hits,
      misses: _misses,
      evictions: _evictions,
      entryCount: _box!.length,
      estimatedSizeBytes: totalSize,
    );
  }

  // ── Maintenance ───────────────────────────────

  /// Remove expired entries.
  Future<int> pruneExpired() async {
    await _ensureOpen();
    final expiredKeys = <dynamic>[];
    for (final key in _box!.keys) {
      final raw = _box!.get(key);
      if (raw == null) continue;
      final entry = CacheEntry.fromMap(Map<String, dynamic>.from(raw));
      if (entry.isExpired) expiredKeys.add(key);
    }
    await _box!.deleteAll(expiredKeys);
    _log.info('Pruned ${expiredKeys.length} expired entries');
    return expiredKeys.length;
  }

  Future<void> _evictLRU() async {
    // Find LRU entry (oldest lastAccessedAt or createdAt)
    String? lruKey;
    DateTime? oldest;

    for (final key in _box!.keys) {
      final raw = _box!.get(key);
      if (raw == null) continue;
      final entry = CacheEntry.fromMap(Map<String, dynamic>.from(raw));
      final ts = entry.lastAccessedAt ?? entry.createdAt;
      if (oldest == null || ts.isBefore(oldest)) {
        oldest = ts;
        lruKey = key as String;
      }
    }

    if (lruKey != null) {
      await _box!.delete(lruKey);
      _evictions++;
      _log.fine('Evicted LRU entry: ${lruKey.substring(0, 8)}…');
    }
  }

  Future<void> close() async => _box?.close();
}

// ─────────────────────────────────────────────
// In-memory cache (for tests / no persistence)
// ─────────────────────────────────────────────

class InMemoryResponseCache implements ResponseCache {
  InMemoryResponseCache({this.config = const CacheConfig()});

  final CacheConfig config;
  final _store = <String, CacheEntry>{};
  int _hits = 0, _misses = 0, _evictions = 0;

  String _key(String prompt, Map<String, dynamic> variables) {
    final payload = '${prompt.trim()}|${json.encode(variables)}';
    return sha256.convert(utf8.encode(payload)).toString();
  }

  @override
  Future<AgentUIResponse?> get(
    String prompt,
    Map<String, dynamic> variables,
  ) async {
    if (!config.enabled) return null;
    final key = _key(prompt, variables);
    final entry = _store[key];
    if (entry == null || entry.isExpired) {
      _misses++;
      _store.remove(key);
      return null;
    }
    entry.hitCount++;
    entry.lastAccessedAt = DateTime.now();
    _hits++;
    return entry.response;
  }

  @override
  Future<void> put(
    String prompt,
    Map<String, dynamic> variables,
    AgentUIResponse response, {
    Duration? ttl,
  }) async {
    if (!config.enabled) return;
    if (_store.length >= config.maxEntries) _evictLRU();
    final key = _key(prompt, variables);
    final now = DateTime.now();
    _store[key] = CacheEntry(
      key: key,
      responseJson: response.toJsonString(),
      createdAt: now,
      expiresAt: now.add(ttl ?? config.defaultTtl),
    );
  }

  @override
  Future<void> invalidate(String prompt, Map<String, dynamic> variables) async {
    _store.remove(_key(prompt, variables));
  }

  @override
  Future<void> invalidateAll() async => _store.clear();

  @override
  Future<CacheStats> stats() async => CacheStats(
    hits: _hits,
    misses: _misses,
    evictions: _evictions,
    entryCount: _store.length,
    estimatedSizeBytes: _store.values.fold(
      0,
      (s, e) => s + e.responseJson.length,
    ),
  );

  void _evictLRU() {
    if (_store.isEmpty) return;
    String? lruKey;
    DateTime? oldest;
    for (final entry in _store.entries) {
      final ts = entry.value.lastAccessedAt ?? entry.value.createdAt;
      if (oldest == null || ts.isBefore(oldest)) {
        oldest = ts;
        lruKey = entry.key;
      }
    }
    if (lruKey != null) {
      _store.remove(lruKey);
      _evictions++;
    }
  }
}
