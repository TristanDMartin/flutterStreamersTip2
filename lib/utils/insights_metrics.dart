/// Pure helpers for creator video insight rates — no fabricated demographics.
class InsightsMetrics {
  InsightsMetrics._();

  static double engagementRatePercent({
    required int views,
    required int likes,
    required int comments,
    required int shares,
    required int bookmarks,
  }) {
    if (views <= 0) {
      return 0;
    }
    final int total = likes + comments + shares + bookmarks;
    return (total / views) * 100;
  }

  static double ratePercent({required int numerator, required int denominator}) {
    if (denominator <= 0) {
      return 0;
    }
    return (numerator / denominator) * 100;
  }

  static String formatCount(int value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    }
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    }
    return value.toString();
  }

  static String formatPercent(double value, {int digits = 1}) {
    return '${value.toStringAsFixed(digits)}%';
  }

  static String formatDurationSeconds(double seconds) {
    if (seconds <= 0) {
      return '—';
    }
    if (seconds >= 3600) {
      final int hours = seconds ~/ 3600;
      final int minutes = (seconds % 3600) ~/ 60;
      return '${hours}h ${minutes}m';
    }
    if (seconds >= 60) {
      final int minutes = seconds ~/ 60;
      final int secs = seconds.round() % 60;
      return '${minutes}m ${secs}s';
    }
    return '${seconds.round()}s';
  }
}
