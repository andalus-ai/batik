// lib/src/document/document_node.dart
//
// Batik — Live Document Runtime (Patch 036)
// ============================================================
// Interactive, executable document model blending rich text,
// code blocks, embedded Tenun charts, and diagrams into a
// single cohesive narrative document.
//
// JSON schema:
// {
//   "type": "document",
//   "title": "Quarterly Financial Analysis",
//   "blocks": [
//     {"type": "heading", "level": 1, "text": "Executive Summary"},
//     {"type": "paragraph", "text": "Revenue grew by 24%..."},
//     {"type": "code", "language": "python", "code": "import pandas as pd..."},
//     {"type": "chart", "spec": {"kind": "bar", "series": [...]}},
//     {"type": "diagram", "mermaid": "flowchart LR\\nA-->B"}
//   ]
// }
// ============================================================

import 'package:flutter/material.dart';
import '../schema/ui_schema.dart';
import '../core/registry.dart';
import '../plugin/batik_plugin.dart';
import '../theme/batik_tokens.dart';
import '../tenun/tenun_adapter.dart';
import '../diagram/diagram_node_widget.dart';
import '../diagram/mermaid_parser.dart';

/// Base class for any block inside a [DocumentNode].
abstract class DocumentBlock {
  const DocumentBlock({required this.type});

  final String type;

  factory DocumentBlock.fromJson(Map<String, dynamic> j) {
    final type = j['type'] as String? ?? 'paragraph';
    return switch (type) {
      'heading' => HeadingBlock.fromJson(j),
      'paragraph' => ParagraphBlock.fromJson(j),
      'code' => CodeBlock.fromJson(j),
      'table' => TableBlock.fromJson(j),
      'chart' => ChartBlock.fromJson(j),
      'diagram' => DiagramBlock.fromJson(j),
      'image' => ImageBlock.fromJson(j),
      _ => ParagraphBlock(text: j['text']?.toString() ?? ''),
    };
  }

  Map<String, dynamic> toJson();
}

class HeadingBlock extends DocumentBlock {
  const HeadingBlock({required this.text, this.level = 1})
      : super(type: 'heading');

  final String text;
  final int level;

  factory HeadingBlock.fromJson(Map<String, dynamic> j) => HeadingBlock(
        text: j['text'] as String? ?? '',
        level: j['level'] as int? ?? 1,
      );

  @override
  Map<String, dynamic> toJson() => {'type': 'heading', 'text': text, 'level': level};
}

class ParagraphBlock extends DocumentBlock {
  const ParagraphBlock({required this.text}) : super(type: 'paragraph');

  final String text;

  factory ParagraphBlock.fromJson(Map<String, dynamic> j) =>
      ParagraphBlock(text: j['text'] as String? ?? '');

  @override
  Map<String, dynamic> toJson() => {'type': 'paragraph', 'text': text};
}

class CodeBlock extends DocumentBlock {
  const CodeBlock({required this.code, this.language}) : super(type: 'code');

  final String code;
  final String? language;

  factory CodeBlock.fromJson(Map<String, dynamic> j) => CodeBlock(
        code: j['code'] as String? ?? '',
        language: j['language'] as String?,
      );

  @override
  Map<String, dynamic> toJson() => {
        'type': 'code',
        'code': code,
        if (language != null) 'language': language,
      };
}

class TableBlock extends DocumentBlock {
  const TableBlock({required this.headers, required this.rows})
      : super(type: 'table');

  final List<String> headers;
  final List<List<String>> rows;

  factory TableBlock.fromJson(Map<String, dynamic> j) => TableBlock(
        headers: List<String>.from(j['headers'] as List? ?? []),
        rows: (j['rows'] as List? ?? [])
            .map((r) => List<String>.from(r as List? ?? []))
            .toList(),
      );

  @override
  Map<String, dynamic> toJson() => {
        'type': 'table',
        'headers': headers,
        'rows': rows,
      };
}

class ChartBlock extends DocumentBlock {
  const ChartBlock({required this.spec}) : super(type: 'chart');

