import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Service for feed telemetry per spec (video_impression, video_skip, etc.)
class FeedTelemetryService {
  static final FeedTelemetryService _instance = FeedTelemetryService._internal();
  factory FeedTelemetryService() => _instance;
  FeedTelemetryService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Log video_impression — video enters viewport
  Future<void> logVideoImpression({
    required String videoId,
    required int feedPosition,
  }) async {
    await _logToFeedSkipLogs(
      videoId: videoId,
      event: 'video_impression',
      feedPosition: feedPosition,
    );
  }

  /// Log video_play_start — playback begins
  Future<void> logVideoPlayStart({
    required String videoId,
    required String source,
  }) async {
    await _logToFeedSkipLogs(
      videoId: videoId,
      event: 'video_play_start',
      source: source,
    );
  }

  /// Log video_watch_duration — paused, skipped, or ended
  Future<void> logVideoWatchDuration({
    required String videoId,
    required double watchedSeconds,
    required double totalSeconds,
    required double completionRate,
  }) async {
    await _logToFeedSkipLogs(
      videoId: videoId,
      event: 'video_watch_duration',
      watchedSeconds: watchedSeconds,
      totalSeconds: totalSeconds,
      completionRate: completionRate,
    );
  }

  /// Log video_skip — user swipes away in < 2 seconds
  Future<void> logVideoSkip({
    required String videoId,
    required double watchedSeconds,
  }) async {
    await _logToFeedSkipLogs(
      videoId: videoId,
      event: 'video_skip',
      watchedSeconds: watchedSeconds,
    );
  }

  /// Log video_load_error — player fails to load
  Future<void> logVideoLoadError({
    required String videoId,
    required String error,
    String? networkType,
    int? feedPosition,
  }) async {
    await _logToFeedSkipLogs(
      videoId: videoId,
      event: 'video_load_error',
      reason: error,
      networkType: networkType,
      feedPosition: feedPosition,
    );
  }

  /// Log video_auto_skipped — system skipped due to error
  Future<void> logVideoAutoSkipped({
    required String videoId,
    required String reason,
    int? feedPosition,
  }) async {
    await _logToFeedSkipLogs(
      videoId: videoId,
      event: 'video_auto_skipped',
      reason: reason,
      feedPosition: feedPosition,
    );
  }

  /// Log feed_tab_switch
  Future<void> logFeedTabSwitch({
    required String fromTab,
    required String toTab,
    String? previousVideoId,
  }) async {
    await _logToFeedSkipLogs(
      videoId: previousVideoId ?? '',
      event: 'feed_tab_switch',
      fromTab: fromTab,
      toTab: toTab,
    );
  }

  Future<void> _logToFeedSkipLogs({
    required String videoId,
    required String event,
    int? feedPosition,
    String? source,
    double? watchedSeconds,
    double? totalSeconds,
    double? completionRate,
    String? reason,
    String? networkType,
    String? fromTab,
    String? toTab,
  }) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      await _firestore.collection('feedSkipLogs').add({
        'videoId': videoId,
        'userId': userId,
        'event': event,
        'timestamp': FieldValue.serverTimestamp(),
        'platform': 'app',
        if (feedPosition != null) 'feedPosition': feedPosition,
        if (source != null) 'source': source,
        if (watchedSeconds != null) 'watchedSeconds': watchedSeconds,
        if (totalSeconds != null) 'totalSeconds': totalSeconds,
        if (completionRate != null) 'completionRate': completionRate,
        if (reason != null) 'reason': reason,
        if (networkType != null) 'networkType': networkType,
        if (fromTab != null) 'fromTab': fromTab,
        if (toTab != null) 'toTab': toTab,
      });
    } catch (e) {
      debugPrint('⚠️ FeedTelemetryService: Failed to log $event: $e');
    }
  }
}
