// lib/core/action_dispatcher.dart
//
// AgentUIKit — Action Dispatcher & Variable Store
// ============================================================
// Decouples UI events from business logic.
// Apps implement [ActionHandler] to handle agent-specified actions.
// ============================================================

import 'package:flutter/widgets.dart';
import '../schema/ui_schema.dart';

// ─────────────────────────────────────────────
// Variable Store
// ─────────────────────────────────────────────

/// Holds runtime key-value state that the UI tree can read/write.
/// Used by form fields, switches, sliders, dropdowns, etc.
class VariableStore extends ChangeNotifier {
  final _data = <String, dynamic>{};

  T? get<T>(String key) => _data[key] as T?;

  void set(String key, dynamic value) {
    if (_data[key] == value) return;
    _data[key] = value;
    notifyListeners();
  }

  void remove(String key) {
    _data.remove(key);
    notifyListeners();
  }

  void setMany(Map<String, dynamic> values) {
    _data.addAll(values);
    notifyListeners();
  }

  Map<String, dynamic> snapshot() => Map.unmodifiable(_data);

  void clear() {
    _data.clear();
    notifyListeners();
  }
}

// ─────────────────────────────────────────────
// Condition Resolver
// ─────────────────────────────────────────────

/// Evaluates [UINode.condition] references against the [VariableStore].
class ConditionResolver {
  const ConditionResolver(this._store);

  final VariableStore _store;

  /// Returns true if the node should be shown.
  bool evaluate(String? condition) {
    if (condition == null) return true;
    final val = _store.get<dynamic>(condition);
    if (val == null) return false;
    if (val is bool) return val;
    if (val is String) return val.isNotEmpty;
    if (val is num) return val != 0;
    return true;
  }
}

// ─────────────────────────────────────────────
// Action Types (built-in)
// ─────────────────────────────────────────────

/// Well-known action types. Your [ActionHandler] can extend beyond these.
abstract class ActionTypes {
  static const agentMessage = 'agentMessage';
  static const navigate = 'navigate';
  static const setVariable = 'setVariable';
  static const openUrl = 'openUrl';
  static const dismiss = 'dismiss';
  static const submitForm = 'submitForm';
  static const showDialog = 'showDialog';
  static const showSnackbar = 'showSnackbar';
  static const custom = 'custom';
}

// ─────────────────────────────────────────────
// Action Handler interface
// ─────────────────────────────────────────────

/// Implement this to handle declarative [UIAction] events in your app.
abstract class ActionHandler {
  /// Called when any [UIAction] fires.
  ///
  /// [context] is the [BuildContext] of the widget that triggered it.
  /// [action] contains the type and payload.
  /// [variables] is the current snapshot of the [VariableStore].
  Future<void> handle(
    BuildContext context,
    UIAction action,
    Map<String, dynamic> variables,
  );
}

// ─────────────────────────────────────────────
// Default (logging) handler
// ─────────────────────────────────────────────

class LoggingActionHandler implements ActionHandler {
  const LoggingActionHandler();

  @override
  Future<void> handle(
    BuildContext context,
    UIAction action,
    Map<String, dynamic> variables,
  ) async {
    debugPrint(
      '[AgentUIKit] Action: ${action.type} — payload: ${action.payload}',
    );
    debugPrint('[AgentUIKit] Variables: $variables');
  }
}

// ─────────────────────────────────────────────
// Dispatcher
// ─────────────────────────────────────────────

/// Connects UI events → [ActionHandler].
/// Respects [setVariable] automatically before delegating.
class ActionDispatcher {
  ActionDispatcher({required this.handler, required this.variableStore});

  final ActionHandler handler;
  final VariableStore variableStore;

  Future<void> dispatch(BuildContext context, UIAction action) async {
    // Handle setVariable in-framework without requiring the app handler.
    if (action.type == ActionTypes.setVariable) {
      final key = action.payload['key'] as String?;
      final value = action.payload['value'];
      if (key != null) variableStore.set(key, value);
      return;
    }

    await handler.handle(context, action, variableStore.snapshot());
  }
}
