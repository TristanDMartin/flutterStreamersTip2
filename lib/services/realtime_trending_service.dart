import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:streamers_tip/utils/secure_log.dart';

/// Real-time trending service - Surfaces hot content instantly
/// Implements burst detection, geographic trending, and time-of-day optimization
class RealtimeTrendingService {
  static RealtimeTrendingService? _instance;
  static RealtimeTrendingService get instance =>
      _instance ??= RealtimeTrendingService._();

  RealtimeTrendingService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Trending boost multipliers
  static const double burstBoost = 3.0; // Sudden viral spike
  static const double hourlyTrendingBoost = 2.0; // Trending last hour
  static const double primeTimeBoost = 1.3; // 7pm-11pm boost

  /// Calculate real-time trending boost for a video
  Future<double> calculateTrendingBoost(String videoId) async {
    try {
      double multiplier = 1.0;

      // 1. Detect burst (sudden engagement spike)
      final burstScore = await _detectBurst(videoId);
      if (burstScore > 0.7) {
        multiplier *= burstBoost;
        secureLog('💥 Burst detected for $videoId - ${burstBoost}x');
      }

      // 2. Hourly trending (last 1-6 hours)
      final hourlyScore = await _getHourlyTrendingScore(videoId);
      if (hourlyScore > 0.6) {
        multiplier *= hourlyTrendingBoost;
        secureLog('🔥 Hourly trending for $videoId - ${hourlyTrendingBoost}x');
      }

      // 3. Time-of-day optimization
      final timeMultiplier = _getTimeOfDayMultiplier();
      multiplier *= timeMultiplier;
      if (timeMultiplier > 1.0) {
        secureLog('🕐 Prime time boost - ${timeMultiplier}x');
      }

      secureLog(
          '✅ Total trending boost for $videoId: ${multiplier.toStringAsFixed(2)}x');
      return multiplier;
    } catch (e) {
      secureLog('❌ Error calculating trending boost: $e');
      return 1.0;
    }
  }

  /// Detect engagement burst (sudden spike)
  Future<double> _detectBurst(String videoId) async {
    try {
      final now = DateTime.now();

      // Get engagement in last hour
      final lastHour = await _getEngagementCount(
        videoId,
        now.subtract(const Duration(hours: 1)),
        now,
      );

      // Get engagement in previous hour
      final previousHour = await _getEngagementCount(
        videoId,
        now.subtract(const Duration(hours: 2)),
        now.subtract(const Duration(hours: 1)),
      );

      if (previousHour == 0) return lastHour > 10 ? 1.0 : 0.0;

      // Calculate acceleration (% increase)
      final acceleration = (lastHour - previousHour) / previousHour;

      // Burst = >200% increase in engagement
      final burstScore = (acceleration / 2.0).clamp(0.0, 1.0);

      secureLog(
          '💥 Burst detection: $videoId - last hour: $lastHour, prev: $previousHour, score: ${burstScore.toStringAsFixed(2)}');

      return burstScore;
    } catch (e) {
      secureLog('❌ Error detecting burst: $e');
      return 0.0;
    }
  }

  /// Get hourly trending score (last 1-6 hours)
  Future<double> _getHourlyTrendingScore(String videoId) async {
    try {
      final now = DateTime.now();
      final sixHoursAgo = now.subtract(const Duration(hours: 6));

      // Get total engagement in last 6 hours
      final engagementCount =
          await _getEngagementCount(videoId, sixHoursAgo, now);

      // Get video views in last 6 hours
      final viewsCount = await _getViewsCount(videoId, sixHoursAgo, now);

      if (viewsCount == 0) return 0.0;

      // Calculate engagement rate
      final engagementRate = engagementCount / viewsCount;

      // Trending if >30% engagement rate with >50 views
      final trendingScore = (engagementRate * 3.0).clamp(0.0, 1.0);

      if (viewsCount > 50) {
        secureLog(
            '🔥 Hourly trending: $videoId - $engagementCount/$viewsCount = ${trendingScore.toStringAsFixed(2)}');
        return trendingScore;
      }

      return 0.0;
    } catch (e) {
      secureLog('❌ Error calculating hourly trending: $e');
      return 0.0;
    }
  }

