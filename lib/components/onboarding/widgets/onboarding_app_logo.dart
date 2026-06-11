import 'package:flutter/material.dart';

class OnboardingAppLogo extends StatefulWidget {
  const OnboardingAppLogo({
    super.key,
    this.size = 120,
    this.animate = true,
  });

  final double size;
  final bool animate;

  @override
  State<OnboardingAppLogo> createState() => _OnboardingAppLogoState();
}

class _OnboardingAppLogoState extends State<OnboardingAppLogo>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;

  @override
  void initState() {
    super.initState();
    if (widget.animate) {
      _controller = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1400),
      )..repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Widget logo = Image.asset(
      'assets/app_logo.PNG',
      width: widget.size,
      height: widget.size,
      fit: BoxFit.contain,
      errorBuilder: (
        BuildContext context,
        Object error,
        StackTrace? stackTrace,
      ) {
        return Image.asset(
          'assets/091225_ST_logo_white.PNG',
          width: widget.size,
          height: widget.size,
          fit: BoxFit.contain,
          errorBuilder: (
            BuildContext context,
            Object error,
            StackTrace? stackTrace,
          ) {
            return Image.asset(
              'assets/logo.png',
              width: widget.size,
              height: widget.size,
              fit: BoxFit.contain,
              errorBuilder: (
                BuildContext context,
                Object error,
                StackTrace? stackTrace,
              ) {
                return Icon(
                  Icons.sports_esports_rounded,
                  color: Colors.white,
                  size: widget.size * 0.72,
                );
              },
            );
          },
        );
      },
    );
    if (_controller == null) {
      return logo;
    }
    return AnimatedBuilder(
      animation: _controller!,
      builder: (BuildContext context, Widget? child) {
        return Transform.scale(
          scale: 1 + (_controller!.value * 0.04),
          child: child,
        );
      },
      child: logo,
    );
  }
}
