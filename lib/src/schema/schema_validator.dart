// lib/src/validation/schema_validator.dart
//
// AgentUIKit v2 — Schema Validation & Safety
// ============================================================
// Validates UINode trees BEFORE they reach the renderer.
// Catches LLM hallucinations, malformed JSON, unsafe values,
// and schema version mismatches early — with structured errors.
// ============================================================

import 'ui_schema.dart';

// ─────────────────────────────────────────────
// Validation result types
// ─────────────────────────────────────────────

enum ValidationSeverity { info, warning, error, fatal }

class ValidationIssue {
  const ValidationIssue({
    required this.severity,
    required this.code,
    required this.message,
    this.nodePath = '',
    this.nodeId,
    this.nodeType,
    this.suggestion,
  });

  final ValidationSeverity severity;
  final String code;
  final String message;
  final String nodePath; // e.g. "root.children[2].children[0]"
  final String? nodeId;
  final String? nodeType;
  final String? suggestion;

  bool get isError =>
      severity == ValidationSeverity.error ||
      severity == ValidationSeverity.fatal;

  @override
  String toString() =>
      '[${severity.name.toUpperCase()}] $code @ $nodePath: $message'
      '${suggestion != null ? '\n  → $suggestion' : ''}';
}

class ValidationResult {
  const ValidationResult({
    required this.isValid,
    required this.issues,
    this.sanitizedResponse,
  });

  final bool isValid;
  final List<ValidationIssue> issues;

  /// If sanitization was possible, this is the cleaned tree.
  final AgentUIResponse? sanitizedResponse;

  List<ValidationIssue> get errors => issues.where((i) => i.isError).toList();
  List<ValidationIssue> get warnings =>
      issues.where((i) => i.severity == ValidationSeverity.warning).toList();

  bool get hasFatal =>
      issues.any((i) => i.severity == ValidationSeverity.fatal);

  @override
  String toString() =>
      'ValidationResult(valid=$isValid, issues=${issues.length})\n'
      '${issues.map((i) => '  $i').join('\n')}';
}

// ─────────────────────────────────────────────
// Validator config
// ─────────────────────────────────────────────

class ValidatorConfig {
  const ValidatorConfig({
    this.supportedSchemaVersions = const {'1.0.0', '2.0.0'},
    this.maxDepth = 20,
    this.maxNodeCount = 500,
    this.maxTextLength = 10000,
    this.allowedNodeTypes,
    this.blockedNodeTypes = const {'webview'}, // restrict by default
    this.allowExpressions = true,
    this.sanitizeUnknownNodes = true,
    this.failOnUnknown = false,
    this.allowedActionTypes,
  });

  final Set<String> supportedSchemaVersions;
  final int maxDepth;
  final int maxNodeCount;
  final int maxTextLength;
  final Set<String>? allowedNodeTypes; // null = all allowed
  final Set<String> blockedNodeTypes;
  final bool allowExpressions;
  final bool sanitizeUnknownNodes;
  final bool failOnUnknown;
  final Set<String>? allowedActionTypes; // null = all allowed

  static const permissive = ValidatorConfig(
    blockedNodeTypes: {},
    maxDepth: 50,
    maxNodeCount: 2000,
  );

  static const strict = ValidatorConfig(
    maxDepth: 10,
    maxNodeCount: 100,
    allowedNodeTypes: {
      'container',
      'row',
      'column',
      'text',
      'button',
      'textField',
      'card',
      'list',
      'listItem',
      'divider',
      'spacer',
    },
    blockedNodeTypes: {'webview', 'custom'},
    failOnUnknown: true,
  );
}

// ─────────────────────────────────────────────
// Main validator
// ─────────────────────────────────────────────

class UISchemaValidator {
  UISchemaValidator({this.config = const ValidatorConfig()});

  final ValidatorConfig config;
  final _issues = <ValidationIssue>[];
  int _nodeCount = 0;