  /// Get engagement count in time window
  Future<int> _getEngagementCount(
      String videoId, DateTime start, DateTime end) async {
    try {
      final snapshot = await _firestore
          .collection('engagement')
          .where('videoId', isEqualTo: videoId)
          .where('lastUpdated', isGreaterThan: Timestamp.fromDate(start))
          .where('lastUpdated', isLessThan: Timestamp.fromDate(end))
          .where('engagementScore',
              isGreaterThan: 5.0) // Significant engagement only
          .get();

      return snapshot.docs.length;
    } catch (e) {
      if (e.toString().contains('permission-denied') ||
          e.toString().contains('PERMISSION_DENIED')) {
        return 0;
      }
      secureLog('❌ Error getting engagement count: $e');
      return 0;
    }
  }

  /// Get views count in time window
  Future<int> _getViewsCount(
      String videoId, DateTime start, DateTime end) async {
    try {
      final snapshot = await _firestore
          .collection('engagement')
          .where('videoId', isEqualTo: videoId)
          .where('lastUpdated', isGreaterThan: Timestamp.fromDate(start))
          .where('lastUpdated', isLessThan: Timestamp.fromDate(end))
          .get();

      return snapshot.docs.length;
    } catch (e) {
      secureLog('❌ Error getting views count: $e');
      return 0;
    }
  }

  /// Get time-of-day multiplier
  double _getTimeOfDayMultiplier() {
    final hour = DateTime.now().hour;

    // Prime time (7pm-11pm): 1.3x boost
    if (hour >= 19 && hour <= 23) {
      return primeTimeBoost;
    }

    // Lunch time (12pm-1pm): 1.15x boost
    if (hour >= 12 && hour <= 13) {
      return 1.15;
    }

    // Early morning (6am-8am): 1.1x boost
    if (hour >= 6 && hour <= 8) {
      return 1.1;
    }

    // Late night (12am-2am): 0.9x (lower engagement)
    if (hour >= 0 && hour <= 2) {
      return 0.9;
    }

    return 1.0; // Normal hours
  }

  /// Check if video is trending geographically
  Future<bool> isGeoTrending(String videoId, String? userLocation) async {
    if (userLocation == null) return false;

    try {
      // Get engagement from same geographic area
      final snapshot = await _firestore
          .collection('engagement')
          .where('videoId', isEqualTo: videoId)
          .where('location', isEqualTo: userLocation)
          .where('lastUpdated',
              isGreaterThan: Timestamp.fromDate(
                  DateTime.now().subtract(const Duration(hours: 24))))
          .limit(20)
          .get();

      // Trending if >10 users from same location engaged
      return snapshot.docs.length >= 10;
    } catch (e) {
      if (e.toString().contains('permission-denied') ||
          e.toString().contains('PERMISSION_DENIED')) {
        return false;
      }
      secureLog('❌ Error checking geo trending: $e');
      return false;
    }
  }

  /// Get trending videos for user's network
  Future<List<String>> getTrendingInNetwork(String userId,
      {int limit = 20}) async {
    try {
      // Get user's connections
      final connectionsSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('connections')
          .where('followState', whereIn: ['mutual', 'following'])
          .limit(50)
          .get();

      final connectionIds =
          connectionsSnapshot.docs.map((doc) => doc.id).toList();

      if (connectionIds.isEmpty) return [];

      // ✅ FIX: Client-side engagement queries are not allowed (requires complex indexes + violates security)
      // This should be computed server-side and exposed via public aggregates
      // TODO: Move to server-side (Cloud Functions)
      // Server should:
      // 1. Compute trending videos based on engagement (server-side only)
      // 2. Store results in: trending_network/{userId} or public_trending/{timeWindow}
      // 3. Client reads only pre-computed results

      secureLog(
          '⚠️ Trending in network: Feature disabled (should be server-side)');
      return [];
    } catch (e) {
      secureLog('❌ Error getting trending in network: $e');
      return [];
    }
  }
}
