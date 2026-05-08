import 'package:flutter/material.dart';

/// Theme-aware chrome for full-screen flows (Activity, Threads, Progression).
/// Dark mode follows [ThemeData.colorScheme] — not the legacy purple support shell.
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
    final Color surface = c.surface;
    final Color surfaceLow = c.surfaceContainerLow;
    return StSupportShellStyle._(
      isLight: false,
      scaffold: t.scaffoldBackgroundColor,
      pageGradient: <Color>[
        t.scaffoldBackgroundColor,
        surfaceLow,
      ],
      onChrome: c.onSurface,
      muted: c.onSurfaceVariant,
      mutedStrong: c.onSurfaceVariant.withValues(alpha: 0.88),
      heroGradient: <Color>[
        c.primary.withValues(alpha: 0.12),
        c.primary.withValues(alpha: 0.22),
      ],
      heroBorder: c.outline.withValues(alpha: 0.4),
      surfaceCard: surface,
      surfaceCardBorder: c.outline.withValues(alpha: 0.35),
      skeletonFill: c.surfaceContainerHighest.withValues(alpha: 0.55),
      skeletonLine: c.outline.withValues(alpha: 0.32),
      skeletonLineDim: c.surfaceContainerHighest.withValues(alpha: 0.4),
      chipSelectedBg: c.primary.withValues(alpha: 0.2),
      chipUnselectedBg: surfaceLow,
      chipSelectedBorder: c.primary.withValues(alpha: 0.45),
      chipUnselectedBorder: c.outline.withValues(alpha: 0.28),
      chipSelectedFg: c.primary,
      chipUnselectedFg: c.onSurface.withValues(alpha: 0.55),
      glassCircleGradientStart: c.primary.withValues(alpha: 0.24),
      glassCircleGradientEnd: surfaceLow,
      glassCircleBorder: c.outline.withValues(alpha: 0.38),
      refreshColor: c.primary,
      refreshBackground: surface,
      shadowSoft: Colors.black.withValues(alpha: 0.22),
      panelSurface: surface,
      panelBorder: c.outline.withValues(alpha: 0.35),
      iconDim: c.onSurface.withValues(alpha: 0.38),
    );
  }
}
