import 'package:flutter/material.dart';

import 'package:google_fonts/google_fonts.dart';

/// Inter‑based helpers; primary [TextTheme] comes from [StAppTheme] + Google Fonts.
abstract final class STTypography {
  STTypography._();

  /// Apply Inter to an existing [TextTheme] (keeps sizes/colors from [base]).
  static TextTheme interTextTheme(TextTheme base) =>
      GoogleFonts.interTextTheme(base);

  static TextStyle inter({
    required double size,
    FontWeight weight = FontWeight.w500,
    Color? color,
    double height = 1.25,
    double letterSpacing = 0,
  }) {
    return GoogleFonts.inter(
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );
  }
}
