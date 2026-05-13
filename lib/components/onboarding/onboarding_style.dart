import 'package:flutter/material.dart';

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
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: onPressed == null ? null : OnboardingStyle.primaryGradient,
        color: onPressed == null ? Colors.white12 : null,
        borderRadius: BorderRadius.circular(999),
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
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
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
