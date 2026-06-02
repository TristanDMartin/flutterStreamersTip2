import 'package:flutter/material.dart';
import '../utils/constants.dart';

class GradientBackground extends StatelessWidget {
  final Widget child;
  final bool fullScreen;

  const GradientBackground({
    super.key,
    required this.child,
    this.fullScreen = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            AppColors.primary, // #9248D2 (purple)
            AppColors.secondary, // #7768DF (purple)
            AppColors.tertiary, // #1670DE (blue)
          ],
          stops: [0.0, 0.5, 1.0],
        ),
      ),
      child: fullScreen ? child : SafeArea(child: child),
    );
  }
}
