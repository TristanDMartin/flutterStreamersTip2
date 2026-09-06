import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'achievement_definition.dart';

class AchievementHexBadge extends StatelessWidget {
  const AchievementHexBadge({
    super.key,
    required this.definition,
    required this.unlocked,
    this.size = 72,
    this.animated = false,
  });

  final AchievementDefinition definition;
  final bool unlocked;
  final double size;
  final bool animated;

  static IconData iconFor(String iconName) {
    switch (iconName) {
      case 'plug':
        return Icons.power_rounded;
      case 'play':
        return Icons.play_arrow_rounded;
      case 'upload':
        return Icons.upload_rounded;
      case 'calendar':
        return Icons.calendar_month_rounded;
      case 'zap':
        return Icons.local_fire_department_rounded;
      case 'target':
        return Icons.flag_rounded;
      case 'message':
        return Icons.chat_bubble_rounded;
      case 'users':
        return Icons.people_rounded;
      case 'star':
        return Icons.star_rounded;
      case 'sparkles':
      default:
        return Icons.auto_awesome_rounded;
    }
  }

  static Color glowFor(AchievementRarity rarity) {
    switch (rarity) {
      case AchievementRarity.common:
        return const Color(0xFF94A3B8);
      case AchievementRarity.rare:
        return const Color(0xFF9248D2);
      case AchievementRarity.epic:
        return const Color(0xFFFBBF24);
    }
  }

  static Duration celebrationDuration(AchievementRarity rarity) {
    switch (rarity) {
      case AchievementRarity.common:
        return const Duration(milliseconds: 1200);
      case AchievementRarity.rare:
        return const Duration(milliseconds: 2400);
      case AchievementRarity.epic:
        return const Duration(milliseconds: 3200);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color glow = glowFor(definition.rarity);
    final Widget badge = CustomPaint(
      size: Size.square(size),
      painter: _HexBadgePainter(
        glow: glow,
        unlocked: unlocked,
      ),
      child: SizedBox(
        width: size,
        height: size,
        child: Center(
          child: Icon(
            iconFor(definition.iconName),
            color: unlocked ? Colors.white : Colors.white38,
            size: size * 0.34,
          ),
        ),
      ),
    );
    if (!animated || !unlocked) {
      return badge;
    }
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.82, end: 1),
      duration: celebrationDuration(definition.rarity),
      curve: Curves.easeOutBack,
      builder: (BuildContext _, double scale, Widget? child) {
        return Transform.scale(scale: scale, child: child);
      },
      child: badge,
    );
  }
}

class _HexBadgePainter extends CustomPainter {
  _HexBadgePainter({required this.glow, required this.unlocked});

  final Color glow;
  final bool unlocked;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double radius = size.width / 2;
    final Path hex = Path();
    for (int i = 0; i < 6; i++) {
      final double angle = (-math.pi / 2) + (i * math.pi / 3);
      final Offset point = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );
      if (i == 0) {
        hex.moveTo(point.dx, point.dy);
      } else {
        hex.lineTo(point.dx, point.dy);
      }
    }
    hex.close();
    if (unlocked) {
      canvas.drawPath(
        hex,
        Paint()
          ..color = glow.withValues(alpha: 0.28)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
      );
    }
    canvas.drawPath(
      hex,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: unlocked
              ? <Color>[const Color(0xFF1E1033), const Color(0xFF0B1220)]
              : <Color>[const Color(0xFF1E293B), const Color(0xFF0F172A)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      hex,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = unlocked ? glow : glow.withValues(alpha: 0.28),
    );
  }

  @override
  bool shouldRepaint(covariant _HexBadgePainter oldDelegate) {
    return oldDelegate.glow != glow || oldDelegate.unlocked != unlocked;
  }
}
