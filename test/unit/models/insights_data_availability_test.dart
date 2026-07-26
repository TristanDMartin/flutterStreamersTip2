import 'package:flutter_test/flutter_test.dart';
import 'package:streamers_tip/models/insights_data.dart';

InsightsData _insights({
  required int views,
  int likes = 0,
}) {
  return InsightsData(
    videoId: 'v1',
    dateRange: DateTime(2026, 1, 1),
    overview: OverviewMetrics(
      totalViews: views,
      totalWatchTime: Duration.zero,
      shares: 0,
      comments: 0,
      retentionRate: 0,
      trafficSources: const <TrafficSource>[],
      searchQueries: const <String>[],
    ),
    viewers: ViewerMetrics(
      totalViews: views,
      uniqueViewers: views,
      viewerTypes: ViewerTypes(newViewers: 0, returningViewers: 0),
      genderBreakdown: GenderBreakdown(
        male: 0,
        female: 0,
        other: 0,
        unknown: 0,
      ),
      ageGroups: const <AgeGroup>[],
      topLocations: const <Location>[],
    ),
    engagement: EngagementMetrics(
      likes: likes,
      comments: 0,
      shares: 0,
      favorites: 0,
      engagementRate: 0,
      trends: const <EngagementTrend>[],
    ),
  );
}

void main() {
  test('zero activity is not enough data — no mock numbers path', () {
    final InsightsData actual = _insights(views: 0);
    expect(actual.isNotEnoughDataYet, isTrue);
    expect(actual.hasEnoughCoreSignal, isFalse);
    expect(actual.isEarlySignal, isFalse);
    expect(actual.hasAudienceBreakdown, isFalse);
  });

  test('low views are early signal until reliable threshold', () {
    final InsightsData actual = _insights(views: 5, likes: 1);
    expect(actual.isNotEnoughDataYet, isFalse);
    expect(actual.isEarlySignal, isTrue);
    expect(actual.hasEnoughCoreSignal, isFalse);
  });

  test('enough views clears early-signal gate', () {
    final InsightsData actual = _insights(
      views: InsightsDataAvailability.minViewsForReliableRates,
    );
    expect(actual.hasEnoughCoreSignal, isTrue);
    expect(actual.isEarlySignal, isFalse);
    expect(actual.isNotEnoughDataYet, isFalse);
  });
}
