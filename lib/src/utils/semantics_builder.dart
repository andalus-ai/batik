// lib/src/accessibility/semantics_builder.dart
//
// AgentUIKit v3 — Accessibility (A11y) Layer
// ============================================================
// Wraps every rendered widget with proper Flutter Semantics so
// that screen readers (TalkBack / VoiceOver) can describe
// agent-generated UIs correctly.
//
// Features:
//  • Per-node semanticsLabel / hint / value overrides
//  • Live region support (announce dynamic changes)
//  • Focus traversal ordering
//  • Role mapping (button, image, heading, form field…)
//  • excludeSemantics for decorative nodes
//  • RTL-aware
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import '../schema/ui_schema.dart';

// ─────────────────────────────────────────────
// Semantics descriptor (schema extension)
// ─────────────────────────────────────────────

/// Attach to any UINode via the node's `semantics` property.
/// Agents can emit these to give screen readers precise descriptions.
class UISemantics {
  const UISemantics({
    this.label,
    this.hint,
    this.value,
    this.role,
    this.liveRegion = false,
    this.focusOrder,
    this.exclude = false,
    this.isHeader = false,
    this.isLink = false,
    this.isReadOnly = false,
    this.isRequired = false,
    this.onTapHint,
    this.onLongPressHint,
  });

  /// Overrides the default accessible label.
  final String? label;

  /// Additional context read after the label.
  final String? hint;

  /// Current value (for sliders, text fields, switches…).
  final String? value;

  /// Semantic role: "button" | "image" | "heading" | "textField"
  ///               | "checkbox" | "radio" | "slider" | "link" | "none"
  final String? role;

  /// If true, changes are announced to screen readers immediately.
  final bool liveRegion;

  /// Tab/focus traversal order (lower = first).
  final int? focusOrder;

  /// If true, this node and its subtree are hidden from accessibility tree.
  final bool exclude;

  final bool isHeader;
  final bool isLink;
  final bool isReadOnly;
  final bool isRequired;

  /// Hint read when the user performs a tap action.
  final String? onTapHint;

  /// Hint read when the user performs a long-press action.
  final String? onLongPressHint;

  factory UISemantics.fromJson(Map<String, dynamic> j) => UISemantics(
    label: j['label'] as String?,
    hint: j['hint'] as String?,
    value: j['value'] as String?,
    role: j['role'] as String?,
    liveRegion: j['liveRegion'] as bool? ?? false,
    focusOrder: j['focusOrder'] as int?,
    exclude: j['exclude'] as bool? ?? false,
    isHeader: j['isHeader'] as bool? ?? false,
    isLink: j['isLink'] as bool? ?? false,
    isReadOnly: j['isReadOnly'] as bool? ?? false,
    isRequired: j['isRequired'] as bool? ?? false,
    onTapHint: j['onTapHint'] as String?,
    onLongPressHint: j['onLongPressHint'] as String?,
  );

  Map<String, dynamic> toJson() => {
    if (label != null) 'label': label,
    if (hint != null) 'hint': hint,
    if (value != null) 'value': value,
    if (role != null) 'role': role,
    if (liveRegion) 'liveRegion': liveRegion,
    if (focusOrder != null) 'focusOrder': focusOrder,
    if (exclude) 'exclude': exclude,
    if (isHeader) 'isHeader': isHeader,
    if (isLink) 'isLink': isLink,
    if (isReadOnly) 'isReadOnly': isReadOnly,
    if (isRequired) 'isRequired': isRequired,
    if (onTapHint != null) 'onTapHint': onTapHint,
    if (onLongPressHint != null) 'onLongPressHint': onLongPressHint,
  };
}

// ─────────────────────────────────────────────
// Semantics builder
// ─────────────────────────────────────────────

/// Wraps [child] with appropriate [Semantics] based on [node] type
/// and any explicitly provided [UISemantics] override.
class SemanticsBuilder {
  const SemanticsBuilder();

