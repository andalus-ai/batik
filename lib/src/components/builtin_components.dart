// lib/src/components/builtin_components.dart
//
// Batik Framework — Built-in Component Builders
// ============================================================
// Registers all standard node types into the [UIComponentRegistry].
// Call [registerBuiltinComponents()] once at app startup.
// ============================================================

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../core/registry.dart';
import '../core/style_utils.dart';
import '../schema/ui_schema.dart';
import '../renderer/ui_renderer.dart';

void registerBuiltinComponents([UIComponentRegistry? reg]) {
  final r = reg ?? UIComponentRegistry.instance;

  // ── Layout ───────────────────────────────────────────────
  r.register<ContainerNode>(_buildContainer);
  r.register<RowNode>(_buildRow);
  r.register<ColumnNode>(_buildColumn);
  r.register<StackNode>(_buildStack);

  // ── Content ──────────────────────────────────────────────
  r.register<TextNode>(_buildText);
  r.register<RichTextNode>(_buildRichText);
  r.register<ImageNode>(_buildImage);
  r.register<IconNode>(_buildIcon);
  r.register<MarkdownNode>(_buildMarkdown);

  // ── Interactive ───────────────────────────────────────────
  r.register<ButtonNode>(_buildButton);
  r.register<IconButtonNode>(_buildIconButton);
  r.register<TextFieldNode>(_buildTextField);
  r.register<SwitchNode>(_buildSwitch);
  r.register<SliderNode>(_buildSlider);
  r.register<DropdownNode>(_buildDropdown);

  // ── Structural ────────────────────────────────────────────
  r.register<CardNode>(_buildCard);
  r.register<ListNode>(_buildList);
  r.register<ListItemNode>(_buildListItem);
  r.register<GridNode>(_buildGrid);
  r.register<FormNode>(_buildForm);

  // ── Scaffold / Nav ────────────────────────────────────────
  r.register<ScaffoldNode>(_buildScaffold);
  r.register<AppBarNode>(_buildAppBar);
  r.register<BottomNavNode>(_buildBottomNav);
  r.register<FabNode>(_buildFab);

  // ── Overlays ──────────────────────────────────────────────
  r.register<DialogNode>(_buildDialog);
  r.register<SnackbarNode>(_buildSnackbar);

  // ── Decoration ────────────────────────────────────────────
  r.register<DividerNode>(_buildDivider);
  r.register<SpacerNode>(_buildSpacer);
  r.register<BadgeNode>(_buildBadge);
  r.register<ChipNode>(_buildChip);
  r.register<AvatarNode>(_buildAvatar);
  r.register<ProgressBarNode>(_buildProgress);

  // ── Rich / Plugin ─────────────────────────────────────────
  r.register<ChartNode>(_buildChart);
  r.register<MapNode>(_buildMap);
  r.register<WebViewNode>(_buildWebView);
  r.register<CustomNode>(_buildCustomFallback);

  // UnknownNode is handled by the renderer as a fallback.
}

// ════════════════════════════════════════════════════════════
// LAYOUT
// ════════════════════════════════════════════════════════════

Widget _buildContainer(BuildContext ctx, ContainerNode node, NodeRenderer r) {
  Widget child = node.children.length == 1
      ? r.render(ctx, node.children.first)
      : Column(children: r.renderChildren(ctx, node.children));

  if (node.actions['onTap'] != null) {
    child = GestureDetector(
      onTap: () => ctx.agentDispatcher.dispatch(ctx, node.actions['onTap']!),
      child: child,
    );
  }
  return applyStyle(child, node.style);
}

Widget _buildRow(BuildContext ctx, RowNode node, NodeRenderer r) {
  final children = r.renderChildren(ctx, node.children);
  final row = Row(
    mainAxisAlignment: _mainAxisAlignment(node.mainAxisAlignment),
    crossAxisAlignment: _crossAxisAlignment(node.crossAxisAlignment),
    mainAxisSize: node.mainAxisSize == 'min'
        ? MainAxisSize.min
        : MainAxisSize.max,
    children: children,
  );
  return applyStyle(row, node.style);
}

