// lib/src/utils/style_utils.dart
//
// AgentUIKit — Style Utilities
// ============================================================
// Converts [UIStyle] descriptors into native Flutter types.
// Centralised so every component uses the same conversions.
// ============================================================

import 'package:flutter/material.dart';
import '../schema/ui_schema.dart';

// ─────────────────────────────────────────────
// Color parsing
// ─────────────────────────────────────────────

/// Named CSS colours + hex support (#RGB, #RRGGBB, #AARRGGBB).
Color? parseColor(String? raw) {
  if (raw == null || raw.isEmpty) return null;

  // Named colours
  final named = _namedColors[raw.toLowerCase()];
  if (named != null) return named;

  // Hex
  var hex = raw.replaceFirst('#', '');
  if (hex.length == 3) {
    hex = hex.split('').map((c) => '$c$c').join();
  }
  if (hex.length == 6) hex = 'FF$hex';
  if (hex.length == 8) {
    return Color(int.parse(hex, radix: 16));
  }
  return null;
}

const _namedColors = <String, Color>{
  'transparent': Colors.transparent,
  'white': Colors.white,
  'black': Colors.black,
  'red': Colors.red,
  'pink': Colors.pink,
  'purple': Colors.purple,
  'deepPurple': Colors.deepPurple,
  'indigo': Colors.indigo,
  'blue': Colors.blue,
  'lightBlue': Colors.lightBlue,
  'cyan': Colors.cyan,
  'teal': Colors.teal,
  'green': Colors.green,
  'lightGreen': Colors.lightGreen,
  'lime': Colors.lime,
  'yellow': Colors.yellow,
  'amber': Colors.amber,
  'orange': Colors.orange,
  'deepOrange': Colors.deepOrange,
  'brown': Colors.brown,
  'grey': Colors.grey,
  'blueGrey': Colors.blueGrey,
  'primary': const Color(0xFF6200EE),
  'secondary': const Color(0xFF03DAC6),
  'error': const Color(0xFFB00020),
  'surface': const Color(0xFFFFFFFF),
};

// ─────────────────────────────────────────────
// EdgeInsets
// ─────────────────────────────────────────────

EdgeInsets? parseInsets(UIInsets? insets) {
  if (insets == null) return null;
  if (insets.all != null) return EdgeInsets.all(insets.all!);
  return EdgeInsets.only(
    top: insets.top ?? 0,
    right: insets.right ?? 0,
    bottom: insets.bottom ?? 0,
    left: insets.left ?? 0,
  );
}

// ─────────────────────────────────────────────
// Alignment
// ─────────────────────────────────────────────

Alignment? parseAlignment(String? raw) {
  if (raw == null) return null;
  return const {
    'topLeft': Alignment.topLeft,
    'topCenter': Alignment.topCenter,
    'topRight': Alignment.topRight,
    'centerLeft': Alignment.centerLeft,
    'center': Alignment.center,
    'centerRight': Alignment.centerRight,
    'bottomLeft': Alignment.bottomLeft,
    'bottomCenter': Alignment.bottomCenter,
    'bottomRight': Alignment.bottomRight,
  }[raw];
}

// ─────────────────────────────────────────────
// FontWeight
// ─────────────────────────────────────────────

FontWeight? parseFontWeight(String? raw) {
  if (raw == null) return null;
  return const {
    'thin': FontWeight.w100,
    'extraLight': FontWeight.w200,
    'light': FontWeight.w300,
    'normal': FontWeight.w400,
    'medium': FontWeight.w500,
    'semiBold': FontWeight.w600,
    'bold': FontWeight.w700,
    'extraBold': FontWeight.w800,
    'black': FontWeight.w900,
    'w100': FontWeight.w100,
    'w200': FontWeight.w200,
    'w300': FontWeight.w300,
    'w400': FontWeight.w400,
    'w500': FontWeight.w500,
    'w600': FontWeight.w600,
    'w700': FontWeight.w700,
    'w800': FontWeight.w800,
    'w900': FontWeight.w900,
  }[raw];
}

// ─────────────────────────────────────────────
// TextAlign
// ─────────────────────────────────────────────

TextAlign? parseTextAlign(String? raw) {
  if (raw == null) return null;
  return const {
    'left': TextAlign.left,
    'right': TextAlign.right,
    'center': TextAlign.center,
    'justify': TextAlign.justify,
    'start': TextAlign.start,
    'end': TextAlign.end,
  }[raw];
}