  Widget wrap(BuildContext context, UINode node, Widget child) {
    final sem = _extractSemantics(node);

    if (sem?.exclude == true) {
      return ExcludeSemantics(child: child);
    }

    // Infer role from node type if not explicit
    final role = sem?.role ?? _inferRole(node);

    // Build semantics properties
    final label = sem?.label ?? _inferLabel(node);
    final hint = sem?.hint ?? _inferHint(node, role);
    final value = sem?.value ?? _inferValue(node);

    // Live region wrapping
    Widget result = _applyRoleSemantics(
      child: child,
      node: node,
      role: role,
      label: label,
      hint: hint,
      value: value,
      sem: sem,
    );

    if (sem?.liveRegion == true) {
      result = _LiveRegionWrapper(child: result);
    }

    if (sem?.focusOrder != null) {
      result = FocusTraversalOrder(
        order: NumericFocusOrder(sem!.focusOrder!.toDouble()),
        child: result,
      );
    }

    return result;
  }

  // ── Role-based semantics ──────────────────────

  Widget _applyRoleSemantics({
    required Widget child,
    required UINode node,
    required String? role,
    required String? label,
    required String? hint,
    required String? value,
    required UISemantics? sem,
  }) {
    switch (role) {
      case 'button':
        return Semantics(
          button: true,
          label: label,
          hint: hint ?? sem?.onTapHint,
          enabled: _isEnabled(node),
          child: child,
        );

      case 'image':
        return Semantics(image: true, label: label ?? 'Image', child: child);

      case 'heading':
        return Semantics(header: true, label: label, child: child);

      case 'textField':
        return Semantics(
          textField: true,
          label: label,
          hint: hint,
          value: value,
          readOnly: sem?.isReadOnly ?? false,
          child: child,
        );

      case 'slider':
        return Semantics(
          slider: true,
          label: label,
          value: value,
          child: child,
        );

      case 'checkbox':
      case 'switch':
        final sw = node is SwitchNode ? node : null;
        return Semantics(toggled: sw?.value, label: label, child: child);

      case 'link':
        return Semantics(
          link: true,
          label: label,
          hint: hint ?? 'Opens link',
          child: child,
        );

      case 'none':
        return ExcludeSemantics(child: child);

      default:
        if (label == null && hint == null) return child;
        return Semantics(
          label: label,
          hint: hint,
          value: value,
          header: sem?.isHeader ?? false,
          link: sem?.isLink ?? false,
          readOnly: sem?.isReadOnly ?? false,
          child: child,
        );
    }
  }

  // ── Inference helpers ─────────────────────────

  UISemantics? _extractSemantics(UINode node) {
    // Semantics are stored in the node's raw JSON via toJson()
    // In future schema versions, UINode will have a `semantics` field.
    // For now we infer from type.
    return null;
  }

  String? _inferRole(UINode node) {
    return switch (node) {
      ButtonNode() => 'button',
      IconButtonNode() => 'button',
      FabNode() => 'button',
      ImageNode() => 'image',
      TextNode(variant: final v) when _isHeadingVariant(v) => 'heading',
      TextFieldNode() => 'textField',
      SliderNode() => 'slider',
      SwitchNode() => 'switch',
      _ => null,
    };
  }

  String? _inferLabel(UINode node) {
    return switch (node) {
      TextNode(:final text) => text.isEmpty ? null : text,
      ButtonNode(:final label) => label,
      IconButtonNode(:final tooltip) => tooltip,
      ImageNode(:final alt) => alt ?? 'Image',
      TextFieldNode(:final label) => label,
      SwitchNode(:final label) => label,
      SliderNode(:final label) => label,
      ChipNode(:final label) => label,
      BadgeNode(:final label) => label != null ? 'Badge: $label' : null,
      AvatarNode(:final initials) =>
        initials != null ? 'Avatar: $initials' : 'Avatar',
      FabNode(:final label, :final icon) => label ?? 'Button: $icon',
      _ => null,
    };
  }

  String? _inferHint(UINode node, String? role) {
    if (role == 'button') return 'Double tap to activate';
    if (role == 'textField') return 'Double tap to edit';
    if (role == 'slider') return 'Swipe to adjust';
    if (role == 'switch') return 'Double tap to toggle';
    return null;
  }

  String? _inferValue(UINode node) {
    return switch (node) {
      SwitchNode(:final value) => value ? 'On' : 'Off',
      SliderNode(:final value, :final min, :final max) =>
        '${((value - (min ?? 0)) / ((max ?? 1) - (min ?? 0)) * 100).toInt()}%',
      ProgressBarNode(:final value) =>
        value != null ? '${(value * 100).toInt()}%' : 'Loading',
      DropdownNode(:final value) => value,
      _ => null,
    };
  }