  ValidationResult validate(AgentUIResponse response) {
    _issues.clear();
    _nodeCount = 0;

    // 1. Schema version check
    _validateVersion(response.schemaVersion);

    // 2. Tree walk
    _validateNode(response.root, path: 'root', depth: 0);

    // 3. Sanitize if configured
    AgentUIResponse? sanitized;
    if (config.sanitizeUnknownNodes && _hasUnknownNodes(response.root)) {
      sanitized = AgentUIResponse(
        schemaVersion: response.schemaVersion,
        root: _sanitizeNode(response.root),
        metadata: response.metadata,
        sessionId: response.sessionId,
        turnId: response.turnId,
      );
    }

    final isValid = !_issues.any((i) => i.isError);
    return ValidationResult(
      isValid: isValid,
      issues: List.unmodifiable(_issues),
      sanitizedResponse: sanitized,
    );
  }

  // ── Version ──────────────────────────────────

  void _validateVersion(String version) {
    if (!config.supportedSchemaVersions.contains(version)) {
      _issues.add(
        ValidationIssue(
          severity: ValidationSeverity.warning,
          code: 'SCHEMA_VERSION_UNSUPPORTED',
          message:
              'Schema version "$version" not in supported set '
              '${config.supportedSchemaVersions}',
          suggestion:
              'Use schema version ${config.supportedSchemaVersions.last}',
        ),
      );
    }
  }

  // ── Node ─────────────────────────────────────

  void _validateNode(UINode node, {required String path, required int depth}) {
    _nodeCount++;

    // Depth check
    if (depth > config.maxDepth) {
      _issues.add(
        ValidationIssue(
          severity: ValidationSeverity.fatal,
          code: 'MAX_DEPTH_EXCEEDED',
          message: 'Node tree exceeds max depth of ${config.maxDepth}',
          nodePath: path,
          nodeType: node.type,
          suggestion: 'Flatten the UI structure',
        ),
      );
      return; // stop recursing
    }

    // Node count
    if (_nodeCount > config.maxNodeCount) {
      _issues.add(
        ValidationIssue(
          severity: ValidationSeverity.error,
          code: 'MAX_NODE_COUNT_EXCEEDED',
          message: 'Node count exceeds ${config.maxNodeCount}',
          nodePath: path,
          suggestion: 'Use pagination or virtualized lists',
        ),
      );
      return;
    }

    // Blocked types
    if (config.blockedNodeTypes.contains(node.type)) {
      _issues.add(
        ValidationIssue(
          severity: ValidationSeverity.error,
          code: 'BLOCKED_NODE_TYPE',
          message: 'Node type "${node.type}" is blocked by validator config',
          nodePath: path,
          nodeType: node.type,
          nodeId: node.id,
        ),
      );
    }

    // Allowed types whitelist
    if (config.allowedNodeTypes != null &&
        !config.allowedNodeTypes!.contains(node.type) &&
        node is! UnknownNode) {
      final sev = config.failOnUnknown
          ? ValidationSeverity.error
          : ValidationSeverity.warning;
      _issues.add(
        ValidationIssue(
          severity: sev,
          code: 'NODE_TYPE_NOT_WHITELISTED',
          message: 'Node type "${node.type}" not in allowed set',
          nodePath: path,
          nodeType: node.type,
        ),
      );
    }

    // Unknown nodes
    if (node is UnknownNode) {
      final sev = config.failOnUnknown
          ? ValidationSeverity.error
          : ValidationSeverity.warning;
      _issues.add(
        ValidationIssue(
          severity: sev,
          code: 'UNKNOWN_NODE_TYPE',
          message: 'No registered builder for type "${node.type}"',
          nodePath: path,
          nodeType: node.type,
          suggestion:
              'Register a builder: UIComponentRegistry.instance.register<YourNode>(...)',
        ),
      );
    }

    // Type-specific validation
    _validateNodeProps(node, path);

    // Actions
    for (final entry in node.actions.entries) {
      _validateAction(entry.value, path: '$path.actions.${entry.key}');
    }

    // Style
    if (node.style != null) {
      _validateStyle(node.style!, path: '$path.style');
    }

    // Children recurse
    for (var i = 0; i < node.children.length; i++) {
      _validateNode(
        node.children[i],
        path: '$path.children[$i]',
        depth: depth + 1,
      );
    }
  }

