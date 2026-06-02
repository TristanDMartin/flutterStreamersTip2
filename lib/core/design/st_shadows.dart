import 'package:flutter/material.dart';

import '../theme/st_theme_tokens.dart';

/// Custom shadows — prefer these over raw [elevation] for cross‑device parity.
abstract final class STShadows {
  STShadows._();

  static List<BoxShadow> card(
      {double blur = 20, double dy = 8, double alpha = 0.16}) {
    return <BoxShadow>[
      BoxShadow(
        color: Colors.black.withValues(alpha: alpha),
        blurRadius: blur,
        offset: Offset(0, dy),
      ),
    ];
  }

  static List<BoxShadow> softElevated() => card(blur: 18, dy: 8, alpha: 0.14);

  static List<BoxShadow> purpleGlow({double alpha = 0.28}) => <BoxShadow>[
        BoxShadow(
          color: StThemeColors.brandPurple.withValues(alpha: alpha),
          blurRadius: 22,
          offset: const Offset(0, 10),
        ),
      ];
}
