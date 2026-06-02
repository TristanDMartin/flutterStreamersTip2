import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/theme/st_theme_tokens.dart';

class CommentThreadsOnboardingTooltip extends StatefulWidget {
  const CommentThreadsOnboardingTooltip({
    super.key,
    required this.onDismiss,
    required this.onTryThreads,
  });

  final VoidCallback onDismiss;
  final VoidCallback onTryThreads;

  @override
  State<CommentThreadsOnboardingTooltip> createState() =>
      _CommentThreadsOnboardingTooltipState();
}

class _CommentThreadsOnboardingTooltipState
    extends State<CommentThreadsOnboardingTooltip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _animateOut(VoidCallback action) async {
    await _controller.reverse();
    if (!mounted) {
      return;
    }
    action();
  }

  @override
  Widget build(BuildContext context) {
    final bool isLight = Theme.of(context).brightness == Brightness.light;
    final Color glassFill = isLight
        ? Colors.white.withValues(alpha: 0.92)
        : const Color(0xFF12182A).withValues(alpha: 0.88);
    final Color edgeGlow = StThemeColors.brandPurple.withValues(alpha: 0.45);

    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.bottomCenter,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: glassFill,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: edgeGlow,
                        width: 1,
                      ),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color:
                              StThemeColors.brandPurple.withValues(alpha: 0.18),
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Start conversations with creators.\n'
                            'Reply to comments or turn discussions into Threads.',
                            style: TextStyle(
                              color: isLight
                                  ? StThemeColors.lightTextPrimary
                                  : Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Threads help creators build deeper communities.',
                            style: TextStyle(
                              color: isLight
                                  ? StThemeColors.lightTextSecondary
                                  : StThemeColors.darkTextSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              TextButton(
                                onPressed: () => _animateOut(widget.onDismiss),
                                style: TextButton.styleFrom(
                                  foregroundColor: isLight
                                      ? StThemeColors.lightTextSecondary
                                      : StThemeColors.darkTextSecondary,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: const Text(
                                  'Got it',
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                              ),
                              const Spacer(),
                              DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: StThemeColors.gradient,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(999),
                                    onTap: () =>
                                        _animateOut(widget.onTryThreads),
                                    child: const Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 8,
                                      ),
                                      child: Text(
                                        'Try Threads',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: -6,
                child: CustomPaint(
                  size: const Size(14, 8),
                  painter: _TooltipArrowPainter(
                    color: glassFill,
                    borderColor: edgeGlow,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TooltipArrowPainter extends CustomPainter {
  const _TooltipArrowPainter({
    required this.color,
    required this.borderColor,
  });

  final Color color;
  final Color borderColor;

  @override
  void paint(Canvas canvas, Size size) {
    final Path path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
    canvas.drawPath(
      path,
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
