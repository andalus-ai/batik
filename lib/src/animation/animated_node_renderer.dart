// lib/src/animation/animated_node_renderer.dart
//
// Batik Framework v2 — Animation System
// ============================================================
// Adds declarative animations to UINodes via:
//  1. Per-node `animation` property in the schema
//  2. Global entrance animations for newly appeared nodes
//  3. Diff-aware exit/update transitions
//  4. Loading skeleton shimmer
//
// Uses flutter_animate for the animation engine.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../schema/ui_schema.dart';
import '../diff/ui_diff_engine.dart';

// ─────────────────────────────────────────────
// Animation descriptor (schema extension)
// ─────────────────────────────────────────────

class UIAnimation {
  const UIAnimation({
    required this.type,
    this.duration = const Duration(milliseconds: 300),
    this.delay = Duration.zero,
    this.curve = 'easeOut',
    this.repeat = false,
    this.reverse = false,
  });

  /// "fadeIn" | "slideUp" | "slideDown" | "slideLeft" | "slideRight"
  /// "scale" | "shimmer" | "bounce" | "flip" | "blur"
  final String type;
  final Duration duration;
  final Duration delay;
  final String
  curve; // "easeIn" | "easeOut" | "easeInOut" | "linear" | "bounceOut"
  final bool repeat;
  final bool reverse;

  factory UIAnimation.fromJson(Map<String, dynamic> j) => UIAnimation(
    type: j['type'] as String? ?? 'fadeIn',
    duration: Duration(milliseconds: j['durationMs'] as int? ?? 300),
    delay: Duration(milliseconds: j['delayMs'] as int? ?? 0),
    curve: j['curve'] as String? ?? 'easeOut',
    repeat: j['repeat'] as bool? ?? false,
    reverse: j['reverse'] as bool? ?? false,
  );

  Map<String, dynamic> toJson() => {
    'type': type,
    'durationMs': duration.inMilliseconds,
    'delayMs': delay.inMilliseconds,
    'curve': curve,
    'repeat': repeat,
    'reverse': reverse,
  };
}

// ─────────────────────────────────────────────
// Global animation config
// ─────────────────────────────────────────────

class AnimationConfig {
  const AnimationConfig({
    this.entranceAnimation = const UIAnimation(type: 'fadeIn'),
    this.updateAnimation = const UIAnimation(
      type: 'fadeIn',
      duration: Duration(milliseconds: 150),
    ),
    this.exitAnimation,
    this.enableEntranceAnimations = true,
    this.enableUpdateAnimations = true,
    this.enableStreamingShimmer = true,
    this.staggerDelay = const Duration(milliseconds: 40),
    this.respectReduceMotion = true,
  });

  final UIAnimation entranceAnimation;
  final UIAnimation updateAnimation;
  final UIAnimation? exitAnimation;
  final bool enableEntranceAnimations;
  final bool enableUpdateAnimations;
  final bool enableStreamingShimmer;
  final Duration staggerDelay;
  final bool respectReduceMotion;

  static const none = AnimationConfig(
    enableEntranceAnimations: false,
    enableUpdateAnimations: false,
    enableStreamingShimmer: false,
  );

  static const snappy = AnimationConfig(
    entranceAnimation: UIAnimation(
      type: 'fadeIn',
      duration: Duration(milliseconds: 150),
    ),
    staggerDelay: Duration(milliseconds: 20),
  );

  static const expressive = AnimationConfig(
    entranceAnimation: UIAnimation(
      type: 'slideUp',
      duration: Duration(milliseconds: 400),
    ),
    staggerDelay: Duration(milliseconds: 60),
  );
}

// ─────────────────────────────────────────────
// Animated widget wrapper
// ─────────────────────────────────────────────

/// Wraps a widget with animations based on [UIAnimation] descriptor.
class AnimatedUINode extends StatelessWidget {
  const AnimatedUINode({
    super.key,
    required this.child,
    required this.animation,
    this.staggerIndex = 0,
    this.staggerDelay = const Duration(milliseconds: 40),
  });

