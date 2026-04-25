import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class AppResponsive {
  AppResponsive._(this.mediaQuery)
      : size = mediaQuery.size,
        shortestSide = mediaQuery.size.shortestSide,
        isIOS = defaultTargetPlatform == TargetPlatform.iOS;

  final MediaQueryData mediaQuery;
  final Size size;
  final double shortestSide;
  final bool isIOS;

  static AppResponsive of(BuildContext context) {
    return AppResponsive._(MediaQuery.of(context));
  }

  bool get isCompactPhone => shortestSide < 360;
  bool get isSmallPhone => shortestSide < 390;
  bool get isLargePhone => shortestSide >= 430 && shortestSide < 600;
  bool get isTabletLike => shortestSide >= 600;

  double get scale {
    if (isTabletLike) return 1.06;

    final base = shortestSide / 390.0;
    final minScale = isIOS ? 0.88 : 0.90;
    final maxScale = isIOS ? 1.02 : 1.04;
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

  static MediaQueryData normalizedMediaQuery(MediaQueryData mediaQuery) {
    final textScale = mediaQuery.textScaler.scale(1).clamp(0.90, 1.18);
    return mediaQuery.copyWith(textScaler: TextScaler.linear(textScale));
  }
}

extension AppResponsiveContext on BuildContext {
  AppResponsive get responsive => AppResponsive.of(this);
}
