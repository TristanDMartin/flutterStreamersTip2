import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'creator_stats_sync_service.dart';
import 'production_logging_service.dart';
import 'video_analytics_aggregation_service.dart';

/// Unified Analytics Service - Consolidates all analytics and tracking operations
///
/// Merges functionality from:
/// - EngagementAnalyticsService
/// - VideoAnalyticsService
/// - PerformanceService
class UnifiedAnalyticsService {
  static final UnifiedAnalyticsService _instance =
      UnifiedAnalyticsService._internal();
  factory UnifiedAnalyticsService() => _instance;
  UnifiedAnalyticsService._internal();

  final ProductionLoggingService _logger = ProductionLoggingService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final VideoAnalyticsAggregationService _aggregationService =
      VideoAnalyticsAggregationService();

  // Video engagement tracking
  Future<void> trackVideoView({
    required String videoId,
    required String userId,
    required String viewerId,
    Duration? watchTime,
  }) async {
    try {
      _logger.info('Tracking video view: $videoId by $viewerId',
          tag: 'UnifiedAnalyticsService');

      await _firestore.collection('video_analytics').add({
        'videoId': videoId,
        'userId': userId,
        'viewerId': viewerId,
        'event': 'view',
        'timestamp': FieldValue.serverTimestamp(),
        'watchTime': watchTime?.inSeconds,
        'platform': defaultTargetPlatform.name,
      });
      await _firestore.collection('video_analytics').doc(videoId).set({
        'views': FieldValue.increment(1),
        'lastViewedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      _logger.info('Video view tracked successfully',
          tag: 'UnifiedAnalyticsService');

      // Trigger analytics aggregation for Insights View
      _aggregationService.triggerAggregation(videoId);
    } catch (e) {
      _logger.error('Failed to track video view',
          tag: 'UnifiedAnalyticsService', error: e);
    }
  }

  Future<void> trackVideoLike({
    required String videoId,
    required String userId,
    required String likerId,
    required bool isLiked,
  }) async {
    try {
      _logger.info(
          'Tracking video like: $videoId by $likerId (liked: $isLiked)',
          tag: 'UnifiedAnalyticsService');

      await _firestore.collection('video_analytics').add({
        'videoId': videoId,
        'userId': userId,
        'likerId': likerId,
        'event': isLiked ? 'like' : 'unlike',
        'timestamp': FieldValue.serverTimestamp(),
        'platform': defaultTargetPlatform.name,
      });

      // Update video like count
      await _firestore.collection('videos').doc(videoId).update({
        'likes': FieldValue.increment(isLiked ? 1 : -1),
      });
      await CreatorStatsSyncService().syncLikeToCreator(
        videoId: videoId,
        delta: isLiked ? 1 : -1,
      );

      _logger.info('Video like tracked successfully',
          tag: 'UnifiedAnalyticsService');

      // Trigger analytics aggregation for Insights View
      _aggregationService.triggerAggregation(videoId);
    } catch (e) {
      _logger.error('Failed to track video like',
          tag: 'UnifiedAnalyticsService', error: e);
    }
  }

  Future<void> trackVideoComment({
    required String videoId,
    required String userId,
    required String commenterId,
  }) async {
    try {
      _logger.info('Tracking video comment: $videoId by $commenterId',
          tag: 'UnifiedAnalyticsService');

      await _firestore.collection('video_analytics').add({
        'videoId': videoId,
        'userId': userId,
        'commenterId': commenterId,
        'event': 'comment',
        'timestamp': FieldValue.serverTimestamp(),
        'platform': defaultTargetPlatform.name,
      });

      // Update video comment count
      await _firestore.collection('videos').doc(videoId).update({
        'comments': FieldValue.increment(1),
      });

      _logger.info('Video comment tracked successfully',
          tag: 'UnifiedAnalyticsService');

      // Trigger analytics aggregation for Insights View
      _aggregationService.triggerAggregation(videoId);
    } catch (e) {
      _logger.error('Failed to track video comment',
          tag: 'UnifiedAnalyticsService', error: e);
    }
  }

  Future<void> trackVideoShare({
    required String videoId,
    required String userId,
    required String sharerId,
    String? shareMethod,
  }) async {
    try {
      _logger.info('Tracking video share: $videoId by $sharerId',
          tag: 'UnifiedAnalyticsService');

      await _firestore.collection('video_analytics').add({
        'videoId': videoId,
        'userId': userId,
        'sharerId': sharerId,
        'event': 'share',
        'shareMethod': shareMethod,
        'timestamp': FieldValue.serverTimestamp(),
        'platform': defaultTargetPlatform.name,
      });

      // Update video share count
      await _firestore.collection('videos').doc(videoId).update({
        'shares': FieldValue.increment(1),
      });

      _logger.info('Video share tracked successfully',
          tag: 'UnifiedAnalyticsService');

      // Trigger analytics aggregation for Insights View
      _aggregationService.triggerAggregation(videoId);
    } catch (e) {
      _logger.error('Failed to track video share',
          tag: 'UnifiedAnalyticsService', error: e);
    }
  }

  Future<void> trackVideoFavorite({
    required String videoId,
    required String userId,
    required String favoriterId,
    required bool isFavorited,
  }) async {
    try {
      _logger.info(
          'Tracking video favorite: $videoId by $favoriterId (favorited: $isFavorited)',
          tag: 'UnifiedAnalyticsService');

      await _firestore.collection('video_analytics').add({
        'videoId': videoId,
        'userId': userId,
        'favoriterId': favoriterId,
        'event': isFavorited ? 'favorite' : 'unfavorite',
        'timestamp': FieldValue.serverTimestamp(),
        'platform': defaultTargetPlatform.name,
      });

      // Update video favorite count
      await _firestore.collection('videos').doc(videoId).update({
        'favorites': FieldValue.increment(isFavorited ? 1 : -1),
      });

      _logger.info('Video favorite tracked successfully',
          tag: 'UnifiedAnalyticsService');

      // Trigger analytics aggregation for Insights View
      _aggregationService.triggerAggregation(videoId);
    } catch (e) {
      _logger.error('Failed to track video favorite',
          tag: 'UnifiedAnalyticsService', error: e);
    }
  }

  // Performance tracking
  void trackVideoLoadTime(String videoId, Duration loadTime) {
    _logger.info('Video load time: $videoId - ${loadTime.inMilliseconds}ms',
        tag: 'UnifiedAnalyticsService');
  }

  void trackVideoPlaybackStart(String videoId) {
    _logger.info('Video playback started: $videoId',
        tag: 'UnifiedAnalyticsService');
  }

  void trackVideoPlaybackPause(String videoId) {
    _logger.info('Video playback paused: $videoId',
        tag: 'UnifiedAnalyticsService');
  }

  void trackVideoPlaybackEnd(String videoId, Duration totalWatchTime) {
    _logger.info(
        'Video playback ended: $videoId - ${totalWatchTime.inSeconds}s',
        tag: 'UnifiedAnalyticsService');
  }

  // User engagement tracking
  Future<void> trackUserEngagement({
    required String userId,
    required String action,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      _logger.info('Tracking user engagement: $userId - $action',
          tag: 'UnifiedAnalyticsService');

      await _firestore.collection('user_analytics').add({
        'userId': userId,
        'action': action,
        'metadata': metadata ?? {},
        'timestamp': FieldValue.serverTimestamp(),
        'platform': defaultTargetPlatform.name,
      });

      _logger.info('User engagement tracked successfully',
          tag: 'UnifiedAnalyticsService');
    } catch (e) {
      _logger.error('Failed to track user engagement',
          tag: 'UnifiedAnalyticsService', error: e);
    }
  }

  // App performance tracking
  void trackAppPerformance({
    required String metric,
    required dynamic value,
    Map<String, dynamic>? metadata,
  }) {
    _logger.info('App performance metric: $metric = $value',
        tag: 'UnifiedAnalyticsService');

    // In a real implementation, you'd send this to your analytics service
    // For now, just log it
    if (metadata != null) {
      _logger.info('Metadata: $metadata', tag: 'UnifiedAnalyticsService');
    }
  }

  // Error tracking
  void trackError({
    required String errorType,
    required String context,
    Object? error,
    Map<String, dynamic>? metadata,
  }) {
    _logger.error('Error tracked: $errorType in $context',
        tag: 'UnifiedAnalyticsService', error: error);

    if (metadata != null) {
      _logger.info('Error metadata: $metadata', tag: 'UnifiedAnalyticsService');
    }
  }

  // Cleanup
  void dispose() {
    _logger.info('UnifiedAnalyticsService disposed',
        tag: 'UnifiedAnalyticsService');
  }
}