  void _validateNodeProps(UINode node, String path) {
    switch (node) {
      case TextNode n:
        if (n.text.isEmpty) {
          _issues.add(
            ValidationIssue(
              severity: ValidationSeverity.warning,
              code: 'TEXT_EMPTY',
              message: 'TextNode has empty text',
              nodePath: path,
            ),
          );
        }
        if (n.text.length > config.maxTextLength) {
          _issues.add(
            ValidationIssue(
              severity: ValidationSeverity.warning,
              code: 'TEXT_TOO_LONG',
              message:
                  'Text length ${n.text.length} exceeds ${config.maxTextLength}',
              nodePath: path,
              suggestion: 'Truncate or paginate long text',
            ),
          );
        }
        _checkExpression(n.text, path);

      case ButtonNode n:
        if (n.label == null && n.children.isEmpty) {
          _issues.add(
            ValidationIssue(
              severity: ValidationSeverity.warning,
              code: 'BUTTON_NO_LABEL',
              message: 'Button has no label and no children',
              nodePath: path,
            ),
          );
        }

      case ImageNode n:
        if (n.src.isEmpty) {
          _issues.add(
            ValidationIssue(
              severity: ValidationSeverity.error,
              code: 'IMAGE_EMPTY_SRC',
              message: 'ImageNode has empty src',
              nodePath: path,
            ),
          );
        }
        _validateUrl(n.src, path);

      case TextFieldNode n:
        if (n.variableBinding == null) {
          _issues.add(
            ValidationIssue(
              severity: ValidationSeverity.info,
              code: 'TEXTFIELD_NO_BINDING',
              message:
                  'TextField has no variableBinding — value changes will not be stored',
              nodePath: path,
              suggestion: 'Add variableBinding: "fieldName"',
            ),
          );
        }

      case DropdownNode n:
        if (n.options.isEmpty) {
          _issues.add(
            ValidationIssue(
              severity: ValidationSeverity.error,
              code: 'DROPDOWN_NO_OPTIONS',
              message: 'Dropdown has no options',
              nodePath: path,
            ),
          );
        }
        if (n.value != null && !n.options.any((o) => o.value == n.value)) {
          _issues.add(
            ValidationIssue(
              severity: ValidationSeverity.warning,
              code: 'DROPDOWN_INVALID_VALUE',
              message: 'Dropdown value "${n.value}" not found in options',
              nodePath: path,
            ),
          );
        }

      case GridNode n:
        final count = n.crossAxisCount ?? 2;
        if (count < 1 || count > 12) {
          _issues.add(
            ValidationIssue(
              severity: ValidationSeverity.warning,
              code: 'GRID_INVALID_CROSS_AXIS_COUNT',
              message: 'Grid crossAxisCount=$count is unusual (expected 1–12)',
              nodePath: path,
            ),
          );
        }

      case SliderNode n:
        final min = n.min ?? 0;
        final max = n.max ?? 1;
        if (min >= max) {
          _issues.add(
            ValidationIssue(
              severity: ValidationSeverity.error,
              code: 'SLIDER_INVALID_RANGE',
              message: 'Slider min ($min) >= max ($max)',
              nodePath: path,
            ),
          );
        }
        if (n.value < min || n.value > max) {
          _issues.add(
            ValidationIssue(
              severity: ValidationSeverity.warning,
              code: 'SLIDER_VALUE_OUT_OF_RANGE',
              message: 'Slider value ${n.value} is outside [$min, $max]',
              nodePath: path,
              suggestion: 'Clamp value to valid range',
            ),
          );
        }

      case WebViewNode n:
        _validateUrl(n.url, path);

      default:
        break;
    }
  }