// ─────────────────────────────────────────────
// TextOverflow
// ─────────────────────────────────────────────

TextOverflow? parseOverflow(String? raw) {
  if (raw == null) return null;
  return const {
    'clip': TextOverflow.clip,
    'ellipsis': TextOverflow.ellipsis,
    'fade': TextOverflow.fade,
    'visible': TextOverflow.visible,
  }[raw];
}

// ─────────────────────────────────────────────
// BoxFit
// ─────────────────────────────────────────────

BoxFit? parseBoxFit(String? raw) {
  if (raw == null) return null;
  return const {
    'fill': BoxFit.fill,
    'contain': BoxFit.contain,
    'cover': BoxFit.cover,
    'fitWidth': BoxFit.fitWidth,
    'fitHeight': BoxFit.fitHeight,
    'none': BoxFit.none,
    'scaleDown': BoxFit.scaleDown,
  }[raw];
}

// ─────────────────────────────────────────────
// BoxDecoration from UIStyle
// ─────────────────────────────────────────────

BoxDecoration? buildDecoration(UIStyle? style) {
  if (style == null) return null;

  final bg = parseColor(style.backgroundColor);
  final border = style.borderColor != null
      ? Border.all(
          color: parseColor(style.borderColor) ?? Colors.grey,
          width: style.borderWidth ?? 1.0,
        )
      : null;
  final radius = style.borderRadius != null
      ? BorderRadius.circular(style.borderRadius!)
      : null;
  final shadow = style.shadow != null
      ? [
          BoxShadow(
            color:
                parseColor(style.shadow!.color) ?? Colors.black.withOpacity(.2),
            blurRadius: style.shadow!.blurRadius ?? 4,
            offset: Offset(
              style.shadow!.offsetX ?? 0,
              style.shadow!.offsetY ?? 2,
            ),
          ),
        ]
      : null;

  Gradient? gradient;
  if (style.gradient != null) {
    final g = style.gradient!;
    final colors = g.colors
        .map((c) => parseColor(c) ?? Colors.transparent)
        .toList();
    gradient = g.type == 'radial'
        ? RadialGradient(colors: colors, stops: g.stops)
        : LinearGradient(
            colors: colors,
            stops: g.stops,
            transform: g.angle != null
                ? GradientRotation(g.angle! * 3.14159 / 180)
                : null,
          );
  }

  if (bg == null &&
      border == null &&
      radius == null &&
      shadow == null &&
      gradient == null)
    return null;

  return BoxDecoration(
    color: gradient == null ? bg : null,
    gradient: gradient,
    border: border,
    borderRadius: radius,
    boxShadow: shadow,
  );
}

// ─────────────────────────────────────────────
// TextStyle from UIStyle
// ─────────────────────────────────────────────

TextStyle? buildTextStyle(UIStyle? style, [TextStyle? base]) {
  if (style == null) return base;
  return (base ?? const TextStyle()).copyWith(
    color: parseColor(style.foregroundColor),
    fontSize: style.fontSize,
    fontWeight: parseFontWeight(style.fontWeight),
    fontFamily: style.fontFamily,
    letterSpacing: style.letterSpacing,
    height: style.lineHeight,
  );
}

// ─────────────────────────────────────────────
// Wrap Container with style
// ─────────────────────────────────────────────

/// Wraps [child] in a Container if [style] has layout/decoration props.
Widget applyStyle(Widget child, UIStyle? style) {
  if (style == null) return child;

  final padding = parseInsets(style.padding);
  final margin = parseInsets(style.margin);
  final decoration = buildDecoration(style);
  final align = parseAlignment(style.alignment);

  Widget result = child;

  if (align != null) result = Align(alignment: align, child: result);

  if (padding != null ||
      margin != null ||
      decoration != null ||
      style.width != null ||
      style.height != null ||
      style.minWidth != null ||
      style.maxWidth != null ||
      style.minHeight != null ||
      style.maxHeight != null) {
    result = Container(
      padding: padding,
      margin: margin,
      width: style.width,
      height: style.height,
      constraints:
          (style.minWidth != null ||
              style.maxWidth != null ||
              style.minHeight != null ||
              style.maxHeight != null)
          ? BoxConstraints(
              minWidth: style.minWidth ?? 0,
              maxWidth: style.maxWidth ?? double.infinity,
              minHeight: style.minHeight ?? 0,
              maxHeight: style.maxHeight ?? double.infinity,
            )
          : null,
      decoration: decoration,
      child: result,
    );
  }

  if (style.opacity != null && style.opacity != 1.0) {
    result = Opacity(opacity: style.opacity!.clamp(0.0, 1.0), child: result);
  }

  if (style.flex != null) {
    result = Expanded(flex: style.flex!, child: result);
  }

  return result;
}

