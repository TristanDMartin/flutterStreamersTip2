import 'package:flutter/material.dart';

import 'onboarding_style.dart';

enum CoachMarkPlacement { top, bottom, left, right }

class CoachMark extends StatelessWidget {
  const CoachMark({
    super.key,
    required this.title,
    required this.body,
    required this.targetRect,
    required this.placement,
    required this.primaryLabel,
    required this.onPrimary,
    this.onBack,
    this.onSkip,
    this.stepLabel,
    this.tooltipVerticalBias = 0,
    this.spotlightInset = 6,
    this.showSpotlight = true,
    this.tooltipAlignEnd = false,
  });

  final String title;
  final String body;
  final Rect targetRect;
  final CoachMarkPlacement placement;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final VoidCallback? onBack;
  final VoidCallback? onSkip;
  final String? stepLabel;

  /// Added after placement math; positive moves the coach card downward.
  final double tooltipVerticalBias;

  /// Pixels to expand the spotlight hole from [targetRect] (chip rows use less).
  final double spotlightInset;

  /// When false, no dimmed cutout or ring — only a transparent barrier and the
  /// coach bubble (used for full-screen tour steps like Inbox / Profile).
  final bool showSpotlight;

  /// When true, the coach bubble is aligned to the trailing (right) margin
  /// instead of centered on the spotlight horizontally.
  final bool tooltipAlignEnd;

  static Rect? targetRectForKey(GlobalKey key) {
    final BuildContext? context = key.currentContext;
    if (context == null) return null;
    final RenderObject? object = context.findRenderObject();
    if (object is! RenderBox || !object.hasSize) return null;
    final Offset offset = object.localToGlobal(Offset.zero);
    return offset & object.size;
  }

  @override
  Widget build(BuildContext context) {
    final MediaQueryData mediaQuery = MediaQuery.of(context);
    final Size size = mediaQuery.size;
    final double safeBottomPad = mediaQuery.padding.bottom + 88;
    final Rect spotlightForTooltip = showSpotlight
        ? targetRect.inflate(spotlightInset)
        : Rect.fromCenter(
            center: size.center(Offset.zero),
            width: 2,
            height: 2,
          );
    final Offset tooltipOffset = _tooltipOffset(
      size,
      spotlightForTooltip,
      safeBottomPad,
      tooltipVerticalBias,
      tooltipAlignEnd,
    );
    final double maxBodyHeight =
        (size.height - tooltipOffset.dy - safeBottomPad - 108).clamp(40, 132);
    final Widget bubble = Positioned(
      left: tooltipOffset.dx,
      top: tooltipOffset.dy,
      child: _CoachBubble(
        title: title,
        body: body,
        primaryLabel: primaryLabel,
        onPrimary: onPrimary,
        onBack: onBack,
        onSkip: onSkip,
        stepLabel: stepLabel,
        maxBodyHeight: maxBodyHeight,
      ),
    );
    if (!showSpotlight) {
      return Stack(
        fit: StackFit.expand,
        children: <Widget>[
          const Positioned.fill(
            child: ModalBarrier(
              color: Colors.transparent,
              dismissible: false,
            ),
          ),
          bubble,
        ],
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        Positioned.fill(
          child: AbsorbPointer(
            child: CustomPaint(
              painter: _SpotlightPainter(spotlightForTooltip),
            ),
          ),
        ),
        Positioned.fromRect(
          rect: spotlightForTooltip,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0xFF4897D2), width: 1.5),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: const Color(0xFF4897D2).withValues(alpha: 0.3),
                    blurRadius: 24,
                  ),
                ],
              ),
            ),
          ),
        ),
        bubble,
      ],
    );
  }

  Offset _tooltipOffset(
    Size size,
    Rect spotlight,
    double safeBottomPad,
    double tooltipVerticalBias,
    bool tooltipAlignEnd,
  ) {
    final double width = size.width < 380 ? size.width - 40 : 248;
    const double kBubbleLayoutHeight = 268;
    final double maxLeft = (size.width - width - 16).clamp(16, size.width);
    double left = (spotlight.center.dx - width / 2).clamp(16, maxLeft);
    if (tooltipAlignEnd &&
        (placement == CoachMarkPlacement.top ||
            placement == CoachMarkPlacement.bottom)) {
      left = maxLeft;
    }
    double top;
    switch (placement) {
      case CoachMarkPlacement.top:
        top = spotlight.top - kBubbleLayoutHeight - 16;
        break;
      case CoachMarkPlacement.bottom:
        top = spotlight.bottom + 16;
        break;
      case CoachMarkPlacement.left:
        left = spotlight.left - width - 16;
        top = spotlight.center.dy - kBubbleLayoutHeight / 2 + 48;
        break;
      case CoachMarkPlacement.right:
        left = spotlight.right + 16;
        top = spotlight.center.dy - kBubbleLayoutHeight / 2 + 44;
        break;
    }
    top += tooltipVerticalBias;
    final double maxTop = (size.height - kBubbleLayoutHeight - safeBottomPad)
        .clamp(16, size.height);
    top = top.clamp(16, maxTop);
    left = left.clamp(16, maxLeft);
    return Offset(left, top);
  }
}

class _CoachBubble extends StatelessWidget {
  const _CoachBubble({
    required this.title,
    required this.body,
    required this.primaryLabel,
    required this.onPrimary,
    required this.onBack,
    required this.onSkip,
    required this.stepLabel,
    required this.maxBodyHeight,
  });

  final String title;
  final String body;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final VoidCallback? onBack;
  final VoidCallback? onSkip;
  final String? stepLabel;
  final double maxBodyHeight;

  @override
  Widget build(BuildContext context) {
    final double screenW = MediaQuery.sizeOf(context).width;
    final double width = screenW < 380 ? screenW - 40 : 248;
    return Container(
      width: width,
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
      decoration: OnboardingStyle.cardDecoration(context: context, radius: 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (stepLabel != null) ...[
            Text(
              stepLabel!,
              style: const TextStyle(
                color: Color(0xFF7DD3FC),
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 6),
          ],
          Text(
            title,
            style: TextStyle(
              color: OnboardingStyle.textPrimaryFor(context),
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          SizedBox(
            height: maxBodyHeight,
            child: SingleChildScrollView(
              child: Text(
                body,
                style: TextStyle(
                  color: OnboardingStyle.textSecondaryFor(context),
                  fontSize: 12.5,
                  height: 1.28,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              if (onBack != null)
                TextButton(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: onBack,
                  child: const Text('Back'),
                ),
              if (onSkip != null)
                TextButton(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: onSkip,
                  child: const Text('Skip'),
                ),
              const Spacer(),
              Flexible(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: GradientPillButton(
                      label: primaryLabel,
                      onPressed: onPrimary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SpotlightPainter extends CustomPainter {
  const _SpotlightPainter(this.spotlight);

  final Rect spotlight;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint dim = Paint()..color = Colors.black.withValues(alpha: 0.42);
    final Path overlay = Path()..addRect(Offset.zero & size);
    final Path hole = Path()
      ..addRRect(
        RRect.fromRectAndRadius(spotlight, const Radius.circular(22)),
      );
    canvas.drawPath(
      Path.combine(PathOperation.difference, overlay, hole),
      dim,
    );
  }

  @override
  bool shouldRepaint(_SpotlightPainter oldDelegate) {
    return oldDelegate.spotlight != spotlight;
  }
}
