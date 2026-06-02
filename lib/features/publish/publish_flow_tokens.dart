import 'package:flutter/material.dart';

/// Shared glass / surface tokens for Create → Preview → Publish.
abstract final class PublishFlowTokens {
  static const Color background = Color(0xFF070B14);
  static const Color surface = Color(0x0AFFFFFF);
  static const Color border = Color(0x14FFFFFF);
  static const Color primaryStart = Color(0xFF9248D2);
  static const Color primaryEnd = Color(0xFF4897D2);

  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: <Color>[primaryStart, primaryEnd],
  );

  static BoxDecoration glassPanel({double radius = 22}) {
    return BoxDecoration(
      color: const Color(0xFF0F1322).withValues(alpha: 0.72),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: border),
    );
  }

  static BoxDecoration glassCircle() {
    return BoxDecoration(
      color: Colors.black.withValues(alpha: 0.28),
      shape: BoxShape.circle,
      border: Border.all(color: border),
    );
  }
}
