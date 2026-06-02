import 'package:flutter/material.dart';

class StThemeColors {
  StThemeColors._();

  static const Color brandPurple = Color(0xFF9248D2);
  static const Color brandBlue = Color(0xFF4897D2);
  static const Color purple = brandPurple;
  static const Color blue = brandBlue;

  static const LinearGradient gradient = LinearGradient(
    colors: <Color>[brandPurple, brandBlue],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const Color successGreen = Color(0xFF22C55E);
  static const Color warningAmber = Color(0xFFF59E0B);
  static const Color errorRed = Color(0xFFEF4444);
  static const Color success = successGreen;
  static const Color warning = warningAmber;
  static const Color danger = errorRed;

  static const List<Color> brandGradient = <Color>[brandPurple, brandBlue];

  static const Color darkBg = Color(0xFF050816);
  static const Color darkBackground = darkBg;
  static const Color darkSurface = Color(0xFF0F172A);
  static const Color darkCard = Color(0xFF1E293B);
  static const Color darkTextPrimary = Color(0xFFFFFFFF);
  static const Color darkTextSecondary = Color(0xFFCBD5E1);
  static const Color darkTextMuted = Color(0xFF94A3B8);

  static const Color lightBackground = Color(0xFFF8FAFC);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightCard = Color(0xFFF1F5F9);
  static const Color lightTextPrimary = Color(0xFF0F172A);
  static const Color lightTextSecondary = Color(0xFF334155);
  static const Color lightTextMuted = Color(0xFF64748B);
}

class StSpacing {
  StSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

class StRadius {
  StRadius._();

  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double pill = 999;
}

class StText {
  StText._();

  static const TextStyle feedTitle = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.4,
  );

  static const TextStyle username = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.2,
  );

  static const TextStyle body = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w500,
    height: 1.25,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.35,
  );

  static const TextStyle meta = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
  );
}

class StShadows {
  StShadows._();

  static List<BoxShadow> glass(Color color) => <BoxShadow>[
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.18),
          blurRadius: 18,
          offset: const Offset(0, 8),
        ),
      ];

  static List<BoxShadow> purpleGlow({double alpha = 0.32}) => <BoxShadow>[
        BoxShadow(
          color: StThemeColors.brandPurple.withValues(alpha: alpha),
          blurRadius: 24,
          offset: const Offset(0, 10),
        ),
      ];
}

class StMotion {
  StMotion._();

  static const Duration fast = Duration(milliseconds: 120);
  static const Duration normal = Duration(milliseconds: 220);
  static const Duration smooth = Duration(milliseconds: 320);
  static const Duration sheet = Duration(milliseconds: 420);
  static const Curve out = Curves.easeOutCubic;
  static const Curve inOut = Curves.easeInOutCubic;
}
