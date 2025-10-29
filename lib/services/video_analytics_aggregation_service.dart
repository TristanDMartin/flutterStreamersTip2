import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Service to aggregate video analytics data from individual events
/// into summary documents for the Insights View
///
/// This service aggregates data from 'video_analytics' collection (individual events)
/// into 'videoAnalytics' collection (aggregated summaries)
class VideoAnalyticsAggregationService {
  static final VideoAnalyticsAggregationService _instance =
      VideoAnalyticsAggregationService._internal();
  factory VideoAnalyticsAggregationService() => _instance;
  VideoAnalyticsAggregationService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Aggregate analytics for a specific video
  Future<void> aggregateVideoAnalytics(String videoId) async {
    try {
      debugPrint('🔍 Aggregating analytics for video: $videoId');

      // Get all analytics events for this video
      final eventsSnapshot = await _firestore
          .collection('video_analytics')
          .where('videoId', isEqualTo: videoId)
          .get();

      // Get video document for baseline counts
      final videoDoc = await _firestore.collection('videos').doc(videoId).get();
      final videoData = videoDoc.data() ?? {};

      // Aggregate data
      int totalViews = videoData['views'] ?? 0;
      int totalLikes = videoData['likes'] ?? 0;
      int totalComments = videoData['comments'] ?? 0;
      int totalShares = videoData['shares'] ?? 0;
      int totalFavorites = videoData['favorites'] ?? 0;

      // Track unique viewers
      final Set<String> uniqueViewers = {};
      double totalWatchTime = 0.0;
      int viewCount = 0;

      // Process each event
      for (final doc in eventsSnapshot.docs) {
        final data = doc.data();
        final event = data['event'] as String?;
        final viewerId = data['viewerId'] as String?;
        final watchTime = data['watchTime'] as int?;

        if (event == 'view' && viewerId != null) {
          uniqueViewers.add(viewerId);
          if (watchTime != null) {
            totalWatchTime += watchTime.toDouble();
            viewCount++;
          }
        }
      }

      // Calculate metrics
      final averageWatchTime = viewCount > 0 ? totalWatchTime / viewCount : 0.0;
      final engagementRate = totalViews > 0
          ? (totalLikes + totalComments + totalShares + totalFavorites) /
              totalViews
          : 0.0;

      // For retention rate, we'd need more detailed watch session data
      // For now, use a simple estimate based on average watch time and video duration
      final videoDuration = (videoData['duration'] ?? 0.0).toDouble();
      final retentionRate = videoDuration > 0
          ? (averageWatchTime / videoDuration).clamp(0.0, 1.0)
          : 0.0;

      // Create aggregated analytics document
      final aggregatedData = {
        'videoId': videoId,
        'views': totalViews,
        'likes': totalLikes,
        'comments': totalComments,
        'shares': totalShares,
        'favorites': totalFavorites,
        'watchTime': totalWatchTime,
        'uniqueViewers': uniqueViewers.length,
        'averageWatchTime': averageWatchTime,
        'engagementRate': engagementRate,
        'retentionRate': retentionRate,
        'audienceReach': uniqueViewers.length,
        'completionRate': retentionRate, // Same as retention for now
        'lastUpdated': FieldValue.serverTimestamp(),
      };

      // Write to videoAnalytics collection (camelCase - what InsightsView reads from)
      await _firestore
          .collection('videoAnalytics')
          .doc(videoId)
          .set(aggregatedData, SetOptions(merge: true));

      debugPrint('✅ Successfully aggregated analytics for video: $videoId');
      debugPrint(
          '   Views: $totalViews, Likes: $totalLikes, Comments: $totalComments, Shares: $totalShares, Favorites: $totalFavorites');
      debugPrint(
          '   Unique Viewers: ${uniqueViewers.length}, Avg Watch Time: ${averageWatchTime.toStringAsFixed(1)}s');
    } catch (e) {
      debugPrint('❌ Error aggregating analytics for video $videoId: $e');
    }
  }

  /// Aggregate analytics for multiple videos (batch operation)
  Future<void> aggregateMultipleVideos(List<String> videoIds) async {
    for (final videoId in videoIds) {
      await aggregateVideoAnalytics(videoId);
      // Small delay to avoid overwhelming Firestore
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }

  /// Aggregate analytics for all user's videos
  Future<void> aggregateUserVideos(String userId) async {
    try {
      debugPrint('🔍 Aggregating analytics for all videos by user: $userId');

      final videosSnapshot = await _firestore
          .collection('videos')
          .where('creatorId', isEqualTo: userId)
          .get();

      final videoIds = videosSnapshot.docs.map((doc) => doc.id).toList();

      debugPrint('   Found ${videoIds.length} videos to aggregate');

      await aggregateMultipleVideos(videoIds);

      debugPrint('✅ Completed aggregation for all user videos');
    } catch (e) {
      debugPrint('❌ Error aggregating user videos: $e');
    }
  }

  /// Trigger aggregation when a video analytics event occurs
  /// This should be called after trackVideoView, trackVideoLike, etc.
  Future<void> triggerAggregation(String videoId) async {
    // Run aggregation in background without blocking
    Future.microtask(() => aggregateVideoAnalytics(videoId));
  }
}