Widget _buildColumn(BuildContext ctx, ColumnNode node, NodeRenderer r) {
  final children = r.renderChildren(ctx, node.children);
  final col = Column(
    mainAxisAlignment: _mainAxisAlignment(node.mainAxisAlignment),
    crossAxisAlignment: _crossAxisAlignment(node.crossAxisAlignment),
    mainAxisSize: node.mainAxisSize == 'min'
        ? MainAxisSize.min
        : MainAxisSize.max,
    children: children,
  );
  return applyStyle(col, node.style);
}

Widget _buildStack(BuildContext ctx, StackNode node, NodeRenderer r) {
  final stack = Stack(
    alignment: parseAlignment(node.alignment) ?? Alignment.topLeft,
    fit: node.fit == 'expand'
        ? StackFit.expand
        : node.fit == 'passthrough'
        ? StackFit.passthrough
        : StackFit.loose,
    children: r.renderChildren(ctx, node.children),
  );
  return applyStyle(stack, node.style);
}

// ════════════════════════════════════════════════════════════
// CONTENT
// ════════════════════════════════════════════════════════════

Widget _buildText(BuildContext ctx, TextNode node, NodeRenderer r) {
  final theme = Theme.of(ctx);
  TextStyle? base = _textStyleFromVariant(node.variant, theme);
  final style = buildTextStyle(node.style, base);

  Widget w = node.selectable == true
      ? SelectableText(
          node.text,
          style: style,
          textAlign: parseTextAlign(node.style?.textAlign),
        )
      : Text(
          node.text,
          style: style,
          textAlign: parseTextAlign(node.style?.textAlign),
          overflow: parseOverflow(node.style?.overflow),
        );

  if (node.actions['onTap'] != null) {
    w = GestureDetector(
      onTap: () => ctx.agentDispatcher.dispatch(ctx, node.actions['onTap']!),
      child: w,
    );
  }
  return applyStyle(w, node.style);
}

Widget _buildRichText(BuildContext ctx, RichTextNode node, NodeRenderer r) {
  final spans = node.spans.map((s) {
    final style = buildTextStyle(s.style);
    if (s.actionOnTap != null) {
      return TextSpan(
        text: s.text,
        style: style,
        recognizer: _tapRecognizer(ctx, s.actionOnTap!),
      );
    }
    return TextSpan(text: s.text, style: style);
  }).toList();

  return applyStyle(RichText(text: TextSpan(children: spans)), node.style);
}

Widget _buildImage(BuildContext ctx, ImageNode node, NodeRenderer r) {
  final fit = parseBoxFit(node.fit) ?? BoxFit.cover;
  Widget img;

  final src = node.src;
  final type =
      node.srcType ??
      (src.startsWith('http') || src.startsWith('//')
          ? 'network'
          : src.startsWith('data:')
          ? 'base64'
          : 'asset');

  if (type == 'network') {
    img = Image.network(
      src,
      fit: fit,
      errorBuilder: (_, __, ___) =>
          const Icon(Icons.broken_image, color: Colors.grey),
    );
  } else if (type == 'asset') {
    img = Image.asset(src, fit: fit);
  } else {
    // base64 — strip header
    final data = src.contains(',') ? src.split(',').last : src;
    img = Image.memory(
      Uri.parse('data:image/png;base64,$data').data!.contentAsBytes(),
      fit: fit,
    );
  }

  if (node.style?.borderRadius != null) {
    img = ClipRRect(
      borderRadius: BorderRadius.circular(node.style!.borderRadius!),
      child: img,
    );
  }

  if (node.actions['onTap'] != null) {
    img = GestureDetector(
      onTap: () => ctx.agentDispatcher.dispatch(ctx, node.actions['onTap']!),
      child: img,
    );
  }

  return applyStyle(img, node.style);
}

Widget _buildIcon(BuildContext ctx, IconNode node, NodeRenderer r) {
  return applyStyle(
    Icon(
      resolveIcon(node.icon),
      size: node.size,
      color: parseColor(node.color),
    ),
    node.style,
  );
}