  final Widget child;
  final UIAnimation animation;
  final int staggerIndex;
  final Duration staggerDelay;

  @override
  Widget build(BuildContext context) {
    // Respect accessibility reduce motion
    final mediaQuery = MediaQuery.of(context);
    if (mediaQuery.disableAnimations) return child;

    final totalDelay = animation.delay + staggerDelay * staggerIndex;
    final curve = _parseCurve(animation.curve);

    return _applyAnimation(child, animation, totalDelay, curve);
  }

  Widget _applyAnimation(
    Widget w,
    UIAnimation anim,
    Duration delay,
    Curve curve,
  ) {
    switch (anim.type) {
      case 'fadeIn':
        return w
            .animate(delay: delay)
            .fadeIn(duration: anim.duration, curve: curve);

      case 'slideUp':
        return w
            .animate(delay: delay)
            .fadeIn(duration: anim.duration, curve: curve)
            .slideY(begin: 0.15, end: 0, duration: anim.duration, curve: curve);

      case 'slideDown':
        return w
            .animate(delay: delay)
            .fadeIn(duration: anim.duration, curve: curve)
            .slideY(
              begin: -0.15,
              end: 0,
              duration: anim.duration,
              curve: curve,
            );

      case 'slideLeft':
        return w
            .animate(delay: delay)
            .fadeIn(duration: anim.duration, curve: curve)
            .slideX(begin: 0.15, end: 0, duration: anim.duration, curve: curve);

      case 'slideRight':
        return w
            .animate(delay: delay)
            .fadeIn(duration: anim.duration, curve: curve)
            .slideX(
              begin: -0.15,
              end: 0,
              duration: anim.duration,
              curve: curve,
            );

      case 'scale':
        return w
            .animate(delay: delay)
            .fadeIn(duration: anim.duration, curve: curve)
            .scale(
              begin: const Offset(0.85, 0.85),
              end: const Offset(1, 1),
              duration: anim.duration,
              curve: curve,
            );

      case 'bounce':
        return w
            .animate(delay: delay)
            .slideY(
              begin: -0.1,
              end: 0,
              duration: anim.duration,
              curve: Curves.bounceOut,
            )
            .fadeIn(duration: anim.duration ~/ 2);

      case 'shimmer':
        return w
            .animate(
              onPlay: anim.repeat ? (c) => c.repeat() : null,
              delay: delay,
            )
            .shimmer(duration: anim.duration, color: Colors.white54);

      case 'blur':
        return w
            .animate(delay: delay)
            .blur(
              begin: const Offset(4, 4),
              end: Offset.zero,
              duration: anim.duration,
              curve: curve,
            )
            .fadeIn(duration: anim.duration);

      case 'flip':
        return w
            .animate(delay: delay)
            .flipV(duration: anim.duration, curve: curve);

      default:
        return w.animate(delay: delay).fadeIn(duration: anim.duration);
    }
  }

  Curve _parseCurve(String raw) {
    return const {
          'linear': Curves.linear,
          'easeIn': Curves.easeIn,
          'easeOut': Curves.easeOut,
          'easeInOut': Curves.easeInOut,
          'bounceOut': Curves.bounceOut,
          'bounceIn': Curves.bounceIn,
          'elasticOut': Curves.elasticOut,
          'decelerate': Curves.decelerate,
          'fastOutSlowIn': Curves.fastOutSlowIn,
        }[raw] ??
        Curves.easeOut;
  }
}

// ─────────────────────────────────────────────
// Diff-aware animated container
// ─────────────────────────────────────────────

/// Wraps a widget and animates it when the diff indicates it changed.
class DiffAwareWidget extends StatefulWidget {
  const DiffAwareWidget({
    super.key,
    required this.nodeId,
    required this.child,
    required this.config,
    this.patch,
  });

