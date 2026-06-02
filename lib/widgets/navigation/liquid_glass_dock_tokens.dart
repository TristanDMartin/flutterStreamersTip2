import 'package:flutter/material.dart';

/// Sliding-indicator tokens layered on the original StreamersTip dock.
abstract final class LiquidGlassDockTokens {
  static const Duration orbDuration = Duration(milliseconds: 240);
  static const Curve orbCurve = Curves.easeOutCubic;
  static const Curve orbReverseCurve = Curves.easeInCubic;

  static const double dockBlurSigma = 16;
  static const double inactiveLabelOpacity = 0.4;
  static const double inactiveIconOpacity = 0.4;
  static const double activeIconScale = 1.06;

  static const Color orbGradientStart = Color(0xFF9248D2);
  static const Color orbGradientEnd = Color(0xFF4897D2);
  static const LinearGradient orbGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[
      Color(0x669248D2),
      Color(0x664897D2),
    ],
  );
}