Widget _buildMarkdown(BuildContext ctx, MarkdownNode node, NodeRenderer r) {
  // Basic markdown-to-text fallback.
  // Swap for flutter_markdown if available.
  return applyStyle(
    SelectableText(node.content, style: Theme.of(ctx).textTheme.bodyMedium),
    node.style,
  );
}

// ════════════════════════════════════════════════════════════
// INTERACTIVE
// ════════════════════════════════════════════════════════════

Widget _buildButton(BuildContext ctx, ButtonNode node, NodeRenderer r) {
  final onTap = node.actions['onTap'];
  final disabled = node.disabled == true;
  final isLoading = node.loading == true;

  Widget label = isLoading
      ? const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        )
      : node.children.isNotEmpty
      ? Row(
          mainAxisSize: MainAxisSize.min,
          children: r.renderChildren(ctx, node.children),
        )
      : Text(node.label ?? '');

  if (node.icon != null && !isLoading) {
    label = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(resolveIcon(node.icon!), size: 18),
        const SizedBox(width: 6),
        Flexible(child: label),
      ],
    );
  }

  VoidCallback? handler = disabled || isLoading || onTap == null
      ? null
      : () => ctx.agentDispatcher.dispatch(ctx, onTap);

  final buttonStyle = _buttonStyleFromUIStyle(node.style);

  Widget btn;
  switch (node.variant) {
    case 'outlined':
      btn = OutlinedButton(
        onPressed: handler,
        style: buttonStyle,
        child: label,
      );
      break;
    case 'text':
      btn = TextButton(onPressed: handler, style: buttonStyle, child: label);
      break;
    case 'tonal':
      btn = FilledButton.tonal(
        onPressed: handler,
        style: buttonStyle,
        child: label,
      );
      break;
    case 'filled':
      btn = FilledButton(onPressed: handler, style: buttonStyle, child: label);
      break;
    default: // "elevated" or unspecified
      btn = ElevatedButton(
        onPressed: handler,
        style: buttonStyle,
        child: label,
      );
  }

  return applyStyle(btn, node.style);
}

Widget _buildIconButton(BuildContext ctx, IconButtonNode node, NodeRenderer r) {
  return applyStyle(
    IconButton(
      icon: Icon(resolveIcon(node.icon)),
      tooltip: node.tooltip,
      onPressed: node.disabled == true
          ? null
          : node.actions['onTap'] != null
          ? () => ctx.agentDispatcher.dispatch(ctx, node.actions['onTap']!)
          : null,
    ),
    node.style,
  );
}

Widget _buildTextField(BuildContext ctx, TextFieldNode node, NodeRenderer r) {
  final store = ctx.agentVariables;
  final binding = node.variableBinding;
  final initialValue = binding != null
      ? store.get<String>(binding) ?? node.value
      : node.value;

  return applyStyle(
    TextFormField(
      initialValue: initialValue,
      enabled: node.disabled != true,
      obscureText: node.obscureText ?? false,
      keyboardType: _keyboardType(node.inputType),
      maxLines: node.obscureText == true
          ? 1
          : node.multiline == true
          ? node.maxLines ?? 5
          : 1,
      minLines: node.minLines,
      decoration: InputDecoration(
        labelText: node.label,
        hintText: node.placeholder,
        helperText: node.helperText,
        errorText: node.errorText,
        prefixIcon: node.prefixIcon != null
            ? Icon(resolveIcon(node.prefixIcon!))
            : null,
        suffixIcon: node.suffixIcon != null
            ? Icon(resolveIcon(node.suffixIcon!))
            : null,
      ),
      onChanged: (val) {
        if (binding != null) store.set(binding, val);
        final action = node.actions['onChange'];
        if (action != null) {
          ctx.agentDispatcher.dispatch(
            ctx,
            UIAction(
              type: action.type,
              payload: {...action.payload, 'value': val},
            ),
          );
        }
      },
      onFieldSubmitted: (val) {
        final action = node.actions['onSubmit'];
        if (action != null) {
          ctx.agentDispatcher.dispatch(
            ctx,
            UIAction(
              type: action.type,
              payload: {...action.payload, 'value': val},
            ),
          );
        }
      },
    ),
    node.style,
  );
}

