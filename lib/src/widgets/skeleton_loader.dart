// lib/src/widgets/skeleton_loader.dart
//
// Batik Framework - Skeleton Loading Widget
// ============================================================
// Reusable skeleton loader for loading states with shimmer effect.
// Used throughout the framework for progressive loading UI.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// A skeleton loader widget that displays shimmering placeholder content.
///
/// This widget is commonly used to show loading states while content
/// is being fetched or generated, providing a better user experience
/// than traditional spinners.
///
/// Example usage:
/// ```dart
/// SkeletonLoader(lines: 3, showAvatar: true)
/// ```
class SkeletonLoader extends StatelessWidget {
  const SkeletonLoader({
    super.key,
    this.lines = 3,
    this.showAvatar = false,
    this.showHeader = true,
    this.shimmerDuration = const Duration(milliseconds: 1200),
  });

  /// Number of skeleton lines to display
  final int lines;

  /// Show an avatar placeholder at the top
  final bool showAvatar;

  /// Show a header line at the top
  final bool showHeader;

  /// Duration of the shimmer animation
  final Duration shimmerDuration;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showHeader)
          _SkeletonLine(width: 200, height: 20)
              .animate(onPlay: (c) => c.repeat())
              .shimmer(duration: shimmerDuration, color: Colors.white60),
        if (showHeader) const SizedBox(height: 12),
        if (showAvatar)
          Row(
            children: [
              _SkeletonCircle(size: 48)
                  .animate(onPlay: (c) => c.repeat())
                  .shimmer(duration: shimmerDuration, color: Colors.white60),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SkeletonLine(width: 120, height: 14)
                      .animate(onPlay: (c) => c.repeat())
                      .shimmer(duration: shimmerDuration),
                  const SizedBox(height: 6),
                  _SkeletonLine(width: 80, height: 12)
                      .animate(onPlay: (c) => c.repeat())
                      .shimmer(duration: shimmerDuration),
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
              .shimmer(duration: shimmerDuration, color: Colors.white60),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

/// Internal skeleton line widget
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

/// Internal skeleton circle widget
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
