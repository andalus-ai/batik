// lib/src/actions/typed_actions.dart
//
// AgentUIKit v3 — Typed Action Payload Contracts
// ============================================================
// Replaces Map<String, dynamic> with typed, validated payloads.
// LLM hallucinations are caught at the adapter boundary, not
// silently at dispatch time.
//
// Every built-in action type has:
//  • A typed payload class with required/optional fields
//  • A fromJson factory with field validation
//  • A toJson serialiser for system prompt documentation
//  • An associated handler contract
// ============================================================

import 'package:flutter/material.dart';
import '../schema/ui_schema.dart';
import '../core/action_dispatcher.dart';

// ─────────────────────────────────────────────
// Base
// ─────────────────────────────────────────────

abstract class TypedActionPayload {
  const TypedActionPayload();
  Map<String, dynamic> toJson();

  /// Validate this payload. Returns null if valid, error message if not.
  String? validate() => null;
}

class PayloadParseError {
  const PayloadParseError({
    required this.actionType,
    required this.message,
    required this.rawPayload,
  });
  final String actionType;
  final String message;
  final Map<String, dynamic> rawPayload;

  @override
  String toString() =>
      'PayloadParseError[$actionType]: $message — raw: $rawPayload';
}

// ─────────────────────────────────────────────
// Built-in payload types
// ─────────────────────────────────────────────

/// navigate — push a named route.
class NavigatePayload extends TypedActionPayload {
  const NavigatePayload({
    required this.route,
    this.arguments,
    this.replace = false,
    this.clearStack = false,
  });

  final String route;
  final Map<String, dynamic>? arguments;
  final bool replace;
  final bool clearStack;

  factory NavigatePayload.fromJson(Map<String, dynamic> j) {
    final route = j['route'] as String?;
    if (route == null || route.isEmpty) {
      throw PayloadParseError(
        actionType: 'navigate',
        message: 'Missing required field: route',
        rawPayload: j,
      );
    }
    return NavigatePayload(
      route: route,
      arguments: j['arguments'] as Map<String, dynamic>?,
      replace: j['replace'] as bool? ?? false,
      clearStack: j['clearStack'] as bool? ?? false,
    );
  }

  @override
  String? validate() {
    if (route.isEmpty) return 'route must not be empty';
    if (!route.startsWith('/') && !route.contains('.')) {
      return 'route should be a path (/screen) or named route (ScreenName)';
    }
    return null;
  }

  @override
  Map<String, dynamic> toJson() => {
        'route': route,
        if (arguments != null) 'arguments': arguments,
        if (replace) 'replace': replace,
        if (clearStack) 'clearStack': clearStack,
      };
}

/// agentMessage — send a user message back to the agent.
class AgentMessagePayload extends TypedActionPayload {
  const AgentMessagePayload({
    required this.message,
    this.silent = false,
    this.metadata,
  });

  final String message;

  /// If true, don't show the message in the chat UI.
  final bool silent;
  final Map<String, dynamic>? metadata;

  factory AgentMessagePayload.fromJson(Map<String, dynamic> j) {
    final msg = j['message'] as String?;
    if (msg == null || msg.isEmpty) {
      throw PayloadParseError(
        actionType: 'agentMessage',
        message: 'Missing required field: message',
        rawPayload: j,
      );
    }
    return AgentMessagePayload(
      message: msg,
      silent: j['silent'] as bool? ?? false,
      metadata: j['metadata'] as Map<String, dynamic>?,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'message': message,
        if (silent) 'silent': silent,
        if (metadata != null) 'metadata': metadata,
      };
}

/// setVariable — write to the VariableStore.
class SetVariablePayload extends TypedActionPayload {
  const SetVariablePayload({
    required this.key,
    required this.value,
    this.scope = VariableScope.session,
  });

  final String key;
  final dynamic value;
  final VariableScope scope;

  factory SetVariablePayload.fromJson(Map<String, dynamic> j) {
    final key = j['key'] as String?;
    if (key == null || key.isEmpty) {
      throw PayloadParseError(
        actionType: 'setVariable',
        message: 'Missing required field: key',
        rawPayload: j,
      );
    }
    if (!j.containsKey('value')) {
      throw PayloadParseError(
        actionType: 'setVariable',
        message: 'Missing required field: value',
        rawPayload: j,
      );
    }
    return SetVariablePayload(
      key: key,
      value: j['value'],
      scope: VariableScope.values.firstWhere(
        (s) => s.name == (j['scope'] as String? ?? 'session'),
        orElse: () => VariableScope.session,
      ),
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'key': key,
        'value': value,
        'scope': scope.name,
      };
}

enum VariableScope {
  /// Lives for the current render turn only.
  turn,

  /// Lives for the session (default).
  session,

  /// Persisted across sessions.
  persistent,
}

/// openUrl — open an external URL.
class OpenUrlPayload extends TypedActionPayload {
  const OpenUrlPayload({
    required this.url,
    this.target = UrlTarget.external,
    this.title,
  });

