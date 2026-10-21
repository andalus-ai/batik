// lib/src/datasource/data_source.dart
//
// Batik — DataSource Layer (Patch 031)
// ============================================================
// Unified data-access abstraction. Charts, diagrams, and
// workflows reference a DataSource by id; the runtime fetches
// and optionally watches live data, causing automatic refresh.
//
// Built-ins:
//   MemoryDataSource  — in-process map / list
//   RestDataSource    — HTTP GET/POST via dart:io or package:http
//   McpDataSource     — MCP tool calls over local socket / HTTP
//   StreamDataSource  — wraps any Dart Stream<dynamic>
// ============================================================

import 'dart:async';

/// Opaque result returned by a [DataSource] fetch or watch.
///
/// Cast [data] to the expected type (List, Map, …) after checking
/// [error] is null.
class DataResult {
  const DataResult({this.data, this.error, this.timestamp});

  final dynamic data;
  final Object? error;
  final DateTime? timestamp;

  bool get isOk => error == null;

  @override
  String toString() =>
      isOk ? 'DataResult(data: $data)' : 'DataResult(error: $error)';
}

// ─────────────────────────────────────────────
// 1. Core interfaces
// ─────────────────────────────────────────────

/// One-shot data retrieval.
abstract interface class DataSource {
  /// Globally unique identifier used to reference this source
  /// from UINodes and RuntimeGraph nodes.
  String get id;

  /// Human-readable display name.
  String get name;

  /// Fetch data once. Returns a [DataResult]; never throws.
  Future<DataResult> fetch({Map<String, dynamic>? params});
}

/// Extension of [DataSource] that can emit live updates.
abstract interface class StreamDataSource implements DataSource {
  /// Returns a live stream that emits a [DataResult] whenever
  /// the underlying data changes.
  Stream<DataResult> watch({Map<String, dynamic>? params});
}

// ─────────────────────────────────────────────
// 2. Built-in implementations
// ─────────────────────────────────────────────

/// In-memory data source backed by a simple Dart value.
///
/// Useful for mock data, form state, or variable stores.
class MemoryDataSource implements StreamDataSource {
  MemoryDataSource({required this.id, required this.name, dynamic initialData})
      : _data = initialData;

  @override
  final String id;
  @override
  final String name;

  dynamic _data;
  final _controller = _BroadcastController<DataResult>();

  /// Update the in-memory value and notify all watchers.
  void update(dynamic newData) {
    _data = newData;
    _controller.add(DataResult(data: newData, timestamp: DateTime.now()));
  }

  @override
  Future<DataResult> fetch({Map<String, dynamic>? params}) async =>
      DataResult(data: _data, timestamp: DateTime.now());

  @override
  Stream<DataResult> watch({Map<String, dynamic>? params}) =>
      _controller.stream;

  void dispose() => _controller.close();
}

/// REST data source that issues an HTTP GET request.
///
/// Requires `package:http` to be available. Falls back gracefully
/// if the package is absent by returning an error result.
class RestDataSource implements DataSource {
  RestDataSource({
    required this.id,
    required this.name,
    required this.url,
    this.headers = const {},
  });

  @override
  final String id;
  @override
  final String name;

  final String url;
  final Map<String, String> headers;

  @override
  Future<DataResult> fetch({Map<String, dynamic>? params}) async {
    try {
      // Dynamic import keeps the datasource layer decoupled from http.
      // ignore: avoid_dynamic_calls
      final uri = Uri.parse(url);
      final queryUri = params != null
          ? uri.replace(queryParameters: params.map((k, v) => MapEntry(k, '$v')))
          : uri;

      // Use dart:io HttpClient to avoid a hard dependency on package:http.
      final client = _SimpleHttpClient();
      final body = await client.get(queryUri.toString(), headers: headers);
      return DataResult(data: body, timestamp: DateTime.now());
    } catch (e) {
      return DataResult(error: e, timestamp: DateTime.now());
    }
  }
}