Widget _buildSwitch(BuildContext ctx, SwitchNode node, NodeRenderer r) {
  final store = ctx.agentVariables;
  final binding = node.variableBinding;
  final currentVal = binding != null
      ? (store.get<bool>(binding) ?? node.value)
      : node.value;

  Widget sw = Switch(
    value: currentVal,
    onChanged: (v) {
      if (binding != null) store.set(binding, v);
      final action = node.actions['onChange'];
      if (action != null) {
        ctx.agentDispatcher.dispatch(
          ctx,
          UIAction(type: action.type, payload: {...action.payload, 'value': v}),
        );
      }
    },
  );

  if (node.label != null) {
    sw = Row(
      children: [
        Expanded(child: Text(node.label!)),
        sw,
      ],
    );
  }
  return applyStyle(sw, node.style);
}

Widget _buildSlider(BuildContext ctx, SliderNode node, NodeRenderer r) {
  final store = ctx.agentVariables;
  final binding = node.variableBinding;
  final currentVal = binding != null
      ? (store.get<double>(binding) ?? node.value)
      : node.value;

  return applyStyle(
    Slider(
      value: currentVal.clamp(node.min ?? 0, node.max ?? 1),
      min: node.min ?? 0,
      max: node.max ?? 1,
      divisions: node.divisions,
      label: node.label,
      onChanged: (v) {
        if (binding != null) store.set(binding, v);
        final action = node.actions['onChange'];
        if (action != null) {
          ctx.agentDispatcher.dispatch(
            ctx,
            UIAction(
              type: action.type,
              payload: {...action.payload, 'value': v},
            ),
          );
        }
      },
    ),
    node.style,
  );
}

Widget _buildDropdown(BuildContext ctx, DropdownNode node, NodeRenderer r) {
  final store = ctx.agentVariables;
  final binding = node.variableBinding;
  final currentVal = binding != null
      ? store.get<String>(binding) ?? node.value
      : node.value;

  return applyStyle(
    DropdownButtonFormField<String>(
      value: currentVal,
      decoration: InputDecoration(labelText: node.label),
      items: node.options
          .map((o) => DropdownMenuItem(value: o.value, child: Text(o.label)))
          .toList(),
      onChanged: (v) {
        if (v == null) return;
        if (binding != null) store.set(binding, v);
        final action = node.actions['onChange'];
        if (action != null) {
          ctx.agentDispatcher.dispatch(
            ctx,
            UIAction(
              type: action.type,
              payload: {...action.payload, 'value': v},
            ),
          );
        }
      },
    ),
    node.style,
  );
}

// ════════════════════════════════════════════════════════════
// STRUCTURAL
// ════════════════════════════════════════════════════════════

Widget _buildCard(BuildContext ctx, CardNode node, NodeRenderer r) {
  final child = Column(children: r.renderChildren(ctx, node.children));
  Widget card = Card(
    elevation: node.elevation ?? node.style?.elevation,
    shape: node.borderRadius != null
        ? RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(node.borderRadius!),
          )
        : null,
    child: applyStyle(child, node.style),
  );
  if (node.actions['onTap'] != null) {
    card = InkWell(
      onTap: () => ctx.agentDispatcher.dispatch(ctx, node.actions['onTap']!),
      borderRadius: node.borderRadius != null
          ? BorderRadius.circular(node.borderRadius!)
          : null,
      child: card,
    );
  }
  return card;
}

Widget _buildList(BuildContext ctx, ListNode node, NodeRenderer r) {
  Widget list;
  final items = r.renderChildren(ctx, node.children);
  final isH = node.scrollDirection == 'horizontal';

  if (node.shrinkWrap == true) {
    final sep = node.separator != null ? r.render(ctx, node.separator!) : null;
    list = ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      scrollDirection: isH ? Axis.horizontal : Axis.vertical,
      itemCount: items.length,
      itemBuilder: (_, i) => items[i],
      separatorBuilder: (_, __) => sep ?? const SizedBox.shrink(),
    );
  } else {
    list = ListView(
      scrollDirection: isH ? Axis.horizontal : Axis.vertical,
      itemExtent: node.itemExtent,
      children: items,
    );
  }
  return applyStyle(list, node.style);
}

