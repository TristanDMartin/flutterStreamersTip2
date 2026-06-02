import 'package:flutter/material.dart';
import '../models/insights_data.dart';
import 'dart:math' as math;

/// Custom chart widgets for insights visualization

/// Retention chart showing watch time retention
class RetentionChart extends StatelessWidget {
  final double retentionRate;

  const RetentionChart({
    super.key,
    required this.retentionRate,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 120,
      child: CustomPaint(
        painter: RetentionChartPainter(retentionRate),
        size: Size.infinite,
      ),
    );
  }
}

class RetentionChartPainter extends CustomPainter {
  final double retentionRate;

  RetentionChartPainter(this.retentionRate);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF40DCD1)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final fillPaint = Paint()
      ..color = const Color(0xFF40DCD1).withValues(alpha: 0.2)
      ..style = PaintingStyle.fill;

    // Create a curved line representing retention
    final path = Path();
    final fillPath = Path();

    // Start at top left
    path.moveTo(0, size.height * 0.1);
    fillPath.moveTo(0, size.height);

    // Create retention curve
    for (int i = 0; i <= 100; i++) {
      final x = (i / 100) * size.width;
      final progress = i / 100.0;

      // Simulate retention curve (starts high, gradually decreases)
      final retentionAtPoint = retentionRate * math.exp(-progress * 0.5);
      final y = size.height * (1 - retentionAtPoint);

      if (i == 0) {
        path.moveTo(x, y);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }

    // Complete the fill path
    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    // Draw filled area
    canvas.drawPath(fillPath, fillPaint);

    // Draw line
    canvas.drawPath(path, paint);

    // Draw points at key milestones
    final pointPaint = Paint()
      ..color = const Color(0xFF40DCD1)
      ..style = PaintingStyle.fill;

    // 25% mark
    canvas.drawCircle(
      Offset(size.width * 0.25, size.height * (1 - retentionRate * 0.8)),
      4,
      pointPaint,
    );

    // 50% mark
    canvas.drawCircle(
      Offset(size.width * 0.5, size.height * (1 - retentionRate * 0.6)),
      4,
      pointPaint,
    );

    // 75% mark
    canvas.drawCircle(
      Offset(size.width * 0.75, size.height * (1 - retentionRate * 0.4)),
      4,
      pointPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// Traffic sources pie chart
class TrafficSourcesChart extends StatelessWidget {
  final List<TrafficSource> sources;

  const TrafficSourcesChart({
    super.key,
    required this.sources,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      child: CustomPaint(
        painter: TrafficSourcesChartPainter(sources),
        size: Size.infinite,
      ),
    );
  }
}

class TrafficSourcesChartPainter extends CustomPainter {
  final List<TrafficSource> sources;

  TrafficSourcesChartPainter(this.sources);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 20;

    final colors = [
      const Color(0xFF9248D2),
      const Color(0xFF40DCD1),
      const Color(0xFF1670DE),
      const Color(0xFFE91E63),
    ];

    double startAngle = -math.pi / 2;

    for (int i = 0; i < sources.length; i++) {
      final source = sources[i];
      final sweepAngle = (source.percentage / 100) * 2 * math.pi;

      final paint = Paint()
        ..color = colors[i % colors.length]
        ..style = PaintingStyle.fill;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        true,
        paint,
      );

      startAngle += sweepAngle;
    }

    // Draw center circle
    final centerPaint = Paint()
      ..color = const Color(0xFF1C135D)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, radius * 0.4, centerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// Viewer types donut chart
class ViewerTypesChart extends StatelessWidget {
  final int newViewers;
  final int returningViewers;

  const ViewerTypesChart({
    super.key,
    required this.newViewers,
    required this.returningViewers,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 180,
      child: CustomPaint(
        painter: ViewerTypesChartPainter(newViewers, returningViewers),
        size: Size.infinite,
      ),
    );
  }
}

class ViewerTypesChartPainter extends CustomPainter {
  final int newViewers;
  final int returningViewers;

  ViewerTypesChartPainter(this.newViewers, this.returningViewers);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 20;
    final total = newViewers + returningViewers;

    if (total == 0) return;

    final newPercentage = newViewers / total;
    final returningPercentage = returningViewers / total;

    // Draw new viewers arc
    final newPaint = Paint()
      ..color = const Color(0xFF9248D2)
      ..style = PaintingStyle.fill;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      newPercentage * 2 * math.pi,
      true,
      newPaint,
    );

    // Draw returning viewers arc
    final returningPaint = Paint()
      ..color = const Color(0xFF40DCD1)
      ..style = PaintingStyle.fill;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2 + newPercentage * 2 * math.pi,
      returningPercentage * 2 * math.pi,
      true,
      returningPaint,
    );

    // Draw center circle
    final centerPaint = Paint()
      ..color = const Color(0xFF1C135D)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, radius * 0.5, centerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// Gender breakdown donut chart
class GenderBreakdownChart extends StatelessWidget {
  final GenderBreakdown breakdown;

  const GenderBreakdownChart({
    super.key,
    required this.breakdown,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 180,
      child: CustomPaint(
        painter: GenderBreakdownChartPainter(breakdown),
        size: Size.infinite,
      ),
    );
  }
}

class GenderBreakdownChartPainter extends CustomPainter {
  final GenderBreakdown breakdown;

  GenderBreakdownChartPainter(this.breakdown);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 20;

    final total =
        breakdown.male + breakdown.female + breakdown.other + breakdown.unknown;
    if (total == 0) return;

    final colors = [
      const Color(0xFF1670DE), // Male
      const Color(0xFFE91E63), // Female
      const Color(0xFF40DCD1), // Other
      Colors.grey, // Unknown
    ];

    final values = [
      breakdown.male / total,
      breakdown.female / total,
      breakdown.other / total,
      breakdown.unknown / total,
    ];

    double startAngle = -math.pi / 2;

    for (int i = 0; i < values.length; i++) {
      final percentage = values[i];
      final sweepAngle = percentage * 2 * math.pi;

      if (percentage > 0) {
        final paint = Paint()
          ..color = colors[i]
          ..style = PaintingStyle.fill;

        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius),
          startAngle,
          sweepAngle,
          true,
          paint,
        );

        startAngle += sweepAngle;
      }
    }

    // Draw center circle
    final centerPaint = Paint()
      ..color = const Color(0xFF1C135D)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, radius * 0.5, centerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// Age groups bar chart