  final String? nodeId;
  final Widget child;
  final AnimationConfig config;
  final UIPatch? patch;

  @override
  State<DiffAwareWidget> createState() => _DiffAwareWidgetState();
}

class _DiffAwareWidgetState extends State<DiffAwareWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _opacity = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);

    if (widget.patch is InsertPatch && widget.config.enableEntranceAnimations) {
      _ctrl.forward();
    } else {
      _ctrl.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(DiffAwareWidget old) {
    super.didUpdateWidget(old);
    if (widget.patch is UpdatePatch && widget.config.enableUpdateAnimations) {
      _ctrl.forward(from: 0.7); // flash
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(opacity: _opacity, child: widget.child);
  }
}

// ─────────────────────────────────────────────
// Loading skeleton / shimmer
// ─────────────────────────────────────────────

class SkeletonLoader extends StatelessWidget {
  const SkeletonLoader({
    super.key,
    this.lines = 3,
    this.showAvatar = false,
    this.showHeader = true,
  });

  final int lines;
  final bool showAvatar;
  final bool showHeader;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showHeader)
          _SkeletonLine(width: 200, height: 20)
              .animate(onPlay: (c) => c.repeat())
              .shimmer(duration: 1200.ms, color: Colors.white60),
        if (showHeader) const SizedBox(height: 12),
        if (showAvatar)
          Row(
            children: [
              _SkeletonCircle(size: 48)
                  .animate(onPlay: (c) => c.repeat())
                  .shimmer(duration: 1200.ms, color: Colors.white60),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SkeletonLine(width: 120, height: 14)
                      .animate(onPlay: (c) => c.repeat())
                      .shimmer(duration: 1200.ms),
                  const SizedBox(height: 6),
                  _SkeletonLine(width: 80, height: 12)
                      .animate(onPlay: (c) => c.repeat())
                      .shimmer(duration: 1200.ms),
                ],
              ),
            ],
          ),
        if (showAvatar) const SizedBox(height: 12),
        for (var i = 0; i < lines; i++) ...[
          _SkeletonLine(
                width: i == lines - 1 ? 180 : double.infinity,
                height: 14,
              )
              .animate(
                delay: Duration(milliseconds: i * 50),
                onPlay: (c) => c.repeat(),
              )
              .shimmer(duration: 1200.ms, color: Colors.white60),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _SkeletonLine extends StatelessWidget {
  const _SkeletonLine({required this.width, required this.height});
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey.shade300,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

class _SkeletonCircle extends StatelessWidget {
  const _SkeletonCircle({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.grey.shade300,
        shape: BoxShape.circle,
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Stream progress indicator
// ─────────────────────────────────────────────

class StreamProgressBar extends StatelessWidget {
  const StreamProgressBar({
    super.key,
    required this.progress,
    this.isStreaming = true,
    this.color,
  });

  final double progress;
  final bool isStreaming;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    if (!isStreaming) return const SizedBox.shrink();

    return SizedBox(
      height: 2,
      child: LinearProgressIndicator(
        value: progress <= 0 ? null : progress,
        backgroundColor: Colors.transparent,
        color: color ?? Theme.of(context).colorScheme.primary,
        minHeight: 2,
      ),
    ).animate().fadeIn(duration: 200.ms);
  }
}

// ─────────────────────────────────────────────
// Staggered list animation
// ─────────────────────────────────────────────

/// Applies staggered entrance animations to a list of widgets.
List<Widget> staggeredList(
  List<Widget> children, {
  UIAnimation animation = const UIAnimation(type: 'slideUp'),
  Duration staggerDelay = const Duration(milliseconds: 40),
}) {
  return [
    for (var i = 0; i < children.length; i++)
      AnimatedUINode(
        animation: animation,
        staggerIndex: i,
        staggerDelay: staggerDelay,
        child: children[i],
      ),
  ];
}
