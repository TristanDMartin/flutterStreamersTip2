import 'package:flutter/material.dart';

import '../theme/support_shell_style.dart';

/// Animated shimmer overlay for skeleton placeholders.
class StShimmer extends StatefulWidget {
  const StShimmer({
    super.key,
    required this.child,
    this.enabled = true,
  });

  final Widget child;
  final bool enabled;

  @override
  State<StShimmer> createState() => _StShimmerState();
}

class _StShimmerState extends State<StShimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) {
      return widget.child;
    }
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (Rect bounds) {
            return LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: <Color>[
                shell.skeletonFill,
                shell.skeletonLine.withValues(alpha: 0.55),
                shell.skeletonFill,
              ],
              stops: <double>[
                (_controller.value - 0.35).clamp(0.0, 1.0),
                _controller.value.clamp(0.0, 1.0),
                (_controller.value + 0.35).clamp(0.0, 1.0),
              ],
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// Rounded skeleton block using theme shell colors.
class StSkeletonBox extends StatelessWidget {
  const StSkeletonBox({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8,
    this.circle = false,
  });

  final double width;
  final double height;
  final double borderRadius;
  final bool circle;

  @override
  Widget build(BuildContext context) {
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    return StShimmer(
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: shell.skeletonFill,
          borderRadius:
              circle ? null : BorderRadius.circular(borderRadius),
          shape: circle ? BoxShape.circle : BoxShape.rectangle,
        ),
      ),
    );
  }
}