class AgeGroupsChart extends StatelessWidget {
  final List<AgeGroup> ageGroups;

  const AgeGroupsChart({
    super.key,
    required this.ageGroups,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 120,
      child: CustomPaint(
        painter: AgeGroupsChartPainter(ageGroups),
        size: Size.infinite,
      ),
    );
  }
}

class AgeGroupsChartPainter extends CustomPainter {
  final List<AgeGroup> ageGroups;

  AgeGroupsChartPainter(this.ageGroups);

  @override
  void paint(Canvas canvas, Size size) {
    if (ageGroups.isEmpty) return;

    final barWidth = (size.width - 40) / ageGroups.length;
    final maxValue = ageGroups.map((e) => e.percentage).reduce(math.max);

    for (int i = 0; i < ageGroups.length; i++) {
      final ageGroup = ageGroups[i];
      final barHeight = (ageGroup.percentage / maxValue) * (size.height - 40);

      final paint = Paint()
        ..color = const Color(0xFF9248D2).withValues(alpha: 0.8)
        ..style = PaintingStyle.fill;

      final rect = Rect.fromLTWH(
        20 + i * barWidth + 4,
        size.height - barHeight - 20,
        barWidth - 8,
        barHeight,
      );

      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(4)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// Engagement trends line chart
class EngagementTrendsChart extends StatelessWidget {
  final List<EngagementTrend> trends;

  const EngagementTrendsChart({
    super.key,
    required this.trends,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      child: CustomPaint(
        painter: EngagementTrendsChartPainter(trends),
        size: Size.infinite,
      ),
    );
  }
}

class EngagementTrendsChartPainter extends CustomPainter {
  final List<EngagementTrend> trends;

  EngagementTrendsChartPainter(this.trends);

  @override
  void paint(Canvas canvas, Size size) {
    if (trends.isEmpty) return;

    // Calculate max value for scaling
    final maxValue = trends
        .map((e) => math.max(
            e.likes, math.max(e.shares, math.max(e.comments, e.favorites))))
        .reduce(math.max)
        .toDouble();

    // Draw grid lines
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.1)
      ..strokeWidth = 1;

    for (int i = 0; i <= 4; i++) {
      final y = (size.height - 40) * i / 4 + 20;
      canvas.drawLine(Offset(40, y), Offset(size.width - 20, y), gridPaint);
    }

    // Draw trend lines
    final colors = [
      const Color(0xFFE91E63), // Likes
      const Color(0xFF1670DE), // Shares
      const Color(0xFF40DCD1), // Comments
      const Color(0xFF9248D2), // Favorites
    ];

    final data = [
      trends.map((e) => e.likes.toDouble()).toList(),
      trends.map((e) => e.shares.toDouble()).toList(),
      trends.map((e) => e.comments.toDouble()).toList(),
      trends.map((e) => e.favorites.toDouble()).toList(),
    ];

    for (int dataIndex = 0; dataIndex < data.length; dataIndex++) {
      final linePaint = Paint()
        ..color = colors[dataIndex]
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;

      final path = Path();
      final pointPaint = Paint()
        ..color = colors[dataIndex]
        ..style = PaintingStyle.fill;

      for (int i = 0; i < data[dataIndex].length; i++) {
        final x = 40 + (i / (data[dataIndex].length - 1)) * (size.width - 60);
        final y = size.height -
            20 -
            (data[dataIndex][i] / maxValue) * (size.height - 40);

        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }

        // Draw points
        canvas.drawCircle(Offset(x, y), 3, pointPaint);
      }

      canvas.drawPath(path, linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// Engagement breakdown donut chart
class EngagementBreakdownChart extends StatelessWidget {
  final int likes;
  final int shares;
  final int comments;
  final int favorites;

  const EngagementBreakdownChart({
    super.key,
    required this.likes,
    required this.shares,
    required this.comments,
    required this.favorites,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 180,
      child: CustomPaint(
        painter:
            EngagementBreakdownChartPainter(likes, shares, comments, favorites),
        size: Size.infinite,
      ),
    );
  }
}

class EngagementBreakdownChartPainter extends CustomPainter {
  final int likes;
  final int shares;
  final int comments;
  final int favorites;

  EngagementBreakdownChartPainter(
      this.likes, this.shares, this.comments, this.favorites);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 20;

    final total = likes + shares + comments + favorites;
    if (total == 0) return;

    final colors = [
      const Color(0xFFE91E63), // Likes
      const Color(0xFF1670DE), // Shares
      const Color(0xFF40DCD1), // Comments
      const Color(0xFF9248D2), // Favorites
    ];

    final values = [
      likes / total,
      shares / total,
      comments / total,
      favorites / total,
    ];

    double startAngle = -math.pi / 2;

    for (int i = 0; i < values.length; i++) {
      final percentage = values[i];
      final sweepAngle = percentage * 2 * math.pi;

      if (percentage > 0) {
        final paint = Paint()
          ..color = colors[i]
          ..style = PaintingStyle.fill;

        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius),
          startAngle,
          sweepAngle,
          true,
          paint,
        );

        startAngle += sweepAngle;
      }
    }

    // Draw center circle
    final centerPaint = Paint()
      ..color = const Color(0xFF1C135D)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, radius * 0.5, centerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
