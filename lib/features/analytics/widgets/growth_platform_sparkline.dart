import 'package:flutter/material.dart';

import '../growth_analytics_view.dart';
import '../models/growth_data.dart';

class GrowthPlatformSparkline extends StatelessWidget {
  const GrowthPlatformSparkline({
    super.key,
    required this.platforms,
    required this.data,
    required this.activeDays,
  });

  final List<GrowthPlatformMeta> platforms;
  final GrowthData data;
  final int activeDays;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _GrowthSparklinePainter(
        platforms: platforms,
        data: data,
        activeDays: activeDays,
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _GrowthSparklinePainter extends CustomPainter {
  _GrowthSparklinePainter({
    required this.platforms,
    required this.data,
    required this.activeDays,
  });

  final List<GrowthPlatformMeta> platforms;
  final GrowthData data;
  final int activeDays;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) {
      return;
    }
    final Paint gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..strokeWidth = 1;
    for (int i = 1; i <= 3; i++) {
      final double y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    double maxValue = 1;
    final List<_SeriesPaintData> seriesList = <_SeriesPaintData>[];
    for (final GrowthPlatformMeta platform in platforms) {
      final List<PlatformGrowthPoint> points =
          _trimSeries(data.seriesFor(platform.key), activeDays);
      if (points.isEmpty) {
        continue;
      }
      for (final PlatformGrowthPoint point in points) {
        if (point.value > maxValue) {
          maxValue = point.value.toDouble();
        }
      }
      seriesList.add(
        _SeriesPaintData(color: platform.color, points: points),
      );
    }
    if (seriesList.isEmpty) {
      final TextPainter emptyPainter = TextPainter(
        text: const TextSpan(
          text: 'Connect platforms to see growth trends',
          style: TextStyle(color: Colors.white54, fontSize: 13),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: size.width);
      emptyPainter.paint(
        canvas,
        Offset(
          (size.width - emptyPainter.width) / 2,
          (size.height - emptyPainter.height) / 2,
        ),
      );
      return;
    }
    for (final _SeriesPaintData series in seriesList) {
      final Path path = Path();
      final Paint linePaint = Paint()
        ..color = series.color
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      for (int i = 0; i < series.points.length; i++) {
        final PlatformGrowthPoint point = series.points[i];
        final double x = series.points.length == 1
            ? size.width / 2
            : size.width * i / (series.points.length - 1);
        final double y =
            size.height - (point.value / maxValue) * (size.height - 8) - 4;
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(path, linePaint);
    }
  }

  List<PlatformGrowthPoint> _trimSeries(
    List<PlatformGrowthPoint> series,
    int days,
  ) {
    if (series.isEmpty) {
      return const <PlatformGrowthPoint>[];
    }
    final List<PlatformGrowthPoint> sorted =
        List<PlatformGrowthPoint>.from(series)
          ..sort((PlatformGrowthPoint a, PlatformGrowthPoint b) =>
              a.date.compareTo(b.date));
    if (sorted.length <= days) {
      return sorted;
    }
    return sorted.sublist(sorted.length - days);
  }

  @override
  bool shouldRepaint(covariant _GrowthSparklinePainter oldDelegate) {
    return oldDelegate.data != data || oldDelegate.activeDays != activeDays;
  }
}

class _SeriesPaintData {
  const _SeriesPaintData({
    required this.color,
    required this.points,
  });

  final Color color;
  final List<PlatformGrowthPoint> points;
}