Widget _buildListItem(BuildContext ctx, ListItemNode node, NodeRenderer r) {
  Widget tile = ListTile(
    selected: node.selected ?? false,
    leading: node.leading != null ? r.render(ctx, node.leading!) : null,
    title: node.title != null ? r.render(ctx, node.title!) : null,
    subtitle: node.subtitle != null ? r.render(ctx, node.subtitle!) : null,
    trailing: node.trailing != null ? r.render(ctx, node.trailing!) : null,
    onTap: node.actions['onTap'] != null
        ? () => ctx.agentDispatcher.dispatch(ctx, node.actions['onTap']!)
        : null,
  );
  if (node.children.isNotEmpty) {
    tile = Column(children: [tile, ...r.renderChildren(ctx, node.children)]);
  }
  return applyStyle(tile, node.style);
}

Widget _buildGrid(BuildContext ctx, GridNode node, NodeRenderer r) {
  return applyStyle(
    GridView.count(
      shrinkWrap: true,
      crossAxisCount: node.crossAxisCount ?? 2,
      childAspectRatio: node.childAspectRatio ?? 1.0,
      mainAxisSpacing: node.mainAxisSpacing ?? 0,
      crossAxisSpacing: node.crossAxisSpacing ?? 0,
      children: r.renderChildren(ctx, node.children),
    ),
    node.style,
  );
}

Widget _buildForm(BuildContext ctx, FormNode node, NodeRenderer r) {
  final key = GlobalKey<FormState>();
  return applyStyle(
    Form(
      key: key,
      child: Column(children: r.renderChildren(ctx, node.children)),
    ),
    node.style,
  );
}

// ════════════════════════════════════════════════════════════
// SCAFFOLD / NAV
// ════════════════════════════════════════════════════════════

Widget _buildScaffold(BuildContext ctx, ScaffoldNode node, NodeRenderer r) {
  return Scaffold(
    backgroundColor: parseColor(node.backgroundColor),
    appBar: node.appBar != null
        ? _buildAppBarWidget(ctx, node.appBar!, r)
        : null,
    body: node.body != null ? r.render(ctx, node.body!) : null,
    bottomNavigationBar: node.bottomNav != null
        ? r.render(ctx, node.bottomNav!)
        : null,
    floatingActionButton: node.fab != null ? r.render(ctx, node.fab!) : null,
    drawer: node.drawer != null ? r.render(ctx, node.drawer!) : null,
  );
}

Widget _buildAppBar(BuildContext ctx, AppBarNode node, NodeRenderer r) {
  return SizedBox(
    height: kToolbarHeight,
    child: _buildAppBarWidget(ctx, node, r),
  );
}

PreferredSizeWidget _buildAppBarWidget(
  BuildContext ctx,
  AppBarNode node,
  NodeRenderer r,
) {
  return AppBar(
    backgroundColor: parseColor(node.backgroundColor),
    elevation: node.elevation,
    centerTitle: node.centerTitle,
    title: node.title != null ? r.render(ctx, node.title!) : null,
    leading: node.leading != null ? r.render(ctx, node.leading!) : null,
    actions: node.actions_nodes?.map((n) => r.render(ctx, n)).toList() ?? [],
  );
}

Widget _buildBottomNav(BuildContext ctx, BottomNavNode node, NodeRenderer r) {
  return BottomNavigationBar(
    currentIndex: node.currentIndex ?? 0,
    backgroundColor: parseColor(node.backgroundColor),
    items: node.items
        .map(
          (i) => BottomNavigationBarItem(
            icon: Icon(resolveIcon(i.icon)),
            activeIcon: i.activeIcon != null
                ? Icon(resolveIcon(i.activeIcon!))
                : null,
            label: i.label ?? '',
          ),
        )
        .toList(),
    onTap: (index) {
      final action = node.actions['onTap'];
      if (action != null) {
        ctx.agentDispatcher.dispatch(
          ctx,
          UIAction(
            type: action.type,
            payload: {...action.payload, 'index': index},
          ),
        );
      }
    },
  );
}