// ─────────────────────────────────────────────
// Icon mapping (Material → IconData)
// ─────────────────────────────────────────────

/// Maps string icon names to [IconData].
/// A minimal set is provided; register your own via [IconRegistry].
IconData resolveIcon(String name) {
  return IconRegistry.instance.resolve(name);
}

class IconRegistry {
  IconRegistry._();
  static final instance = IconRegistry._();

  final _map = <String, IconData>{};

  void register(String name, IconData data) => _map[name] = data;
  void registerAll(Map<String, IconData> icons) => _map.addAll(icons);

  IconData resolve(String name) =>
      _map[name] ?? _builtins[name] ?? Icons.help_outline;

  static const _builtins = <String, IconData>{
    'home': Icons.home,
    'search': Icons.search,
    'settings': Icons.settings,
    'person': Icons.person,
    'star': Icons.star,
    'star_outline': Icons.star_border,
    'favorite': Icons.favorite,
    'favorite_border': Icons.favorite_border,
    'add': Icons.add,
    'remove': Icons.remove,
    'close': Icons.close,
    'check': Icons.check,
    'edit': Icons.edit,
    'delete': Icons.delete,
    'share': Icons.share,
    'info': Icons.info,
    'warning': Icons.warning,
    'error': Icons.error,
    'check_circle': Icons.check_circle,
    'arrow_back': Icons.arrow_back,
    'arrow_forward': Icons.arrow_forward,
    'menu': Icons.menu,
    'more_vert': Icons.more_vert,
    'more_horiz': Icons.more_horiz,
    'send': Icons.send,
    'attach_file': Icons.attach_file,
    'camera': Icons.camera_alt,
    'image': Icons.image,
    'video': Icons.videocam,
    'mic': Icons.mic,
    'phone': Icons.phone,
    'email': Icons.email,
    'location': Icons.location_on,
    'calendar': Icons.calendar_today,
    'notifications': Icons.notifications,
    'help': Icons.help_outline,
    'refresh': Icons.refresh,
    'download': Icons.download,
    'upload': Icons.upload,
    'link': Icons.link,
    'visibility': Icons.visibility,
    'visibility_off': Icons.visibility_off,
    'lock': Icons.lock,
    'unlock': Icons.lock_open,
    'play': Icons.play_arrow,
    'pause': Icons.pause,
    'stop': Icons.stop,
    'skip_next': Icons.skip_next,
    'skip_previous': Icons.skip_previous,
    'volume_up': Icons.volume_up,
    'volume_off': Icons.volume_off,
    'wifi': Icons.wifi,
    'bluetooth': Icons.bluetooth,
    'battery': Icons.battery_full,
    'dark_mode': Icons.dark_mode,
    'light_mode': Icons.light_mode,
    'filter': Icons.filter_list,
    'sort': Icons.sort,
    'copy': Icons.content_copy,
    'paste': Icons.content_paste,
    'cut': Icons.content_cut,
    'undo': Icons.undo,
    'redo': Icons.redo,
    'save': Icons.save,
    'print': Icons.print,
    'chart_bar': Icons.bar_chart,
    'chart_line': Icons.show_chart,
    'chart_pie': Icons.pie_chart,
    'table': Icons.table_chart,
    'list': Icons.list,
    'grid': Icons.grid_view,
    'dashboard': Icons.dashboard,
    'account': Icons.account_circle,
    'logout': Icons.logout,
    'login': Icons.login,
    'shopping_cart': Icons.shopping_cart,
    'payment': Icons.payment,
    'receipt': Icons.receipt,
    'tag': Icons.label,
    'bookmark': Icons.bookmark,
    'bookmark_border': Icons.bookmark_border,
    'thumbs_up': Icons.thumb_up,
    'thumbs_down': Icons.thumb_down,
    'comment': Icons.comment,
    'chat': Icons.chat_bubble_outline,
    'group': Icons.group,
    'public': Icons.public,
    'circle': Icons.circle,
    'help_outline': Icons.help_outline,
  };
}
