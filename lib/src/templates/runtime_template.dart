// lib/src/templates/runtime_template.dart
//
// Batik — Runtime Templates (Patch 049)
// ============================================================
// Macro application patterns that generate coordinated screen
// layouts from concise high-level specs.
//
// Instead of an LLM streaming 500 low-level widget nodes, it can output:
// {
//   "type": "template",
//   "template": "dashboard",
//   "title": "Executive Overview",
//   "metrics": [...],
//   "charts": [...],
//   "recentActivity": [...]
// }
// ============================================================

import 'package:flutter/material.dart';
import '../schema/ui_schema.dart';
import '../core/registry.dart';
import '../plugin/batik_plugin.dart';
import '../theme/batik_tokens.dart';

/// Base class for macro application templates in Batik.
abstract class RuntimeTemplate {
  const RuntimeTemplate();

  String get templateName;

  Widget build(BuildContext context, TemplateNode node, NodeRenderer renderer);
}

/// UINode for runtime templates.
class TemplateNode extends UINode with _TmplNodeJsonBase {
  TemplateNode({
    super.id,
    super.style,
    super.actions,
    super.condition,
    super.children,
    required this.templateName,
    this.title,
    this.data = const {},
  }) : super(type: 'template');

  final String templateName;
  final String? title;
  final Map<String, dynamic> data;

  factory TemplateNode.fromJson(Map<String, dynamic> j) => TemplateNode(
        id: j['id'] as String?,
        style: _parseTmplStyle(j),
        actions: _parseTmplActions(j),
        condition: j['condition'] as String?,
        templateName: j['template'] as String? ?? 'dashboard',
        title: j['title'] as String?,
        data: Map<String, dynamic>.from(j)
          ..removeWhere((k, _) => {'type', 'id', 'style', 'actions', 'condition', 'template', 'title', 'children'}.contains(k)),
        children: (j['children'] as List<dynamic>? ?? [])
            .map((c) => UINode.fromJson(c as Map<String, dynamic>))
            .toList(),
      );

  @override
  Map<String, dynamic> toJson() => {
        ..._baseTmplJson(),
        'template': templateName,
        if (title != null) 'title': title,
        ...data,
        if (children.isNotEmpty)
          'children': children.map((c) => c.toJson()).toList(),
      };
}

/// Registry of available runtime templates.
class RuntimeTemplateRegistry {
  RuntimeTemplateRegistry._();
  static final instance = RuntimeTemplateRegistry._();

  final _templates = <String, RuntimeTemplate>{};

  void register(RuntimeTemplate template) {
    _templates[template.templateName] = template;
  }

  void unregister(String name) => _templates.remove(name);

  RuntimeTemplate? operator [](String name) => _templates[name];

  bool has(String name) => _templates.containsKey(name);
}

// ─────────────────────────────────────────────
// Built-in Templates
// ─────────────────────────────────────────────

/// Executive KPI Dashboard Template.
class DashboardTemplate extends RuntimeTemplate {
  const DashboardTemplate();

  @override
  String get templateName => 'dashboard';

  @override
  Widget build(BuildContext context, TemplateNode node, NodeRenderer renderer) {
    final theme = Theme.of(context);
    final metrics = (node.data['metrics'] as List<dynamic>?) ?? [];
    final subtitle = node.data['subtitle'] as String?;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(BatikSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (node.title != null) ...[
            Text(node.title!, style: BatikTypography.headlineLarge),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(subtitle, style: BatikTypography.bodyMedium),
            ],
            const SizedBox(height: BatikSpacing.lg),
          ],
          if (metrics.isNotEmpty) ...[
            Wrap(
              spacing: BatikSpacing.md,
              runSpacing: BatikSpacing.md,
              children: metrics.map((m) {
                final map = m is Map<String, dynamic> ? m : <String, dynamic>{};
                return SizedBox(
                  width: 160,
                  child: Container(
                    padding: const EdgeInsets.all(BatikSpacing.md),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BatikRadius.roundedMd,
                      border: Border.all(color: theme.colorScheme.outlineVariant),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(map['label']?.toString() ?? '', style: BatikTypography.caption),
                        const SizedBox(height: 4),
                        Text(map['value']?.toString() ?? '', style: BatikTypography.headlineMedium),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: BatikSpacing.xl),
          ],
          if (node.children.isNotEmpty)
            ...renderer.renderChildren(context, node.children),
        ],
      ),
    );
  }
}

/// CRM / Contact Workspace Template.
class CrmTemplate extends RuntimeTemplate {
  const CrmTemplate();

  @override
  String get templateName => 'crm';