  final ChartSpec spec;

  factory ChartBlock.fromJson(Map<String, dynamic> j) => ChartBlock(
        spec: ChartSpec.fromJson(j['spec'] as Map<String, dynamic>? ?? {}),
      );

  @override
  Map<String, dynamic> toJson() => {'type': 'chart', 'spec': spec.toJson()};
}

class DiagramBlock extends DocumentBlock {
  const DiagramBlock({this.mermaid, this.graphData}) : super(type: 'diagram');

  final String? mermaid;
  final Map<String, dynamic>? graphData;

  factory DiagramBlock.fromJson(Map<String, dynamic> j) => DiagramBlock(
        mermaid: j['mermaid'] as String?,
        graphData: j['graph'] as Map<String, dynamic>?,
      );

  @override
  Map<String, dynamic> toJson() => {
        'type': 'diagram',
        if (mermaid != null) 'mermaid': mermaid,
        if (graphData != null) 'graph': graphData,
      };
}

class ImageBlock extends DocumentBlock {
  const ImageBlock({required this.src, this.caption}) : super(type: 'image');

  final String src;
  final String? caption;

  factory ImageBlock.fromJson(Map<String, dynamic> j) => ImageBlock(
        src: j['src'] as String? ?? '',
        caption: j['caption'] as String?,
      );

  @override
  Map<String, dynamic> toJson() => {
        'type': 'image',
        'src': src,
        if (caption != null) 'caption': caption,
      };
}

/// UINode for Live Documents.
class DocumentNode extends UINode with _DocNodeJsonBase {
  DocumentNode({
    super.id,
    super.style,
    super.actions,
    super.condition,
    super.children,
    this.title,
    this.author,
    this.blocks = const [],
  }) : super(type: 'document');

  final String? title;
  final String? author;
  final List<DocumentBlock> blocks;

  factory DocumentNode.fromJson(Map<String, dynamic> j) => DocumentNode(
        id: j['id'] as String?,
        style: _parseDocStyle(j),
        actions: _parseDocActions(j),
        condition: j['condition'] as String?,
        title: j['title'] as String?,
        author: j['author'] as String?,
        blocks: (j['blocks'] as List<dynamic>? ?? [])
            .map((b) => DocumentBlock.fromJson(b as Map<String, dynamic>))
            .toList(),
        children: (j['children'] as List<dynamic>? ?? [])
            .map((c) => UINode.fromJson(c as Map<String, dynamic>))
            .toList(),
      );

  @override
  Map<String, dynamic> toJson() => {
        ..._baseDocJson(),
        if (title != null) 'title': title,
        if (author != null) 'author': author,
        'blocks': blocks.map((b) => b.toJson()).toList(),
        if (children.isNotEmpty)
          'children': children.map((c) => c.toJson()).toList(),
      };
}

/// Renderer for DocumentNode.
class DocumentRendererWidget extends StatelessWidget {
  const DocumentRendererWidget({super.key, required this.node});

