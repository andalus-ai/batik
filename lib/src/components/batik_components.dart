// lib/src/components/batik_components.dart
import 'package:flutter/material.dart';
import '../core/registry.dart';
import '../schema/ui_schema.dart';
import '../core/style_utils.dart';
import '../renderer/ui_renderer.dart';
import '../theme/batik_colors.dart';

class BatikComponents {
  static void register(UIComponentRegistry registry) {
    registry.register<CardNode>(_buildBatikCard);
    registry.register<ButtonNode>(_buildBatikButton);
    registry.register<TextNode>(_buildBatikText);
    registry.register<ContainerNode>(_buildBatikContainer);
    registry.register<ColumnNode>(_buildBatikColumn);
  }

  static Widget _buildBatikCard(
    BuildContext context,
    CardNode node,
    NodeRenderer renderer,
  ) {
    return Card(
      color: BatikColors.surface,
      elevation: node.elevation ?? 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(node.borderRadius ?? 12.0),
        side: BorderSide(color: BatikColors.primary.withOpacity(0.1)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: renderer.renderChildren(context, node.children),
        ),
      ),
    );
  }

  static Widget _buildBatikButton(
    BuildContext context,
    ButtonNode node,
    NodeRenderer renderer,
  ) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: BatikColors.primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      onPressed: () {},
      child: Text(node.label ?? ''),
    );
  }

  static Widget _buildBatikText(
    BuildContext context,
    TextNode node,
    NodeRenderer renderer,
  ) {
    return Text(
      node.text,
      style: TextStyle(
        color: BatikColors.textPrimary,
        fontSize: node.variant == 'headlineMedium' ? 24 : 16,
        fontWeight: node.variant == 'headlineMedium'
            ? FontWeight.bold
            : FontWeight.normal,
      ),
    );
  }

  static Widget _buildBatikContainer(
    BuildContext context,
    ContainerNode node,
    NodeRenderer renderer,
  ) {
    return Container(
      child: Column(children: renderer.renderChildren(context, node.children)),
    );
  }

  static Widget _buildBatikColumn(
    BuildContext context,
    ColumnNode node,
    NodeRenderer renderer,
  ) {
    return Column(children: renderer.renderChildren(context, node.children));
  }
}