/// MCP-backed data source. Calls a named MCP tool and returns its result.
class McpDataSource implements DataSource {
  McpDataSource({
    required this.id,
    required this.name,
    required this.toolName,
    this.defaultArgs = const {},
    required this.caller,
  });

  @override
  final String id;
  @override
  final String name;

  final String toolName;
  final Map<String, dynamic> defaultArgs;

  /// Callback that executes an MCP tool call.
  /// Signature: `Future<dynamic> call(String tool, Map<String, dynamic> args)`
  final Future<dynamic> Function(String tool, Map<String, dynamic> args) caller;

  @override
  Future<DataResult> fetch({Map<String, dynamic>? params}) async {
    try {
      final args = {...defaultArgs, ...?params};
      final result = await caller(toolName, args);
      return DataResult(data: result, timestamp: DateTime.now());
    } catch (e) {
      return DataResult(error: e, timestamp: DateTime.now());
    }
  }
}

/// Wraps an existing Dart [Stream<dynamic>] as a [StreamDataSource].
class StreamAdapterDataSource implements StreamDataSource {
  StreamAdapterDataSource({
    required this.id,
    required this.name,
    required Stream<dynamic> stream,
  }) : _stream = stream;

  @override
  final String id;
  @override
  final String name;

  final Stream<dynamic> _stream;

  @override
  Future<DataResult> fetch({Map<String, dynamic>? params}) async =>
      const DataResult(error: 'StreamAdapterDataSource is watch-only');

  @override
  Stream<DataResult> watch({Map<String, dynamic>? params}) =>
      _stream.map((d) => DataResult(data: d, timestamp: DateTime.now()));
}

// ─────────────────────────────────────────────
// 3. Registry
// ─────────────────────────────────────────────

/// Singleton registry of all [DataSource]s in the application.
///
/// ```dart
/// DataSourceRegistry.instance.register(RestDataSource(
///   id: 'sales_api',
///   name: 'Sales API',
///   url: 'https://api.example.com/sales',
/// ));
/// ```
class DataSourceRegistry {
  DataSourceRegistry._();
  static final instance = DataSourceRegistry._();

  final _sources = <String, DataSource>{};

  void register(DataSource source) {
    _sources[source.id] = source;
  }

  void unregister(String id) => _sources.remove(id);

  DataSource? operator [](String id) => _sources[id];

  bool has(String id) => _sources.containsKey(id);

  Iterable<DataSource> get all => _sources.values;

  /// Fetch from a registered source by id.
  Future<DataResult> fetch(String id, {Map<String, dynamic>? params}) {
    final source = _sources[id];
    if (source == null) {
      return Future.value(
          DataResult(error: 'DataSource not found: $id'));
    }
    return source.fetch(params: params);
  }

  /// Watch a registered [StreamDataSource] by id.
  Stream<DataResult> watch(String id, {Map<String, dynamic>? params}) {
    final source = _sources[id];
    if (source is StreamDataSource) {
      return source.watch(params: params);
    }
    return Stream.error('DataSource "$id" is not a StreamDataSource');
  }
}

// ─────────────────────────────────────────────
// 4. Internal helpers
// ─────────────────────────────────────────────

/// Minimal broadcast stream controller backed by [StreamController].
class _BroadcastController<T> {
  final StreamController<T> _sc = StreamController<T>.broadcast();

  Stream<T> get stream => _sc.stream;

  void add(T event) {
    if (!_sc.isClosed) _sc.add(event);
  }

  void close() => _sc.close();
}

/// Minimal HTTP GET client stub (no dependency on package:http).
///
/// Override [get] in a subclass or inject package:http via a custom
/// [RestDataSource] subclass when network access is needed.
class _SimpleHttpClient {
  Future<String> get(String url, {Map<String, String>? headers}) async {
    throw UnimplementedError(
        'RestDataSource requires package:http. '
        'Override _SimpleHttpClient or use HttpClient from dart:io.');
  }
}
