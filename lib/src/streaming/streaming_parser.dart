// lib/src/streaming/streaming_parser.dart
//
// AgentUIKit v2 — Streaming JSON Parser
// ============================================================
// Parses LLM token streams incrementally into UINode trees.
// Emits partial trees progressively so the UI renders as the
// agent responds — not just when the full response arrives.
//
// Strategy:
//  1. Buffer incoming chunks
//  2. Detect JSON boundaries via brace depth tracking
//  3. Attempt partial-tree extraction at safe points
//  4. Emit StreamingUIEvent: Partial | Complete | Text | Error
// ============================================================

import 'dart:async';
import 'dart:convert';
import '../schema/ui_schema.dart';

// ─────────────────────────────────────────────
// Stream events
// ─────────────────────────────────────────────

sealed class StreamingUIEvent {}

/// A partial/complete UI tree — rendered progressively.
class StreamingUITree extends StreamingUIEvent {
  StreamingUITree({
    required this.response,
    required this.isComplete,
    this.progress = 0.0,
  });
  final AgentUIResponse response;
  final bool isComplete;
  final double progress; // 0.0–1.0 estimate
}

/// Raw text chunk (for non-UI parts of the response).
class StreamingUIText extends StreamingUIEvent {
  StreamingUIText(this.text);
  final String text;
}

/// Thinking/tool-use status update from the agent.
class StreamingUIStatus extends StreamingUIEvent {
  StreamingUIStatus({required this.status, this.detail});
  final StreamingStatus status;
  final String? detail;
}

enum StreamingStatus {
  thinking,
  callingTool,
  processingResult,
  generating,
  done,
}

/// Terminal error.
class StreamingUIError extends StreamingUIEvent {
  StreamingUIError({required this.error, this.isRecoverable = false});
  final Object error;
  final bool isRecoverable;
}

// ─────────────────────────────────────────────
// Streaming parser
// ─────────────────────────────────────────────

class StreamingUIParser {
  StreamingUIParser({this.schemaVersion = '2.0.0'});

  final String schemaVersion;

  final _buffer = StringBuffer();
  int _braceDepth = 0;
  bool _inString = false;
  bool _escape = false;
  bool _jsonStarted = false;
  int _jsonStart = -1;
  AgentUIResponse? _lastValidTree;

  final _controller = StreamController<StreamingUIEvent>.broadcast();
  Stream<StreamingUIEvent> get events => _controller.stream;

  // ── Feed raw chunks ───────────────────────────

  void addChunk(String chunk) {
    _buffer.write(chunk);
    _scan(chunk);
  }

  void addChunks(Stream<String> stream) {
    stream.listen(
      addChunk,
      onError: (e) =>
          _controller.add(StreamingUIError(error: e, isRecoverable: false)),
      onDone: finalize,
    );
  }

  /// Call when the stream is complete.
  void finalize() {
    final raw = _buffer.toString();
    final tree = _tryExtractComplete(raw);
    if (tree != null) {
      _controller.add(
        StreamingUITree(response: tree, isComplete: true, progress: 1.0),
      );
    } else if (_lastValidTree != null) {
      _controller.add(
        StreamingUITree(
          response: _lastValidTree!,
          isComplete: true,
          progress: 1.0,
        ),
      );
    }
    _controller.add(StreamingUIStatus(status: StreamingStatus.done));
    _controller.close();
  }

  void close() {
    if (!_controller.isClosed) _controller.close();
  }

  // ── Scanning logic ────────────────────────────

  void _scan(String newChunk) {
    final raw = _buffer.toString();

    // Find start of JSON if not yet found
    if (!_jsonStarted) {
      final idx = raw.indexOf('{');
      if (idx >= 0) {
        _jsonStarted = true;
        _jsonStart = idx;
        // Emit any text before the JSON starts
        if (idx > 0) {
          _controller.add(StreamingUIText(raw.substring(0, idx)));
        }
      } else {
        // All text so far, no JSON
        _controller.add(StreamingUIText(newChunk));
        return;
      }
    }

    // Track brace depth
    for (var i = raw.length - newChunk.length; i < raw.length; i++) {
      final ch = raw[i];
      if (_escape) {
        _escape = false;
        continue;
      }
      if (ch == '\\' && _inString) {
        _escape = true;
        continue;
      }
      if (ch == '"') {
        _inString = !_inString;
        continue;
      }
      if (_inString) continue;
      if (ch == '{') _braceDepth++;
      if (ch == '}') {
        _braceDepth--;
        if (_braceDepth == 0 && _jsonStart >= 0) {
          // We have a complete JSON candidate
          final candidate = raw.substring(_jsonStart, i + 1);
          final tree = _tryExtractComplete(candidate);
          if (tree != null) {
            _lastValidTree = tree;
            _controller.add(
              StreamingUITree(response: tree, isComplete: true, progress: 1.0),
            );
          }
          return;
        }
      }
    }

    // Try to emit a partial tree at safe points (every ~200 chars of JSON)
    if (_jsonStarted && raw.length % 200 < newChunk.length) {
      _tryEmitPartial(raw);
    }
  }

