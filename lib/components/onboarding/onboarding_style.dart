import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/design/st_radius.dart';

class OnboardingStyle {
  static const Color background = Color(0xFF0F172A);
  static const Color surface = Color(0xFF1E293B);
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFFCBD5E1);
  static const Color border = Color(0x3394A3B8);
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[Color(0xFF9248D2), Color(0xFF4897D2)],
  );

  static const SystemUiOverlayStyle immersiveSystemUi = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.light,
    systemNavigationBarContrastEnforced: false,
  );

  static bool isLight(BuildContext context) =>
      Theme.of(context).brightness == Brightness.light;

  static Color surfaceFor(BuildContext context) {
    return isLight(context) ? Colors.white : surface.withValues(alpha: 0.95);
  }

  static Color textPrimaryFor(BuildContext context) {
    return isLight(context) ? const Color(0xFF111827) : textPrimary;
  }

  static Color textSecondaryFor(BuildContext context) {
    return isLight(context) ? const Color(0xFF4B5563) : textSecondary;
  }

  static Color borderFor(BuildContext context) {
    return isLight(context) ? const Color(0xFFE5E7EB) : border;
  }

  static TextStyle plainTextStyle(TextStyle style) {
    return style.copyWith(
      decoration: TextDecoration.none,
      decorationColor: Colors.transparent,
    );
  }

  static TextStyle titleFor(BuildContext context, {double fontSize = 28}) {
    return plainTextStyle(
      TextStyle(
        color: textPrimaryFor(context),
        fontSize: fontSize,
        fontWeight: FontWeight.w900,
        height: 1.15,
      ),
    );
  }

  static TextStyle bodyFor(BuildContext context, {double fontSize = 15}) {
    return plainTextStyle(
      TextStyle(
        color: textSecondaryFor(context),
        fontSize: fontSize,
        height: 1.4,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  static TextStyle labelFor(BuildContext context) {
    return plainTextStyle(
      TextStyle(
        color: textSecondaryFor(context),
        fontWeight: FontWeight.w600,
        fontSize: 13,
      ),
    );
  }

  static TextStyle tipTitleFor(BuildContext context) {
    return plainTextStyle(
      TextStyle(
        color: textPrimaryFor(context),
        fontSize: 18,
        fontWeight: FontWeight.w800,
        height: 1.2,
        letterSpacing: -0.2,
      ),
    );
  }

  static TextStyle tipBodyFor(BuildContext context) {
    return plainTextStyle(
      TextStyle(
        color: textSecondaryFor(context),
        fontSize: 14,
        fontWeight: FontWeight.w500,
        height: 1.45,
      ),
    );
  }

  static TextStyle tipLabelFor(BuildContext context) {
    return plainTextStyle(
      TextStyle(
        color: const Color(0xFF9248D2).withValues(alpha: 0.9),
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.6,
      ),
    );
  }

  static BoxDecoration tipCardDecoration(BuildContext context) {
    final bool light = isLight(context);
    return BoxDecoration(
      borderRadius: BorderRadius.circular(STRadius.sheet),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: light
            ? <Color>[
                Colors.white,
                const Color(0xFFF8F5FF),
              ]
            : <Color>[
                const Color(0xFF1E1B2E),
                const Color(0xFF12101C),
              ],
      ),
      border: Border.all(
        color: light
            ? const Color(0xFF9248D2).withValues(alpha: 0.22)
            : const Color(0xFF9248D2).withValues(alpha: 0.38),
      ),
      boxShadow: <BoxShadow>[
        BoxShadow(
          color: const Color(0xFF9248D2).withValues(alpha: light ? 0.08 : 0.18),
          blurRadius: 28,
          offset: const Offset(0, 10),
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: light ? 0.08 : 0.42),
          blurRadius: 24,
          offset: const Offset(0, 12),
        ),
      ],
    );
  }

  static BoxDecoration cardDecoration({
    BuildContext? context,
    double radius = 20,
  }) {
    final Color resolvedSurface =
        context == null ? surface.withValues(alpha: 0.95) : surfaceFor(context);
    final Color resolvedBorder = context == null ? border : borderFor(context);
    return BoxDecoration(
      color: resolvedSurface,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: resolvedBorder),
      boxShadow: <BoxShadow>[
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.35),
          blurRadius: 60,
          offset: const Offset(0, 20),
        ),
      ],
    );
  }
}

class GradientPillButton extends StatelessWidget {
  const GradientPillButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.useSolidPurple = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool useSolidPurple;

  @override
  Widget build(BuildContext context) {
    final bool isEnabled = onPressed != null;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: isEnabled && !useSolidPurple
            ? OnboardingStyle.primaryGradient
            : null,
        color: !isEnabled
            ? Colors.white12
            : useSolidPurple
                ? const Color(0xFF9248D2)
                : null,
        borderRadius: BorderRadius.circular(999),
        boxShadow: isEnabled && useSolidPurple
            ? <BoxShadow>[
                BoxShadow(
                  color: const Color(0xFF9248D2).withValues(alpha: 0.35),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                if (icon != null) ...[
                  Icon(icon, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: OnboardingStyle.plainTextStyle(
                      const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