  final String url;
  final UrlTarget target;
  final String? title;

  factory OpenUrlPayload.fromJson(Map<String, dynamic> j) {
    final url = j['url'] as String?;
    if (url == null || url.isEmpty) {
      throw PayloadParseError(
        actionType: 'openUrl',
        message: 'Missing required field: url',
        rawPayload: j,
      );
    }
    if (url.toLowerCase().startsWith('javascript:')) {
      throw PayloadParseError(
        actionType: 'openUrl',
        message: 'javascript: URLs are not permitted',
        rawPayload: j,
      );
    }
    return OpenUrlPayload(
      url: url,
      target: UrlTarget.values.firstWhere(
        (t) => t.name == (j['target'] as String? ?? 'external'),
        orElse: () => UrlTarget.external,
      ),
      title: j['title'] as String?,
    );
  }

  @override
  String? validate() {
    if (!url.startsWith('https://') && !url.startsWith('http://')) {
      return 'URL must start with https:// or http://';
    }
    return null;
  }

  @override
  Map<String, dynamic> toJson() => {
        'url': url,
        'target': target.name,
        if (title != null) 'title': title,
      };
}

enum UrlTarget { external, inApp, download }

/// submitForm — collect and submit all bound variables.
class SubmitFormPayload extends TypedActionPayload {
  const SubmitFormPayload({
    required this.formId,
    this.endpoint,
    this.method = 'POST',
    this.includeVariables,
  });

  final String formId;
  final String? endpoint;
  final String method;
  final List<String>? includeVariables;

  factory SubmitFormPayload.fromJson(Map<String, dynamic> j) {
    final formId = j['formId'] as String?;
    if (formId == null || formId.isEmpty) {
      throw PayloadParseError(
        actionType: 'submitForm',
        message: 'Missing required field: formId',
        rawPayload: j,
      );
    }
    return SubmitFormPayload(
      formId: formId,
      endpoint: j['endpoint'] as String?,
      method: j['method'] as String? ?? 'POST',
      includeVariables:
          (j['includeVariables'] as List<dynamic>?)?.cast<String>(),
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'formId': formId,
        if (endpoint != null) 'endpoint': endpoint,
        'method': method,
        if (includeVariables != null) 'includeVariables': includeVariables,
      };
}

/// dismiss — close a dialog, sheet, or overlay.
class DismissPayload extends TypedActionPayload {
  const DismissPayload({this.result, this.targetId});

  final dynamic result;
  final String? targetId;

  factory DismissPayload.fromJson(Map<String, dynamic> j) =>
      DismissPayload(result: j['result'], targetId: j['targetId'] as String?);

  @override
  Map<String, dynamic> toJson() => {
        if (result != null) 'result': result,
        if (targetId != null) 'targetId': targetId,
      };
}

/// showSnackbar — programmatic snackbar from action.
class ShowSnackbarPayload extends TypedActionPayload {
  const ShowSnackbarPayload({
    required this.message,
    this.actionLabel,
    this.actionKey,
    this.duration = const Duration(seconds: 4),
    this.type = SnackbarType.info,
  });

  final String message;
  final String? actionLabel;
  final String? actionKey;
  final Duration duration;
  final SnackbarType type;

  factory ShowSnackbarPayload.fromJson(Map<String, dynamic> j) {
    final msg = j['message'] as String?;
    if (msg == null || msg.isEmpty) {
      throw PayloadParseError(
        actionType: 'showSnackbar',
        message: 'Missing required field: message',
        rawPayload: j,
      );
    }
    return ShowSnackbarPayload(
      message: msg,
      actionLabel: j['actionLabel'] as String?,
      actionKey: j['actionKey'] as String?,
      duration: Duration(milliseconds: j['durationMs'] as int? ?? 4000),
      type: SnackbarType.values.firstWhere(
        (t) => t.name == (j['type'] as String? ?? 'info'),
        orElse: () => SnackbarType.info,
      ),
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'message': message,
        if (actionLabel != null) 'actionLabel': actionLabel,
        if (actionKey != null) 'actionKey': actionKey,
        'durationMs': duration.inMilliseconds,
        'type': type.name,
      };
}

enum SnackbarType { info, success, warning, error }

// ─────────────────────────────────────────────
// Payload registry & parser
// ─────────────────────────────────────────────

class ActionPayloadParser {
  static const _builtinParsers =
      <String, TypedActionPayload Function(Map<String, dynamic>)>{
    'navigate': NavigatePayload.fromJson,
    'agentMessage': AgentMessagePayload.fromJson,
    'setVariable': SetVariablePayload.fromJson,
    'openUrl': OpenUrlPayload.fromJson,
    'submitForm': SubmitFormPayload.fromJson,
    'dismiss': DismissPayload.fromJson,
    'showSnackbar': ShowSnackbarPayload.fromJson,
  };

