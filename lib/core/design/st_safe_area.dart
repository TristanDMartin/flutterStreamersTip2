import 'package:flutter/material.dart';

/// Centralized screen insets so [SafeArea] + manual padding do not stack per OS.
abstract final class STInsets {
  STInsets._();

  /// Horizontal gutters + real system top/bottom insets (notches, home indicator).
  static EdgeInsets screen(
    BuildContext context, {
    double horizontal = 20,
  }) {
    final EdgeInsets view = MediaQuery.viewPaddingOf(context);
    return EdgeInsets.only(
      left: horizontal,
      right: horizontal,
      top: view.top,
      bottom: view.bottom,
    );
  }

  /// Content inside a parent that already applied horizontal [screen] padding.
  static EdgeInsets contentVertical({
    double top = 0,
    double bottom = 0,
  }) {
    return EdgeInsets.only(top: top, bottom: bottom);
  }
}
