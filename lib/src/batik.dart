// lib/src/batik.dart
//
// Batik Framework - Internal Barrel Export
// ============================================================
// This file exports all internal modules for use by the public API.
// Import this file from lib/batik.dart to expose the framework.
// ============================================================

// Schema - UI Node definitions and validation
export 'schema/ui_schema.dart';
export 'schema/schema_validator.dart' hide UIDiffEngine;

// Core - Fundamental interfaces and utilities
export 'core/registry.dart';
export 'core/action_dispatcher.dart';
export 'core/style_utils.dart';

// Adapters - Agent communication layer
export 'adapters/agent_adapter.dart';
export 'adapters/system_prompt_builder.dart';
export 'adapters/wayang_assistant_adapter.dart' hide ConversationTurn;
export 'adapters/wayang_assistant_websocket_adapter.dart';
export 'adapters/andalus_adapter.dart';

// Renderer - UI rendering engine
export 'renderer/ui_renderer.dart' hide ActionDispatcher;
export 'renderer/virtual_list_renderer.dart';

// State - Riverpod state management
export 'state/agent_providers.dart'
    hide AgentMessage, DiffResult, UISchemaValidator, UIDiffEngine;

// Streaming - Real-time streaming support
export 'streaming/streaming_parser.dart';
export 'streaming/websocket_client.dart';
export 'streaming/websocket_agent_adapter.dart';

// Diff - Diff/patch engine for efficient updates
export 'diff/ui_diff_engine.dart';

// Animation - Animation system
export 'animation/animated_node_renderer.dart' hide SkeletonLoader;

// Widgets - High-level widgets
export 'widgets/agent_ui_chat.dart';
export 'widgets/multi_agent_orchestrator.dart';
export 'widgets/agent_tool_runner.dart';
export 'widgets/agent_localizations.dart';
export 'widgets/agent_inspector.dart';
export 'widgets/session_persistence.dart';
export 'widgets/agent_ui_theme.dart';
export 'widgets/skeleton_loader.dart';

// Components - Component builders
export 'components/builtin_components.dart';
export 'components/batik_components.dart';

// Theme - Theming system & Design Tokens
export 'theme/batik_theme.dart';
export 'theme/batik_colors.dart';
export 'theme/batik_tokens.dart';

// Plugin - Plugin system (v1 compat + v2 API)
export 'plugin/plugin_registry.dart';
export 'plugin/batik_plugin.dart';

// Utils - Utility classes and helpers
export 'utils/response_cache.dart';
export 'utils/semantics_builder.dart';
export 'utils/typed_actions.dart';

// ── Patch 029-049: New runtime capabilities ──────────────────

// Runtime Graph (Patch 030) — node/edge graph model
export 'runtime/runtime_graph.dart';

// DataSource Layer (Patch 031) — data adapters and registry
export 'datasource/data_source.dart';

// Diagram Core (Patch 033) — DiagramGraph, nodes, edges, types
export 'diagram/diagram_graph.dart';
export 'diagram/diagram_renderer.dart';
export 'diagram/mermaid_parser.dart';
export 'diagram/diagram_node_widget.dart';

// Shape Engine (Patch 034 / Section 4) — vector shapes
export 'shapes/shape_node.dart';

// Tenun Adapter (Patch 032) — Tenun chart node + plugin
export 'tenun/tenun_adapter.dart';

// Workflow Runtime (Patch 035) — workflow graph + executor
export 'workflow/workflow_runtime.dart'
    hide _WorkflowVisual, _parseWfStyle, _parseWfActions, _WfNodeJsonBase;

// Live Document Runtime (Patch 036) — narrative rich doc
export 'document/document_node.dart';

// Agent Workspace Runtime (Patch 039) — multi-pane workspace
export 'workspace/agent_workspace.dart';

// Component Composition Engine (Patch 048) — composable semantic units
export 'components/component_composer.dart';

// Runtime Templates (Patch 049) — macro application patterns
export 'templates/runtime_template.dart';
