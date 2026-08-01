import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';

/// Outlined Get Started CTA with a soft brand pulse.
class AuthGetStartedButton extends StatefulWidget {
  const AuthGetStartedButton({
    super.key,
    required this.onPressed,
  });

  final VoidCallback onPressed;

  @override
  State<AuthGetStartedButton> createState() => _AuthGetStartedButtonState();
}

class _AuthGetStartedButtonState extends State<AuthGetStartedButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _scaleAnimation = Tween<double>(begin: 1, end: 1.035).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _glowAnimation = Tween<double>(begin: 0.22, end: 0.55).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    final bool reduceMotion = WidgetsBinding
            .instance.platformDispatcher.accessibilityFeatures.reduceMotion ==
        true;
    if (!reduceMotion) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (BuildContext context, Widget? child) {
        final double glow = _pulseController.isAnimating
            ? _glowAnimation.value
            : 0.35;
        final double scale =
            _pulseController.isAnimating ? _scaleAnimation.value : 1;
        return Transform.scale(
          scale: scale,
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: glow * 0.7),
                  blurRadius: 18 + (glow * 10),
                  spreadRadius: glow * 1.5,
                ),
                BoxShadow(
                  color: const Color(0xFF4897D2).withValues(alpha: glow * 0.45),
                  blurRadius: 22 + (glow * 8),
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: child,
          ),
        );
      },
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: <Color>[
              AppColors.primary.withValues(alpha: 0.22),
              const Color(0xFF4897D2).withValues(alpha: 0.18),
            ],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.65),
            width: 1.4,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onPressed,
            borderRadius: BorderRadius.circular(16),
            child: const SizedBox(
              height: 48,
              width: double.infinity,
              child: Center(
                child: Text(
                  'Get Started',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