  final _customParsers =
      <String, TypedActionPayload Function(Map<String, dynamic>)>{};

  void register(
    String type,
    TypedActionPayload Function(Map<String, dynamic>) parser,
  ) {
    _customParsers[type] = parser;
  }

  /// Parse and validate an action payload.
  /// Returns typed payload or throws [PayloadParseError].
  TypedActionPayload parse(String actionType, Map<String, dynamic> raw) {
    final parser = _customParsers[actionType] ?? _builtinParsers[actionType];

    if (parser == null) {
      // Unknown action — wrap raw map
      return _RawPayload(actionType, raw);
    }

    final payload = parser(raw);
    final validationError = payload.validate();
    if (validationError != null) {
      throw PayloadParseError(
        actionType: actionType,
        message: validationError,
        rawPayload: raw,
      );
    }

    return payload;
  }

  TypedActionPayload? tryParse(String actionType, Map<String, dynamic> raw) {
    try {
      return parse(actionType, raw);
    } on PayloadParseError {
      return null;
    }
  }

  /// Generates the action contract documentation for the system prompt.
  String toSystemPromptSection() => '''
## Action Types

Available UI actions (use exact field names):

navigate: {"route": "/screen"[, "arguments": {}, "replace": bool, "clearStack": bool]}
agentMessage: {"message": "text"[, "silent": bool]}
setVariable: {"key": "name", "value": any[, "scope": "session|turn|persistent"]}
openUrl: {"url": "https://..."[, "target": "external|inApp|download"]}
submitForm: {"formId": "id"[, "endpoint": "url", "method": "POST"]}
dismiss: {["result": any, "targetId": "id"]}
showSnackbar: {"message": "text"[, "type": "info|success|warning|error", "actionLabel": "Undo"]}
custom: {"name": "yourEvent", ...anyFields}

All actions go in the node's "actions" map, e.g.:
"actions": {"onTap": {"type": "navigate", "payload": {"route": "/home"}}}
''';
}

class _RawPayload extends TypedActionPayload {
  const _RawPayload(this.type, this.raw);
  final String type;
  final Map<String, dynamic> raw;

  @override
  Map<String, dynamic> toJson() => raw;
}

// ─────────────────────────────────────────────
// Typed action handler
// ─────────────────────────────────────────────

/// Handler that receives typed payloads. Implement this instead of
/// the raw ActionHandler for type-safe action handling.
abstract class TypedActionHandler {
  const TypedActionHandler();

  Future<void> onNavigate(BuildContext ctx, NavigatePayload p) async {}
  Future<void> onAgentMessage(
    BuildContext ctx,
    AgentMessagePayload p,
    Map<String, dynamic> vars,
  ) async {}
  Future<void> onSetVariable(BuildContext ctx, SetVariablePayload p) async {}
  Future<void> onOpenUrl(BuildContext ctx, OpenUrlPayload p) async {}
  Future<void> onSubmitForm(
    BuildContext ctx,
    SubmitFormPayload p,
    Map<String, dynamic> vars,
  ) async {}
  Future<void> onDismiss(BuildContext ctx, DismissPayload p) async {}
  Future<void> onShowSnackbar(BuildContext ctx, ShowSnackbarPayload p) async {}
  Future<void> onCustom(
    BuildContext ctx,
    String actionType,
    Map<String, dynamic> payload,
    Map<String, dynamic> vars,
  ) async {}
}

/// Bridges the raw ActionHandler interface to TypedActionHandler.
class TypedActionHandlerBridge implements ActionHandler {
  TypedActionHandlerBridge({
    required this.typedHandler,
    ActionPayloadParser? parser,
  }) : _parser = parser ?? ActionPayloadParser();

  final TypedActionHandler typedHandler;
  final ActionPayloadParser _parser;

  @override
  Future<void> handle(
    BuildContext context,
    UIAction action,
    Map<String, dynamic> variables,
  ) async {
    TypedActionPayload payload;
    try {
      payload = _parser.parse(action.type, action.payload);
    } on PayloadParseError catch (e) {
      debugPrint('[TypedActionHandler] $e');
      payload = _RawPayload(action.type, action.payload);
    }

    switch (payload) {
      case NavigatePayload p:
        await typedHandler.onNavigate(context, p);
      case AgentMessagePayload p:
        await typedHandler.onAgentMessage(context, p, variables);
      case SetVariablePayload p:
        await typedHandler.onSetVariable(context, p);
      case OpenUrlPayload p:
        await typedHandler.onOpenUrl(context, p);
      case SubmitFormPayload p:
        await typedHandler.onSubmitForm(context, p, variables);
      case DismissPayload p:
        await typedHandler.onDismiss(context, p);
      case ShowSnackbarPayload p:
        await typedHandler.onShowSnackbar(context, p);
      default:
        await typedHandler.onCustom(
          context,
          action.type,
          action.payload,
          variables,
        );
    }
  }
}