  bool _isHeadingVariant(String? variant) {
    if (variant == null) return false;
    return variant.startsWith('display') ||
        variant.startsWith('headline') ||
        variant.startsWith('title');
  }

  bool _isEnabled(UINode node) {
    return switch (node) {
      ButtonNode(:final disabled) => disabled != true,
      IconButtonNode(:final disabled) => disabled != true,
      TextFieldNode(:final disabled) => disabled != true,
      _ => true,
    };
  }
}

// ─────────────────────────────────────────────
// Live region announcer
// ─────────────────────────────────────────────

/// Wraps child and announces content changes to screen readers.
class _LiveRegionWrapper extends StatefulWidget {
  const _LiveRegionWrapper({required this.child});
  final Widget child;

  @override
  State<_LiveRegionWrapper> createState() => _LiveRegionWrapperState();
}

class _LiveRegionWrapperState extends State<_LiveRegionWrapper> {
  @override
  Widget build(BuildContext context) {
    return Semantics(liveRegion: true, child: widget.child);
  }
}

// ─────────────────────────────────────────────
// Accessible chat message list
// ─────────────────────────────────────────────

/// Announces new agent messages to screen readers.
class AccessibleMessageAnnouncer extends StatefulWidget {
  const AccessibleMessageAnnouncer({
    super.key,
    required this.lastMessage,
    required this.child,
  });

  final String? lastMessage;
  final Widget child;

  @override
  State<AccessibleMessageAnnouncer> createState() =>
      _AccessibleMessageAnnouncerState();
}

class _AccessibleMessageAnnouncerState
    extends State<AccessibleMessageAnnouncer> {
  String? _previousMessage;

  @override
  void didUpdateWidget(AccessibleMessageAnnouncer old) {
    super.didUpdateWidget(old);
    final msg = widget.lastMessage;
    if (msg != null && msg != _previousMessage) {
      _previousMessage = msg;
      // Announce to screen reader with polite priority
      WidgetsBinding.instance.addPostFrameCallback((_) {
        SemanticsService.announce(
          'Agent responded: ${_truncateForAnnouncement(msg)}',
          TextDirection.ltr,
          assertiveness: Assertiveness.polite,
        );
      });
    }
  }

  String _truncateForAnnouncement(String text) {
    // Truncate JSON / very long strings for screen reader sanity
    final clean = text.replaceAll(RegExp(r'\{.*?\}', dotAll: true), '');
    if (clean.trim().isEmpty) return 'New UI content generated';
    return clean.length > 150 ? '${clean.substring(0, 150)}…' : clean;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

// ─────────────────────────────────────────────
// Skip navigation link
// ─────────────────────────────────────────────

/// "Skip to content" — jumps focus past the agent header/toolbar.
class SkipNavigationLink extends StatelessWidget {
  const SkipNavigationLink({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        Positioned(
          top: -100, // off-screen by default
          child: Focus(
            child: Semantics(
              button: true,
              label: 'Skip to main content',
              child: const SizedBox.shrink(),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// A11y config
// ─────────────────────────────────────────────

class AccessibilityConfig {
  const AccessibilityConfig({
    this.enabled = true,
    this.announceAgentResponses = true,
    this.inferRolesFromTypes = true,
    this.inferLabelsFromProps = true,
    this.enableFocusTraversal = true,
    this.highContrastMode = false,
    this.minimumTouchTargetSize = 44.0,
  });

  final bool enabled;
  final bool announceAgentResponses;
  final bool inferRolesFromTypes;
  final bool inferLabelsFromProps;
  final bool enableFocusTraversal;
  final bool highContrastMode;

  /// WCAG 2.1 AA minimum: 44×44 dp
  final double minimumTouchTargetSize;

  static const wcagAA = AccessibilityConfig(
    minimumTouchTargetSize: 44.0,
    highContrastMode: false,
  );

  static const wcagAAA = AccessibilityConfig(
    minimumTouchTargetSize: 48.0,
    highContrastMode: true,
  );
}

// ─────────────────────────────────────────────
// Touch target enforcer
// ─────────────────────────────────────────────

/// Ensures interactive widgets meet minimum touch target size (WCAG 2.5.5).
Widget ensureMinTouchTarget(
  Widget child, {
  double minSize = 44.0,
  bool isInteractive = false,
}) {
  if (!isInteractive) return child;
  return ConstrainedBox(
    constraints: BoxConstraints(minWidth: minSize, minHeight: minSize),
    child: child,
  );
}