  final DocumentNode node;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(BatikSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (node.title != null) ...[
            Text(node.title!, style: BatikTypography.displayLarge),
            if (node.author != null) ...[
              const SizedBox(height: 4),
              Text('By ${node.author}', style: BatikTypography.caption),
            ],
            const Divider(height: 32),
          ],
          ...node.blocks.map((block) => _renderBlock(context, block, theme)),
        ],
      ),
    );
  }

  Widget _renderBlock(BuildContext context, DocumentBlock block, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: BatikSpacing.md),
      child: switch (block) {
        HeadingBlock h => Text(
            h.text,
            style: h.level == 1
                ? BatikTypography.headlineLarge
                : h.level == 2
                    ? BatikTypography.headlineMedium
                    : BatikTypography.titleMedium,
          ),
        ParagraphBlock p => Text(p.text, style: BatikTypography.bodyLarge),
        CodeBlock c => Container(
            width: double.infinity,
            padding: const EdgeInsets.all(BatikSpacing.md),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BatikRadius.roundedSm,
            ),
            child: Text(
              c.code,
              style: const TextStyle(
                fontFamily: 'monospace',
                color: Color(0xFFD4D4D4),
                fontSize: 12,
              ),
            ),
          ),
        TableBlock t => SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: t.headers.map((h) => DataColumn(label: Text(h))).toList(),
              rows: t.rows
                  .map((r) => DataRow(cells: r.map((c) => DataCell(Text(c))).toList()))
                  .toList(),
            ),
          ),
        ChartBlock ch => TenunChartRenderer(
            node: TenunChartNode(spec: ch.spec),
          ),
        DiagramBlock d => d.mermaid != null
            ? DiagramUINode(graph: const MermaidParser().parse(d.mermaid!))
                is Widget
                ? const SizedBox.shrink()
                : _renderMermaid(context, d.mermaid!)
            : const SizedBox.shrink(),
        ImageBlock im => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BatikRadius.roundedMd,
                child: Image.network(
                  im.src,
                  errorBuilder: (_, __, ___) => Container(
                    height: 120,
                    color: theme.colorScheme.surfaceContainerHighest,
                    child: const Center(child: Icon(Icons.broken_image)),
                  ),
                ),
              ),
              if (im.caption != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(im.caption!, style: BatikTypography.caption),
                ),
            ],
          ),
        _ => const SizedBox.shrink(),
      },
    );
  }

  Widget _renderMermaid(BuildContext context, String source) {
    try {
      final graph = const MermaidParser().parse(source);
      return const DiagramPlugin().manifest.capabilities.isNotEmpty
          ? Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                borderRadius: BatikRadius.roundedMd,
              ),
              child: Text('Flowchart (${graph.nodes.length} nodes)'),
            )
          : const SizedBox.shrink();
    } catch (_) {
      return const SizedBox.shrink();
    }
  }
}

/// Plugin registering DocumentNode into Batik.
class DocumentPlugin extends BatikPlugin {
  const DocumentPlugin();

  @override
  PluginManifest get manifest => const PluginManifest(
        id: 'batik_document',
        version: '0.1.0',
        capabilities: [PluginCapability.document],
        description: 'Live interactive document runtime with markdown, code, charts, and diagrams.',
      );

  @override
  Future<void> initialize(BatikRuntime runtime) async {
    UINode.registerExternal('document', (j) => DocumentNode.fromJson(j));
  }

  @override
  void registerNodes(UIComponentRegistry registry) {
    registry.register<DocumentNode>((context, node, renderer) {
      return DocumentRendererWidget(node: node);
    });
  }

  @override
  String get systemPromptSection => '''
DocumentNode: {
  "type": "document",
  "title": "Document Title",
  "author": "Author Name",
  "blocks": [
    {"type": "heading", "level": 1|2|3, "text": "..."},
    {"type": "paragraph", "text": "..."},
    {"type": "code", "language": "dart", "code": "..."},
    {"type": "table", "headers": ["A", "B"], "rows": [["1", "2"]]},
    {"type": "chart", "spec": {"kind": "bar", "series": [...]}},
    {"type": "diagram", "mermaid": "flowchart LR\\nA-->B"}
  ]
}''';
}

// ── Private serialization helpers ─────────────────────────────
UIStyle? _parseDocStyle(Map<String, dynamic> j) {
  final s = j['style'] as Map<String, dynamic>?;
  return s == null ? null : UIStyle.fromJson(s);
}

Map<String, UIAction> _parseDocActions(Map<String, dynamic> j) {
  final raw = j['actions'] as Map<String, dynamic>?;
  if (raw == null) return const {};
  return raw
      .map((k, v) => MapEntry(k, UIAction.fromJson(v as Map<String, dynamic>)));
}

mixin _DocNodeJsonBase on UINode {
  Map<String, dynamic> _baseDocJson() => {
        'type': type,
        if (id != null) 'id': id,
        if (style != null) 'style': style!.toJson(),
        if (actions.isNotEmpty)
          'actions': actions.map((k, v) => MapEntry(k, v.toJson())),
        if (condition != null) 'condition': condition,
      };
}
