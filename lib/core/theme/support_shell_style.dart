import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';

/// Theme-aware chrome for full-screen flows that used the purple “support”
/// shell in dark mode only ([AppColors.supportBackground]).
class StSupportShellStyle {
  const StSupportShellStyle._({
    required this.isLight,
    required this.scaffold,
    required this.pageGradient,
    required this.onChrome,
    required this.muted,
    required this.mutedStrong,
    required this.heroGradient,
    required this.heroBorder,
    required this.surfaceCard,
    required this.surfaceCardBorder,
    required this.skeletonFill,
    required this.skeletonLine,
    required this.skeletonLineDim,
    required this.chipSelectedBg,
    required this.chipUnselectedBg,
    required this.chipSelectedBorder,
    required this.chipUnselectedBorder,
    required this.chipSelectedFg,
    required this.chipUnselectedFg,
    required this.glassCircleGradientStart,
    required this.glassCircleGradientEnd,
    required this.glassCircleBorder,
    required this.refreshColor,
    required this.refreshBackground,
    required this.shadowSoft,
    required this.panelSurface,
    required this.panelBorder,
    required this.iconDim,
  });

  final bool isLight;
  final Color scaffold;
  final List<Color> pageGradient;
  final Color onChrome;
  final Color muted;
  final Color mutedStrong;
  final List<Color> heroGradient;
  final Color heroBorder;
  final Color surfaceCard;
  final Color surfaceCardBorder;
  final Color skeletonFill;
  final Color skeletonLine;
  final Color skeletonLineDim;
  final Color chipSelectedBg;
  final Color chipUnselectedBg;
  final Color chipSelectedBorder;
  final Color chipUnselectedBorder;
  final Color chipSelectedFg;
  final Color chipUnselectedFg;
  final Color glassCircleGradientStart;
  final Color glassCircleGradientEnd;
  final Color glassCircleBorder;
  final Color refreshColor;
  final Color refreshBackground;
  final Color shadowSoft;
  final Color panelSurface;
  final Color panelBorder;
  final Color iconDim;

  static StSupportShellStyle of(BuildContext context) {
    final ThemeData t = Theme.of(context);
    final ColorScheme c = t.colorScheme;
    if (t.brightness == Brightness.light) {
      return StSupportShellStyle._(
        isLight: true,
        scaffold: t.scaffoldBackgroundColor,
        pageGradient: <Color>[
          t.scaffoldBackgroundColor,
          c.surfaceContainerLow,
        ],
        onChrome: c.onSurface,
        muted: c.onSurface.withValues(alpha: 0.62),
        mutedStrong: c.onSurface.withValues(alpha: 0.5),
        heroGradient: <Color>[
          c.primary.withValues(alpha: 0.10),
          c.primary.withValues(alpha: 0.18),
        ],
        heroBorder: c.outline.withValues(alpha: 0.45),
        surfaceCard: c.surface,
        surfaceCardBorder: c.outline.withValues(alpha: 0.45),
        skeletonFill: c.surfaceContainerHighest.withValues(alpha: 0.85),
        skeletonLine: c.outline.withValues(alpha: 0.4),
        skeletonLineDim: c.surfaceContainerHighest,
        chipSelectedBg: c.primary.withValues(alpha: 0.14),
        chipUnselectedBg: c.surfaceContainerLow,
        chipSelectedBorder: c.primary.withValues(alpha: 0.4),
        chipUnselectedBorder: c.outline.withValues(alpha: 0.35),
        chipSelectedFg: c.primary,
        chipUnselectedFg: c.onSurface.withValues(alpha: 0.55),
        glassCircleGradientStart: c.primary.withValues(alpha: 0.18),
        glassCircleGradientEnd: c.surfaceContainerLow,
        glassCircleBorder: c.outline.withValues(alpha: 0.4),
        refreshColor: c.primary,
        refreshBackground: c.surface,
        shadowSoft: c.shadow.withValues(alpha: 0.08),
        panelSurface: c.surface,
        panelBorder: c.outline.withValues(alpha: 0.35),
        iconDim: c.onSurface.withValues(alpha: 0.32),
      );
    }
    return StSupportShellStyle._(
      isLight: false,
      scaffold: AppColors.supportBackground,
      pageGradient: AppColors.supportSurfaceGradient,
      onChrome: Colors.white,
      muted: Colors.white.withValues(alpha: 0.72),
      mutedStrong: Colors.white.withValues(alpha: 0.58),
      heroGradient: AppColors.supportSurfaceGradient,
      heroBorder: Colors.white.withValues(alpha: 0.10),
      surfaceCard: Colors.white.withValues(alpha: 0.06),
      surfaceCardBorder: Colors.white.withValues(alpha: 0.10),
      skeletonFill: Colors.white.withValues(alpha: 0.05),
      skeletonLine: Colors.white.withValues(alpha: 0.12),
      skeletonLineDim: Colors.white.withValues(alpha: 0.08),
      chipSelectedBg: AppColors.primary.withValues(alpha: 0.22),
      chipUnselectedBg: Colors.white.withValues(alpha: 0.06),
      chipSelectedBorder: AppColors.accent.withValues(alpha: 0.45),
      chipUnselectedBorder: Colors.white.withValues(alpha: 0.10),
      chipSelectedFg: Colors.white,
      chipUnselectedFg: Colors.white.withValues(alpha: 0.58),
      glassCircleGradientStart:
          AppColors.supportTopSurface.withValues(alpha: 0.35),
      glassCircleGradientEnd: Colors.white.withValues(alpha: 0.06),
      glassCircleBorder: Colors.white.withValues(alpha: 0.16),
      refreshColor: Colors.white,
      refreshBackground: AppColors.primary,
      shadowSoft: Colors.black.withValues(alpha: 0.1),
      panelSurface: const Color(0xFF0E1220),
      panelBorder: Colors.white.withValues(alpha: 0.1),
      iconDim: Colors.white.withValues(alpha: 0.3),
    );
  }
}
