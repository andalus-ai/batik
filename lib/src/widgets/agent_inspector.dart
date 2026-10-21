// lib/src/devtools/agent_inspector.dart
//
// AgentUIKit v3 — Developer Inspector Overlay
// ============================================================
// An in-app debug panel that shows live:
//  • Current UINode tree with props
//  • Active VariableStore values
//  • Last DiffResult (patches)
//  • Cache stats
//  • Validation issues
//  • Session history
//  • System prompt preview
//
// Enable with AgentInspector.wrap(child) in debug builds only.
// Toggle with a floating debug button or shake gesture.
// Zero overhead in release mode (tree-shaken out entirely).
// ============================================================

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../utils/response_cache.dart';
import '../schema/schema_validator.dart';
import '../diff/ui_diff_engine.dart' as diff_engine;
import '../schema/ui_schema.dart';
import '../state/agent_providers.dart' show AgentSessionConfig;

// ─────────────────────────────────────────────
// Inspector state
// ─────────────────────────────────────────────

class _InspectorState {
  const _InspectorState({
    this.isOpen = false,
    this.tab = InspectorTab.tree,
    this.selectedNodePath,
    this.filterText = '',
  });

  final bool isOpen;
  final InspectorTab tab;
  final String? selectedNodePath;
  final String filterText;

  _InspectorState copyWith({
    bool? isOpen,
    InspectorTab? tab,
    String? selectedNodePath,
    String? filterText,
  }) =>
      _InspectorState(
        isOpen: isOpen ?? this.isOpen,
        tab: tab ?? this.tab,
        selectedNodePath: selectedNodePath ?? this.selectedNodePath,
        filterText: filterText ?? this.filterText,
      );
}

enum InspectorTab { tree, variables, diff, cache, validation, prompt }

class _InspectorNotifier extends Notifier<_InspectorState> {
  @override
  _InspectorState build() => const _InspectorState();

  void toggle() => state = state.copyWith(isOpen: !state.isOpen);
  void open() => state = state.copyWith(isOpen: true);
  void close() => state = state.copyWith(isOpen: false);
  void setTab(InspectorTab tab) => state = state.copyWith(tab: tab);
  void selectNode(String path) =>
      state = state.copyWith(selectedNodePath: path);
  void setFilter(String text) => state = state.copyWith(filterText: text);
}

final _inspectorProvider =
    NotifierProvider<_InspectorNotifier, _InspectorState>(
  _InspectorNotifier.new,
);

// ─────────────────────────────────────────────
// Inspector data model
// ─────────────────────────────────────────────

class InspectorData {
  const InspectorData({
    this.sessionConfig,
    this.uiResponse,
    this.variables = const {},
    this.diff,
    this.validationResult,
    this.cache,
    this.systemPrompt,
  });

  final AgentSessionConfig? sessionConfig;
  final AgentUIResponse? uiResponse;
  final Map<String, dynamic> variables;
  final diff_engine.DiffResult? diff;
  final ValidationResult? validationResult;
  final ResponseCache? cache;
  final String? systemPrompt;
}

// ─────────────────────────────────────────────
// Main wrapper widget
// ─────────────────────────────────────────────

class AgentInspector extends ConsumerWidget {
  const AgentInspector({
    super.key,
    required this.child,
    required this.data,
    this.enabled,
  });

  final Widget child;
  final InspectorData data;

  /// Defaults to kDebugMode. Set to false to always disable.
  final bool? enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = enabled ?? kDebugMode;
    if (!active) return child;

    final state = ref.watch(_inspectorProvider);