Widget _buildFab(BuildContext ctx, FabNode node, NodeRenderer r) {
  final onPressed = node.actions['onTap'] != null
      ? () => ctx.agentDispatcher.dispatch(ctx, node.actions['onTap']!)
      : null;

  if (node.extended == true && node.label != null) {
    return FloatingActionButton.extended(
      onPressed: onPressed,
      icon: Icon(resolveIcon(node.icon)),
      label: Text(node.label!),
      backgroundColor: parseColor(node.backgroundColor),
      foregroundColor: parseColor(node.foregroundColor),
    );
  }
  return FloatingActionButton(
    onPressed: onPressed,
    backgroundColor: parseColor(node.backgroundColor),
    foregroundColor: parseColor(node.foregroundColor),
    mini: node.mini ?? false,
    child: Icon(resolveIcon(node.icon)),
  );
}

// ════════════════════════════════════════════════════════════
// OVERLAYS
// ════════════════════════════════════════════════════════════

Widget _buildDialog(BuildContext ctx, DialogNode node, NodeRenderer r) {
  // Dialogs are typically triggered imperatively; render inline as a Card.
  return Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (node.title != null) r.render(ctx, node.title!),
          if (node.content != null) r.render(ctx, node.content!),
          ...r.renderChildren(ctx, node.children),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (node.cancelAction != null)
                TextButton(
                  onPressed: () =>
                      ctx.agentDispatcher.dispatch(ctx, node.cancelAction!),
                  child: const Text('Cancel'),
                ),
              if (node.confirmAction != null)
                FilledButton(
                  onPressed: () =>
                      ctx.agentDispatcher.dispatch(ctx, node.confirmAction!),
                  child: const Text('OK'),
                ),
            ],
          ),
        ],
      ),
    ),
  );
}

Widget _buildSnackbar(BuildContext ctx, SnackbarNode node, NodeRenderer r) {
  // Auto-show snackbar on render. Use WidgetsBinding to avoid frame issues.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final messenger = ScaffoldMessenger.maybeOf(ctx);
    if (messenger == null) return;
    final snackbar = SnackBar(
      content: Text(node.message),
      duration: Duration(milliseconds: node.duration ?? 4000),
      action: node.actionLabel != null && node.actionOnTap != null
          ? SnackBarAction(
              label: node.actionLabel!,
              onPressed: () =>
                  ctx.agentDispatcher.dispatch(ctx, node.actionOnTap!),
            )
          : null,
    );
    messenger.showSnackBar(snackbar);
  });
  return const SizedBox.shrink();
}

// ════════════════════════════════════════════════════════════
// DECORATION / MISC
// ════════════════════════════════════════════════════════════

Widget _buildDivider(BuildContext ctx, DividerNode node, NodeRenderer r) {
  if (node.direction == 'vertical') {
    return VerticalDivider(
      thickness: node.thickness,
      color: parseColor(node.color),
      indent: node.indent,
      endIndent: node.endIndent,
    );
  }
  return Divider(
    thickness: node.thickness,
    color: parseColor(node.color),
    indent: node.indent,
    endIndent: node.endIndent,
  );
}

Widget _buildSpacer(BuildContext ctx, SpacerNode node, NodeRenderer r) {
  if (node.flex != null) return Spacer(flex: node.flex!);
  return SizedBox(width: node.width, height: node.height);
}

Widget _buildBadge(BuildContext ctx, BadgeNode node, NodeRenderer r) {
  Widget child = node.children.isNotEmpty
      ? r.render(ctx, node.children.first)
      : const SizedBox();
  if (node.label != null) {
    child = Badge.count(
      count: int.tryParse(node.label ?? '0') ?? 0,
      child: child,
    );
  }
  return applyStyle(child, node.style);
}