  void _validateAction(UIAction action, {required String path}) {
    if (config.allowedActionTypes != null &&
        !config.allowedActionTypes!.contains(action.type)) {
      _issues.add(
        ValidationIssue(
          severity: ValidationSeverity.error,
          code: 'ACTION_TYPE_BLOCKED',
          message: 'Action type "${action.type}" is not allowed',
          nodePath: path,
        ),
      );
    }

    // Required payload fields per action type
    switch (action.type) {
      case 'navigate':
        if (!action.payload.containsKey('route')) {
          _issues.add(
            ValidationIssue(
              severity: ValidationSeverity.warning,
              code: 'ACTION_MISSING_PAYLOAD_FIELD',
              message: 'navigate action missing required "route" field',
              nodePath: path,
            ),
          );
        }
      case 'setVariable':
        if (!action.payload.containsKey('key')) {
          _issues.add(
            ValidationIssue(
              severity: ValidationSeverity.error,
              code: 'ACTION_MISSING_PAYLOAD_FIELD',
              message: 'setVariable action missing required "key" field',
              nodePath: path,
            ),
          );
        }
      case 'openUrl':
        final url = action.payload['url'] as String?;
        if (url == null || url.isEmpty) {
          _issues.add(
            ValidationIssue(
              severity: ValidationSeverity.error,
              code: 'ACTION_MISSING_PAYLOAD_FIELD',
              message: 'openUrl action missing "url" field',
              nodePath: path,
            ),
          );
        } else {
          _validateUrl(url, path);
        }
    }
  }

  void _validateStyle(UIStyle style, {required String path}) {
    if (style.opacity != null && (style.opacity! < 0 || style.opacity! > 1)) {
      _issues.add(
        ValidationIssue(
          severity: ValidationSeverity.warning,
          code: 'STYLE_OPACITY_OUT_OF_RANGE',
          message: 'opacity ${style.opacity} is outside [0, 1]',
          nodePath: path,
        ),
      );
    }

    if (style.fontSize != null && style.fontSize! <= 0) {
      _issues.add(
        ValidationIssue(
          severity: ValidationSeverity.warning,
          code: 'STYLE_INVALID_FONT_SIZE',
          message: 'fontSize ${style.fontSize} must be > 0',
          nodePath: path,
        ),
      );
    }

    if (style.gradient != null) {
      final g = style.gradient!;
      if (g.colors.length < 2) {
        _issues.add(
          ValidationIssue(
            severity: ValidationSeverity.error,
            code: 'STYLE_GRADIENT_TOO_FEW_COLORS',
            message: 'gradient needs at least 2 colors',
            nodePath: path,
          ),
        );
      }
      if (g.stops != null && g.stops!.length != g.colors.length) {
        _issues.add(
          ValidationIssue(
            severity: ValidationSeverity.error,
            code: 'STYLE_GRADIENT_STOPS_MISMATCH',
            message:
                'gradient stops count (${g.stops!.length}) != colors count (${g.colors.length})',
            nodePath: path,
          ),
        );
      }
    }
  }

  void _validateUrl(String url, String path) {
    if (url.isEmpty) return;
    // Block javascript: URLs
    if (url.toLowerCase().startsWith('javascript:')) {
      _issues.add(
        ValidationIssue(
          severity: ValidationSeverity.fatal,
          code: 'UNSAFE_URL_JAVASCRIPT',
          message: 'javascript: URLs are not permitted',
          nodePath: path,
          suggestion: 'Use https:// URLs only',
        ),
      );
    }
    // Warn on non-https
    if (url.startsWith('http://')) {
      _issues.add(
        ValidationIssue(
          severity: ValidationSeverity.warning,
          code: 'URL_NOT_HTTPS',
          message: 'URL uses http:// instead of https://',
          nodePath: path,
        ),
      );
    }
  }

  void _checkExpression(String text, String path) {
    if (!config.allowExpressions && text.contains('{{')) {
      _issues.add(
        ValidationIssue(
          severity: ValidationSeverity.warning,
          code: 'EXPRESSIONS_DISABLED',
          message: 'Text contains expression syntax but allowExpressions=false',
          nodePath: path,
        ),
      );
    }
  }

  // ── Sanitization ──────────────────────────────

  bool _hasUnknownNodes(UINode node) {
    if (node is UnknownNode) return true;
    return node.children.any(_hasUnknownNodes);
  }

  UINode _sanitizeNode(UINode node) {
    if (node is UnknownNode) {
      // Replace with an informational placeholder
      return TextNode(
        id: node.id,
        text: '[Unsupported component: ${node.type}]',
        style: const UIStyle(foregroundColor: 'grey', fontSize: 12),
      );
    }
    // Recursively sanitize children — requires node reconstruction.
    // For now return as-is (children are immutable in base class).
    return node;
  }
}