    return Stack(
      children: [
        child,
        // Inspector panel
        if (state.isOpen) Positioned.fill(child: _InspectorPanel(data: data)),
        // FAB toggle
        Positioned(
          bottom: 88,
          right: 12,
          child: _InspectorFab(isOpen: state.isOpen),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// FAB
// ─────────────────────────────────────────────

class _InspectorFab extends ConsumerWidget {
  const _InspectorFab({required this.isOpen});
  final bool isOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FloatingActionButton.small(
      heroTag: 'agentInspectorFab',
      backgroundColor:
          isOpen ? Colors.red.shade700 : Colors.deepPurple.shade700,
      onPressed: () => ref.read(_inspectorProvider.notifier).toggle(),
      child: Icon(
        isOpen ? Icons.close : Icons.bug_report,
        color: Colors.white,
        size: 20,
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Inspector panel
// ─────────────────────────────────────────────

class _InspectorPanel extends ConsumerWidget {
  const _InspectorPanel({required this.data});
  final InspectorData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(_inspectorProvider);

    return Material(
      color: Colors.transparent,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          height: MediaQuery.of(context).size.height * 0.65,
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E2E),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(.5), blurRadius: 24),
            ],
          ),
          child: Column(
            children: [
              _PanelHeader(tab: state.tab),
              Expanded(
                child: _PanelBody(data: data, tab: state.tab),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PanelHeader extends ConsumerWidget {
  const _PanelHeader({required this.tab});
  final InspectorTab tab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: Color(0xFF2A2A3E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Text(
                '🔍 AgentUIKit Inspector',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const Spacer(),
              Text(
                'DEBUG',
                style: TextStyle(
                  color: Colors.amber.shade400,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: InspectorTab.values
                  .map((t) => _TabChip(tab: t, selected: t == tab))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _TabChip extends ConsumerWidget {
  const _TabChip({required this.tab, required this.selected});
  final InspectorTab tab;
  final bool selected;

  static const _labels = {
    InspectorTab.tree: '🌲 Tree',
    InspectorTab.variables: '📦 Vars',
    InspectorTab.diff: '🔄 Diff',
    InspectorTab.cache: '💾 Cache',
    InspectorTab.validation: '✅ Validate',
    InspectorTab.prompt: '📝 Prompt',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () => ref.read(_inspectorProvider.notifier).setTab(tab),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: selected
              ? Colors.deepPurple.shade600
              : Colors.white.withOpacity(.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          _labels[tab] ?? tab.name,
          style: TextStyle(
            color: selected ? Colors.white : Colors.white60,
            fontSize: 11,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

class _PanelBody extends StatelessWidget {
  const _PanelBody({required this.data, required this.tab});
  final InspectorData data;
  final InspectorTab tab;

  @override
  Widget build(BuildContext context) {
    return switch (tab) {
      InspectorTab.tree => _TreeTab(response: data.uiResponse),
      InspectorTab.variables => _VariablesTab(variables: data.variables),
      InspectorTab.diff => _DiffTab(diff: data.diff),
      InspectorTab.cache => _CacheTab(cache: data.cache),
      InspectorTab.validation => _ValidationTab(result: data.validationResult),
      InspectorTab.prompt => _PromptTab(prompt: data.systemPrompt),
    };
  }
}

// ─────────────────────────────────────────────
// Tree tab
// ─────────────────────────────────────────────

class _TreeTab extends StatelessWidget {
  const _TreeTab({this.response});
  final AgentUIResponse? response;

  @override
  Widget build(BuildContext context) {
    if (response == null) {
      return const _EmptyState('No UI tree loaded yet.');
    }
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [_NodeRow(node: response!.root, depth: 0)],
    );
  }
}

class _NodeRow extends StatefulWidget {
  const _NodeRow({required this.node, required this.depth});
  final UINode node;
  final int depth;

  @override
  State<_NodeRow> createState() => _NodeRowState();
}

class _NodeRowState extends State<_NodeRow> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final node = widget.node;
    final indent = widget.depth * 16.0;
    final hasChildren = node.children.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap:
              hasChildren ? () => setState(() => _expanded = !_expanded) : null,
          child: Padding(
            padding: EdgeInsets.only(left: indent, bottom: 3),
            child: Row(
              children: [
                if (hasChildren)
                  Icon(
                    _expanded ? Icons.arrow_drop_down : Icons.arrow_right,
                    color: Colors.white54,
                    size: 14,
                  )
                else
                  const SizedBox(width: 14),
                const SizedBox(width: 2),
                _TypeBadge(type: node.type),
                const SizedBox(width: 6),
                if (node.id != null)
                  Text(
                    '#${node.id}',
                    style: const TextStyle(color: Colors.amber, fontSize: 10),
                  ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    _nodePreview(node),
                    style: const TextStyle(color: Colors.white70, fontSize: 10),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_expanded && hasChildren)
          ...node.children.map(
            (c) => _NodeRow(node: c, depth: widget.depth + 1),
          ),
      ],
    );
  }

  String _nodePreview(UINode node) {
    return switch (node) {
      TextNode(:final text) =>
        '"${text.length > 30 ? '${text.substring(0, 30)}…' : text}"',
      ButtonNode(:final label) => label != null ? '"$label"' : '',
      ImageNode(:final src) =>
        src.length > 30 ? '${src.substring(0, 30)}…' : src,
      TextFieldNode(:final label) => label ?? '',
      _ => node.children.isEmpty ? '' : '${node.children.length} children',
    };
  }
}

class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.type});
  final String type;

  static final _colors = <String, Color>{
    'container': Colors.blueGrey,
    'row': Colors.blue.shade700,
    'column': Colors.indigo.shade700,
    'text': Colors.green.shade700,
    'button': Colors.orange.shade700,
    'card': Colors.purple.shade700,
    'list': Colors.teal.shade700,
    'image': Colors.pink.shade700,
    'textField': Colors.cyan.shade700,
  };

  @override
  Widget build(BuildContext context) {
    final color = _colors[type] ?? Colors.grey.shade700;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: color.withOpacity(.3),
        border: Border.all(color: color.withOpacity(.6), width: .5),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        type,
        style: TextStyle(
          color: color.withOpacity(1),
          fontSize: 9,
          fontWeight: FontWeight.bold,
          fontFamily: 'monospace',
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Variables tab
// ─────────────────────────────────────────────

class _VariablesTab extends StatelessWidget {
  const _VariablesTab({required this.variables});
  final Map<String, dynamic> variables;

  @override
  Widget build(BuildContext context) {
    if (variables.isEmpty) {
      return const _EmptyState('No variables in store.');
    }
    return ListView(
      padding: const EdgeInsets.all(12),
      children:
          variables.entries.map((e) => _VarRow(k: e.key, v: e.value)).toList(),
    );
  }
}

class _VarRow extends StatelessWidget {
  const _VarRow({required this.k, required this.v});
  final String k;
  final dynamic v;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            k,
            style: const TextStyle(
              color: Colors.cyan,
              fontSize: 11,
              fontFamily: 'monospace',
            ),
          ),
          const Text(
            ' = ',
            style: TextStyle(color: Colors.white38, fontSize: 11),
          ),
          Flexible(
            child: Text(
              v.toString(),
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 11,
                fontFamily: 'monospace',
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 3,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(.06),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(
              v.runtimeType.toString(),
              style: const TextStyle(color: Colors.white38, fontSize: 8),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Diff tab
// ─────────────────────────────────────────────

class _DiffTab extends StatelessWidget {
  const _DiffTab({this.diff});
  final diff_engine.DiffResult? diff;

  @override
  Widget build(BuildContext context) {
    if (diff == null || !diff!.hasChanges) {
      return const _EmptyState('No diff yet — send a message first.');
    }
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _CodeLine('// ${diff!.summary}', Colors.white54),
        const SizedBox(height: 8),
        ...diff!.patches.map(_PatchRow.new),
      ],
    );
  }
}

class _PatchRow extends StatelessWidget {
  const _PatchRow(this.patch);
  final diff_engine.UIPatch patch;

  @override
  Widget build(BuildContext context) {
    final (icon, color, label) = switch (patch) {
      diff_engine.InsertPatch() => ('＋', Colors.green, 'INSERT'),
      diff_engine.RemovePatch() => ('－', Colors.red, 'REMOVE'),
      diff_engine.UpdatePatch() => ('~', Colors.amber, 'UPDATE'),
      diff_engine.ReplacePatch() => ('⇄', Colors.orange, 'REPLACE'),
      diff_engine.ReorderPatch() => ('↕', Colors.blue, 'REORDER'),
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        children: [
          Container(
            width: 52,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: 2),
            decoration: BoxDecoration(
              color: color.withOpacity(.15),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(
              '$icon $label',
              style: TextStyle(
                color: color,
                fontSize: 9,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              patch.path,
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 10,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Cache tab
// ─────────────────────────────────────────────

class _CacheTab extends StatelessWidget {
  const _CacheTab({this.cache});
  final ResponseCache? cache;

  @override
  Widget build(BuildContext context) {
    if (cache == null) {
      return const _EmptyState('No cache configured.');
    }
    return FutureBuilder<CacheStats>(
      future: cache!.stats(),
      builder: (ctx, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator(strokeWidth: 2));
        }
        final s = snap.data!;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _StatCard(
              'Hit Rate',
              '${(s.hitRate * 100).toStringAsFixed(1)}%',
              color: s.hitRate > .5 ? Colors.green : Colors.orange,
            ),
            _StatCard('Hits / Misses', '${s.hits} / ${s.misses}'),
            _StatCard('Entries', '${s.entryCount}'),
            _StatCard('Evictions', '${s.evictions}'),
            _StatCard(
              'Est. Size',
              '${(s.estimatedSizeBytes / 1024).toStringAsFixed(1)} KB',
            ),
          ],
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard(this.label, this.value, {this.color});
  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white60, fontSize: 12),
          ),
          Text(
            value,
            style: TextStyle(
              color: color ?? Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Validation tab
// ─────────────────────────────────────────────

class _ValidationTab extends StatelessWidget {
  const _ValidationTab({this.result});
  final ValidationResult? result;

  @override
  Widget build(BuildContext context) {
    if (result == null) {
      return const _EmptyState('No validation result. Send a message first.');
    }
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _CodeLine(
          result!.isValid ? '✅ Valid' : '❌ Invalid',
          result!.isValid ? Colors.green : Colors.red,
        ),
        _CodeLine('${result!.issues.length} issues total', Colors.white54),
        const SizedBox(height: 8),
        ...result!.issues.map(_IssueRow.new),
      ],
    );
  }
}

class _IssueRow extends StatelessWidget {
  const _IssueRow(this.issue);
  final ValidationIssue issue;

  @override
  Widget build(BuildContext context) {
    final color = switch (issue.severity) {
      ValidationSeverity.fatal => Colors.red,
      ValidationSeverity.error => Colors.red.shade300,
      ValidationSeverity.warning => Colors.amber,
      ValidationSeverity.info => Colors.blue,
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '[${issue.severity.name.toUpperCase()}]',
                style: TextStyle(
                  color: color,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                issue.code,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          Text(
            issue.message,
            style: const TextStyle(color: Colors.white60, fontSize: 10),
          ),
          if (issue.nodePath.isNotEmpty)
            Text(
              '@${issue.nodePath}',
              style: const TextStyle(color: Colors.white38, fontSize: 9),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Prompt tab
// ─────────────────────────────────────────────

class _PromptTab extends StatelessWidget {
  const _PromptTab({this.prompt});
  final String? prompt;

  @override
  Widget build(BuildContext context) {
    if (prompt == null || prompt!.isEmpty) {
      return const _EmptyState('No system prompt provided.');
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: SelectableText(
        prompt!,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 10,
          fontFamily: 'monospace',
          height: 1.5,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Shared helpers
// ─────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState(this.message);
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        message,
        style: const TextStyle(color: Colors.white38, fontSize: 12),
      ),
    );
  }
}

class _CodeLine extends StatelessWidget {
  const _CodeLine(this.text, this.color);
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 11, fontFamily: 'monospace'),
      ),
    );
  }
}