  void _tryEmitPartial(String raw) {
    final jsonPart = _jsonStart >= 0 ? raw.substring(_jsonStart) : raw;
    final partial = _tryRepairAndParse(jsonPart);
    if (partial != null && partial != _lastValidTree) {
      _lastValidTree = partial;
      _controller.add(
        StreamingUITree(
          response: partial,
          isComplete: false,
          progress: _estimateProgress(jsonPart),
        ),
      );
    }
  }

  // ── JSON repair & extraction ──────────────────

  AgentUIResponse? _tryExtractComplete(String raw) {
    // 1. Direct parse
    final direct = _tryParse(raw);
    if (direct != null) return direct;

    // 2. Extract from markdown code block
    final md = _extractFromMarkdown(raw);
    if (md != null) return md;

    // 3. Attempt repair
    return _tryRepairAndParse(raw);
  }

  AgentUIResponse? _tryParse(String raw) {
    try {
      final j = json.decode(raw.trim()) as Map<String, dynamic>;
      return _buildResponse(j);
    } catch (_) {
      return null;
    }
  }

  AgentUIResponse? _extractFromMarkdown(String raw) {
    final pattern = RegExp(r'```(?:json)?\s*(\{[\s\S]*?\})\s*```');
    for (final match in pattern.allMatches(raw)) {
      final candidate = match.group(1);
      if (candidate != null) {
        final result = _tryParse(candidate);
        if (result != null) return result;
      }
    }
    return null;
  }

  /// Attempt to close open braces/brackets and parse the result.
  AgentUIResponse? _tryRepairAndParse(String raw) {
    final start = raw.indexOf('{');
    if (start < 0) return null;

    var candidate = raw.substring(start);

    // Count open structures
    int braces = 0, brackets = 0;
    bool inStr = false, esc = false;

    for (final ch in candidate.runes) {
      final c = String.fromCharCode(ch);
      if (esc) {
        esc = false;
        continue;
      }
      if (c == '\\' && inStr) {
        esc = true;
        continue;
      }
      if (c == '"') {
        inStr = !inStr;
        continue;
      }
      if (inStr) continue;
      if (c == '{') braces++;
      if (c == '}') braces--;
      if (c == '[') brackets++;
      if (c == ']') brackets--;
    }

    // Close any open string
    if (inStr) candidate += '"';

    // Close any open arrays
    candidate += ']' * brackets.clamp(0, 20);
    // Close any open objects
    candidate += '}' * braces.clamp(0, 20);

    return _tryParse(candidate);
  }

  AgentUIResponse? _buildResponse(Map<String, dynamic> j) {
    try {
      if (j.containsKey('root')) {
        return AgentUIResponse.fromJson(j);
      }
      if (j.containsKey('type')) {
        return AgentUIResponse(
          schemaVersion: schemaVersion,
          root: UINode.fromJson(j),
        );
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  double _estimateProgress(String jsonSoFar) {
    // Heuristic: ratio of closed to open braces
    int open = 0, closed = 0;
    bool inStr = false;
    for (final ch in jsonSoFar.runes) {
      final c = String.fromCharCode(ch);
      if (c == '"') inStr = !inStr;
      if (inStr) continue;
      if (c == '{') open++;
      if (c == '}') closed++;
    }
    if (open == 0) return 0;
    return (closed / open).clamp(0.0, 0.95);
  }
}

// ─────────────────────────────────────────────
// SSE (Server-Sent Events) reader
// ─────────────────────────────────────────────

/// Parses a raw HTTP stream of SSE data: lines into text chunks.
class SSEReader {
  SSEReader({this.dataPrefix = 'data: '});
  final String dataPrefix;

  Stream<String> parse(Stream<List<int>> byteStream) async* {
    final lines = byteStream
        .transform(utf8.decoder)
        .transform(const LineSplitter());

    await for (final line in lines) {
      if (line.startsWith(dataPrefix)) {
        final data = line.substring(dataPrefix.length).trim();
        if (data == '[DONE]') return;
        yield data;
      }
    }
  }
}

// ─────────────────────────────────────────────
// Anthropic streaming helper
// ─────────────────────────────────────────────

/// Extracts text deltas from Anthropic SSE JSON events.
String? extractAnthropicDelta(String sseData) {
  try {
    final j = json.decode(sseData) as Map<String, dynamic>;
    final type = j['type'] as String?;
    if (type == 'content_block_delta') {
      final delta = j['delta'] as Map<String, dynamic>?;
      if (delta?['type'] == 'text_delta') {
        return delta?['text'] as String?;
      }
    }
    return null;
  } catch (_) {
    return null;
  }
}

/// Extracts text deltas from OpenAI SSE JSON events.
String? extractOpenAIDelta(String sseData) {
  try {
    final j = json.decode(sseData) as Map<String, dynamic>;
    final choices = j['choices'] as List<dynamic>?;
    if (choices == null || choices.isEmpty) return null;
    final delta = choices[0]['delta'] as Map<String, dynamic>?;
    return delta?['content'] as String?;
  } catch (_) {
    return null;
  }
}