  @override
  Widget build(BuildContext context, TemplateNode node, NodeRenderer renderer) {
    final contacts = (node.data['contacts'] as List<dynamic>?) ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(BatikSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (node.title != null) ...[
            Text(node.title!, style: BatikTypography.headlineLarge),
            const SizedBox(height: BatikSpacing.lg),
          ],
          if (contacts.isNotEmpty) ...[
            const Text('Contacts', style: BatikTypography.titleMedium),
            const SizedBox(height: BatikSpacing.sm),
            ...contacts.map((c) {
              final map = c is Map<String, dynamic> ? c : <String, dynamic>{};
              return Card(
                margin: const EdgeInsets.only(bottom: BatikSpacing.sm),
                child: ListTile(
                  leading: CircleAvatar(
                    child: Text(
                      map['name'] != null && map['name'].toString().isNotEmpty
                          ? map['name'].toString()[0].toUpperCase()
                          : '?',
                    ),
                  ),
                  title: Text(map['name']?.toString() ?? 'Contact'),
                  subtitle: Text(map['email']?.toString() ?? map['role']?.toString() ?? ''),
                  trailing: map['status'] != null
                      ? Chip(label: Text(map['status'].toString(), style: const TextStyle(fontSize: 10)))
                      : null,
                ),
              );
            }),
          ],
          if (node.children.isNotEmpty)
            ...renderer.renderChildren(context, node.children),
        ],
      ),
    );
  }
}

/// Research Workspace Template.
class ResearchTemplate extends RuntimeTemplate {
  const ResearchTemplate();

  @override
  String get templateName => 'research';

  @override
  Widget build(BuildContext context, TemplateNode node, NodeRenderer renderer) {
    final topic = node.data['topic']?.toString() ?? node.title ?? 'Research Workspace';
    final findings = (node.data['findings'] as List<dynamic>?) ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(BatikSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.science_outlined, size: 28),
              const SizedBox(width: BatikSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(topic, style: BatikTypography.headlineLarge),
                    const Text('Autonomous Analysis Report', style: BatikTypography.caption),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: BatikSpacing.lg),
          if (findings.isNotEmpty) ...[
            const Text('Key Findings', style: BatikTypography.titleMedium),
            const SizedBox(height: BatikSpacing.sm),
            ...findings.map((f) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('• ', style: TextStyle(fontWeight: FontWeight.bold)),
                      Expanded(child: Text(f.toString(), style: BatikTypography.bodyLarge)),
                    ],
                  ),
                )),
            const SizedBox(height: BatikSpacing.lg),
          ],
          if (node.children.isNotEmpty)
            ...renderer.renderChildren(context, node.children),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// TemplatePlugin
// ─────────────────────────────────────────────

class TemplatePlugin extends BatikPlugin {
  const TemplatePlugin();

  @override
  PluginManifest get manifest => const PluginManifest(
        id: 'batik_templates',
        version: '0.1.0',
        capabilities: [PluginCapability.document],
        description: 'Macro application templates: dashboard, crm, and research.',
      );

  @override
  Future<void> initialize(BatikRuntime runtime) async {
    UINode.registerExternal('template', (j) => TemplateNode.fromJson(j));

    final registry = RuntimeTemplateRegistry.instance;
    registry.register(const DashboardTemplate());
    registry.register(const CrmTemplate());
    registry.register(const ResearchTemplate());
  }

  @override
  void registerNodes(UIComponentRegistry registry) {
    registry.register<TemplateNode>((context, node, renderer) {
      final tmpl = RuntimeTemplateRegistry.instance[node.templateName];
      if (tmpl == null) {
        return Container(
          padding: const EdgeInsets.all(12),
          child: Text('Unknown template: ${node.templateName}',
              style: const TextStyle(color: Colors.red)),
        );
      }
      return tmpl.build(context, node, renderer);
    });
  }

  @override
  String get systemPromptSection => '''
TemplateNode: {
  "type": "template",
  "template": "dashboard|crm|research",
  "title": "Page Title",
  // For dashboard:
  "metrics": [{"label": "Revenue", "value": "\$12,400"}],
  // For crm:
  "contacts": [{"name": "Jane", "email": "jane@co.com", "status": "Lead"}],
  // For research:
  "topic": "Market Trends",
  "findings": ["Trend A...", "Trend B..."],
  "children": [...]
}''';
}

// ── Private serialization helpers ─────────────────────────────
UIStyle? _parseTmplStyle(Map<String, dynamic> j) {
  final s = j['style'] as Map<String, dynamic>?;
  return s == null ? null : UIStyle.fromJson(s);
}

Map<String, UIAction> _parseTmplActions(Map<String, dynamic> j) {
  final raw = j['actions'] as Map<String, dynamic>?;
  if (raw == null) return const {};
  return raw
      .map((k, v) => MapEntry(k, UIAction.fromJson(v as Map<String, dynamic>)));
}

mixin _TmplNodeJsonBase on UINode {
  Map<String, dynamic> _baseTmplJson() => {
        'type': type,
        if (id != null) 'id': id,
        if (style != null) 'style': style!.toJson(),
        if (actions.isNotEmpty)
          'actions': actions.map((k, v) => MapEntry(k, v.toJson())),
        if (condition != null) 'condition': condition,
      };
}
