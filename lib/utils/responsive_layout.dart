import 'dart:math' as math;

import 'package:flutter/material.dart';

class AppResponsive {
  AppResponsive._(this.mediaQuery)
      : size = mediaQuery.size,
        shortestSide = mediaQuery.size.shortestSide;

  final MediaQueryData mediaQuery;
  final Size size;
  final double shortestSide;

  static AppResponsive of(BuildContext context) {
    return AppResponsive._(MediaQuery.of(context));
  }

  bool get isCompactPhone => shortestSide < 360;
  bool get isSmallPhone => shortestSide < 390;
  bool get isLargePhone => shortestSide >= 430 && shortestSide < 600;
  bool get isTabletLike => shortestSide >= 600;

  double get scale {
    if (isTabletLike) return 1.06;

    final double base = shortestSide / 390.0;
    const double minScale = 0.90;
    const double maxScale = 1.04;
    return base.clamp(minScale, maxScale);
  }

  double spacing(double value) => (value * scale).roundToDouble();

  double radius(double value) {
    final adjusted = value * scale;
    return math.max(value - 4, adjusted).roundToDouble();
  }

  double icon(double value) =>
      (value * scale).clamp(18.0, value).roundToDouble();

  double font(double value) {
    final adjusted = value * scale;
    return adjusted.clamp(value - 2, value + 1).roundToDouble();
  }

  EdgeInsets horizontalPagePadding({double base = 20}) {
    final horizontal = isCompactPhone ? base - 4 : base;
    return EdgeInsets.symmetric(horizontal: spacing(horizontal));
  }

  EdgeInsets screenInsets({
    double horizontal = 20,
    double top = 12,
    double bottom = 20,
  }) {
    return EdgeInsets.fromLTRB(
      spacing(isCompactPhone ? horizontal - 4 : horizontal),
      spacing(top),
      spacing(isCompactPhone ? horizontal - 4 : horizontal),
      spacing(bottom) + mediaQuery.padding.bottom,
    );
  }

  /// Clamps OS accessibility text scale so A/B across phones stays comparable.
  /// When comparing iOS vs Android, set similar **Display → Text size** on both.
  static MediaQueryData normalizedMediaQuery(MediaQueryData mediaQuery) {
    final double textScale = mediaQuery.textScaler.scale(1).clamp(0.90, 1.18);
    return mediaQuery.copyWith(textScaler: TextScaler.linear(textScale));
  }
}

extension AppResponsiveContext on BuildContext {
  AppResponsive get responsive => AppResponsive.of(this);
}