Widget _buildChip(BuildContext ctx, ChipNode node, NodeRenderer r) {
  Widget chip;
  final icon = node.icon != null ? Icon(resolveIcon(node.icon!)) : null;
  final onTap = node.actions['onTap'];
  final onDelete = node.actions['onDelete'];

  if (node.variant == 'filter' || node.selected != null) {
    chip = FilterChip(
      label: Text(node.label),
      avatar: icon,
      selected: node.selected ?? false,
      onSelected: onTap != null
          ? (v) => ctx.agentDispatcher.dispatch(
              ctx,
              UIAction(
                type: onTap.type,
                payload: {...onTap.payload, 'selected': v},
              ),
            )
          : null,
    );
  } else {
    chip = ActionChip(
      label: Text(node.label),
      avatar: icon,
      onPressed: onTap != null
          ? () => ctx.agentDispatcher.dispatch(ctx, onTap)
          : null,
    );
  }
  return applyStyle(chip, node.style);
}

Widget _buildAvatar(BuildContext ctx, AvatarNode node, NodeRenderer r) {
  final radius = (node.size ?? 40) / 2;
  Widget avatar;
  if (node.src != null) {
    avatar = CircleAvatar(
      radius: radius,
      backgroundImage: NetworkImage(node.src!),
      backgroundColor: parseColor(node.backgroundColor),
    );
  } else {
    avatar = CircleAvatar(
      radius: radius,
      backgroundColor: parseColor(node.backgroundColor),
      child: Text(
        node.initials ?? '?',
        style: TextStyle(color: parseColor(node.foregroundColor)),
      ),
    );
  }
  return applyStyle(avatar, node.style);
}

Widget _buildProgress(BuildContext ctx, ProgressBarNode node, NodeRenderer r) {
  final color = parseColor(node.color);
  final bg = parseColor(node.backgroundColor);

  Widget w;
  if (node.variant == 'circular') {
    w = CircularProgressIndicator(
      value: node.value,
      color: color,
      backgroundColor: bg,
      strokeWidth: node.strokeWidth ?? 4.0,
    );
  } else {
    w = LinearProgressIndicator(
      value: node.value,
      color: color,
      backgroundColor: bg,
    );
  }
  return applyStyle(w, node.style);
}

// ════════════════════════════════════════════════════════════
// RICH / PLUGIN
// ════════════════════════════════════════════════════════════

Widget _buildChart(BuildContext ctx, ChartNode node, NodeRenderer r) {
  // Placeholder — swap for fl_chart / syncfusion / charts_flutter integration.
  return applyStyle(
    Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bar_chart, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 8),
          Text(
            node.title ?? node.chartType,
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 4),
          Text(
            '[Chart: register ChartNodeBuilder to render]',
            style: TextStyle(color: Colors.grey.shade400, fontSize: 10),
          ),
        ],
      ),
    ),
    node.style,
  );
}

Widget _buildMap(BuildContext ctx, MapNode node, NodeRenderer r) {
  return applyStyle(
    Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.map, size: 48, color: Colors.blue.shade300),
          const SizedBox(height: 8),
          Text(
            '${node.lat.toStringAsFixed(4)}, ${node.lng.toStringAsFixed(4)}',
            style: TextStyle(color: Colors.blue.shade700),
          ),
          const SizedBox(height: 4),
          Text(
            '[Map: register MapNodeBuilder to render]',
            style: TextStyle(color: Colors.blue.shade300, fontSize: 10),
          ),
        ],
      ),
    ),
    node.style,
  );
}

Widget _buildWebView(BuildContext ctx, WebViewNode node, NodeRenderer r) {
  return applyStyle(
    Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.open_in_browser, color: Colors.grey.shade400, size: 36),
          const SizedBox(height: 6),
          Text(
            node.url,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),
        ],
      ),
    ),
    node.style,
  );
}

Widget _buildCustomFallback(BuildContext ctx, CustomNode node, NodeRenderer r) {
  return Container(
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      border: Border.all(color: Colors.purple.shade200),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(
      'Custom component "${node.componentId}" not registered.',
      style: TextStyle(color: Colors.purple.shade700, fontSize: 12),
    ),
  );
}

// ════════════════════════════════════════════════════════════
// HELPERS
// ════════════════════════════════════════════════════════════

MainAxisAlignment _mainAxisAlignment(String? raw) {
  return const {
        'start': MainAxisAlignment.start,
        'end': MainAxisAlignment.end,
        'center': MainAxisAlignment.center,
        'spaceBetween': MainAxisAlignment.spaceBetween,
        'spaceAround': MainAxisAlignment.spaceAround,
        'spaceEvenly': MainAxisAlignment.spaceEvenly,
      }[raw] ??
      MainAxisAlignment.start;
}

CrossAxisAlignment _crossAxisAlignment(String? raw) {
  return const {
        'start': CrossAxisAlignment.start,
        'end': CrossAxisAlignment.end,
        'center': CrossAxisAlignment.center,
        'stretch': CrossAxisAlignment.stretch,
        'baseline': CrossAxisAlignment.baseline,
      }[raw] ??
      CrossAxisAlignment.center;
}

TextInputType _keyboardType(String? type) {
  return const {
        'number': TextInputType.number,
        'email': TextInputType.emailAddress,
        'phone': TextInputType.phone,
        'url': TextInputType.url,
        'multiline': TextInputType.multiline,
        'password': TextInputType.visiblePassword,
      }[type] ??
      TextInputType.text;
}

TextStyle? _textStyleFromVariant(String? variant, ThemeData theme) {
  if (variant == null) return null;
  return const {
        'displayLarge': 'displayLarge',
        'displayMedium': 'displayMedium',
        'displaySmall': 'displaySmall',
        'headlineLarge': 'headlineLarge',
        'headlineMedium': 'headlineMedium',
        'headlineSmall': 'headlineSmall',
        'titleLarge': 'titleLarge',
        'titleMedium': 'titleMedium',
        'titleSmall': 'titleSmall',
        'bodyLarge': 'bodyLarge',
        'bodyMedium': 'bodyMedium',
        'bodySmall': 'bodySmall',
        'labelLarge': 'labelLarge',
        'labelMedium': 'labelMedium',
        'labelSmall': 'labelSmall',
      }.containsKey(variant)
      ? _getTextThemeStyle(theme.textTheme, variant)
      : null;
}

TextStyle? _getTextThemeStyle(TextTheme t, String variant) {
  return switch (variant) {
    'displayLarge' => t.displayLarge,
    'displayMedium' => t.displayMedium,
    'displaySmall' => t.displaySmall,
    'headlineLarge' => t.headlineLarge,
    'headlineMedium' => t.headlineMedium,
    'headlineSmall' => t.headlineSmall,
    'titleLarge' => t.titleLarge,
    'titleMedium' => t.titleMedium,
    'titleSmall' => t.titleSmall,
    'bodyLarge' => t.bodyLarge,
    'bodyMedium' => t.bodyMedium,
    'bodySmall' => t.bodySmall,
    'labelLarge' => t.labelLarge,
    'labelMedium' => t.labelMedium,
    'labelSmall' => t.labelSmall,
    _ => null,
  };
}

ButtonStyle? _buttonStyleFromUIStyle(UIStyle? style) {
  if (style == null) return null;
  return ButtonStyle(
    backgroundColor: style.backgroundColor != null
        ? WidgetStateProperty.all(parseColor(style.backgroundColor))
        : null,
    foregroundColor: style.foregroundColor != null
        ? WidgetStateProperty.all(parseColor(style.foregroundColor))
        : null,
    shape: style.borderRadius != null
        ? WidgetStateProperty.all(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(style.borderRadius!),
            ),
          )
        : null,
  );
}

// Lazy TapGestureRecognizer helper

TapGestureRecognizer _tapRecognizer(BuildContext ctx, UIAction action) {
  final r = TapGestureRecognizer();
  r.onTap = () => ctx.agentDispatcher.dispatch(ctx, action);
  return r;
}
