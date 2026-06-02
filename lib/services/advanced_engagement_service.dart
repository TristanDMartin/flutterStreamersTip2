import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:streamers_tip/utils/secure_log.dart';

import '../features/gamification/daily_activity_service.dart';

/// Advanced engagement tracking service - Better than TikTok
/// Tracks granular watch time, retention, velocity, and network effects
class AdvancedEngagementService {
  static AdvancedEngagementService? _instance;
  static AdvancedEngagementService get instance =>
      _instance ??= AdvancedEngagementService._();

  AdvancedEngagementService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Watch time tracking (granular)
  final Map<String, WatchTimeData> _videoWatchData = {};

  // Session tracking
  final Map<String, SessionData> _userSessions = {};

  // Creator performance tracking - removed unused field

  /// Track granular watch time for a video
  void trackWatchTime({
    required String videoId,
    required String creatorId,
    required double watchPercentage,
    required double totalDuration,
    required bool isReplay,
    required bool didComplete,
  }) {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    final watchData = _videoWatchData.putIfAbsent(
      videoId,
      () => WatchTimeData(
        videoId: videoId,
        creatorId: creatorId,
        totalWatches: 0,
        completions: 0,
        replays: 0,
        averageWatchPercentage: 0.0,
        watchSegments: {},
      ),
    );

    // Update watch data
    watchData.totalWatches++;
    if (didComplete) watchData.completions++;
    if (isReplay) watchData.replays++;

    // Calculate new average
    watchData.averageWatchPercentage =
        ((watchData.averageWatchPercentage * (watchData.totalWatches - 1)) +
                watchPercentage) /
            watchData.totalWatches;

    // Track which segment was watched
    final segment = _getWatchSegment(watchPercentage);
    watchData.watchSegments[segment] =
        (watchData.watchSegments[segment] ?? 0) + 1;

    secureLog(
        '📊 Watch time tracked: $videoId - ${watchPercentage.toStringAsFixed(1)}% (segment: $segment)');

    // Calculate engagement score
    final score = _calculateWatchTimeScore(watchData);

    // Save to Firestore asynchronously
    _saveWatchData(userId, videoId, watchData, score);
  }

  /// Get watch segment (0-25%, 25-50%, 50-75%, 75-100%)
  WatchSegment _getWatchSegment(double percentage) {
    if (percentage < 25) return WatchSegment.early;
    if (percentage < 50) return WatchSegment.mid;
    if (percentage < 75) return WatchSegment.late;
    return WatchSegment.complete;
  }

  /// Calculate engagement score based on watch time
  double _calculateWatchTimeScore(WatchTimeData data) {
    double score = 0.0;

    // Base score from average watch percentage
    score += data.averageWatchPercentage / 10; // 0-10 points

    // Completion bonus
    final completionRate =
        data.totalWatches > 0 ? data.completions / data.totalWatches : 0.0;
    score += completionRate * 15; // 0-15 points

    // Replay multiplier (exponential)
    if (data.replays > 0) {
      score *= (1.0 + (data.replays * 0.3)); // +30% per replay
    }

    // Segment distribution bonus (watched all segments = better)
    if (data.watchSegments.length == 4) {
      score *= 1.2; // 20% bonus for full engagement
    }

    return score.clamp(0.0, 100.0);
  }

  /// Save watch data to Firestore
  Future<void> _saveWatchData(
    String userId,
    String videoId,
    WatchTimeData data,
    double score,
  ) async {
    try {
      await _firestore.collection('engagement').doc('${userId}_$videoId').set({
        'userId': userId,
        'videoId': videoId,
        'creatorId': data.creatorId,
        'totalWatches': data.totalWatches,
        'completions': data.completions,
        'replays': data.replays,
        'averageWatchPercentage': data.averageWatchPercentage,
        'watchSegments': data.watchSegments.map((k, v) => MapEntry(k.name, v)),
        'engagementScore': score,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      secureLog(
          '✅ Watch data saved: $videoId - score: ${score.toStringAsFixed(2)}');
    } catch (e) {
      secureLog('❌ Error saving watch data: $e');
    }
  }

  /// Track user session for retention analysis
  void startSession() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    final session = SessionData(
      userId: userId,
      startTime: DateTime.now(),
      videosWatched: 0,
      engagementActions: 0,
      sessionDuration: Duration.zero,
    );

    _userSessions[userId] = session;
    secureLog('📱 Session started for user: $userId');
  }

  /// End user session and calculate retention signals
  Future<void> endSession() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    final session = _userSessions[userId];
    if (session == null) return;

    // Calculate session duration
    session.sessionDuration = DateTime.now().difference(session.startTime);

    // Calculate retention score
    final retentionScore = _calculateRetentionScore(session);

    // Save session data
    await _saveSessionData(session, retentionScore);
    if (session.sessionDuration.inSeconds >= 30 || session.videosWatched >= 2) {
      DailyActivityService.instance.maybeEmitDayQualified(
        source: 'home_session',
      );
    }

    secureLog(
        '📱 Session ended: ${session.sessionDuration.inMinutes}min, ${session.videosWatched} videos, score: $retentionScore');

    _userSessions.remove(userId);
  }

  /// Calculate retention score for session
  double _calculateRetentionScore(SessionData session) {
    double score = 0.0;

    // Session duration (0-30 points)
    final minutes = session.sessionDuration.inMinutes;
    score += (minutes / 60.0).clamp(0.0, 30.0);

    // Videos watched (0-25 points)
    score += (session.videosWatched * 2.5).clamp(0.0, 25.0);

    // Engagement actions (0-25 points)
    score += (session.engagementActions * 5.0).clamp(0.0, 25.0);

    // Time-to-first-action bonus (0-20 points)
    if (session.engagementActions > 0 && session.videosWatched > 0) {
      final actionsPerVideo = session.engagementActions / session.videosWatched;
      score += (actionsPerVideo * 10).clamp(0.0, 20.0);
    }

    return score.clamp(0.0, 100.0);
  }

  /// Save session data for retention analysis
  Future<void> _saveSessionData(
      SessionData session, double retentionScore) async {
    try {
      await _firestore.collection('user_sessions').add({
        'userId': session.userId,
        'startTime': Timestamp.fromDate(session.startTime),
        'endTime': FieldValue.serverTimestamp(),
        'sessionDuration': session.sessionDuration.inSeconds,
        'videosWatched': session.videosWatched,
        'engagementActions': session.engagementActions,
        'retentionScore': retentionScore,
      });

      secureLog('✅ Session saved with retention score: $retentionScore');
    } catch (e) {
      secureLog('❌ Error saving session data: $e');
    }
  }

  /// Increment video watch count for current session
  void incrementVideoWatch() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    final session = _userSessions[userId];
    if (session != null) {
      session.videosWatched++;
    }
  }

  /// Increment engagement action count for current session
  void incrementEngagementAction() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    final session = _userSessions[userId];
    if (session != null) {
      session.engagementActions++;
    }
  }
}

/// Watch time data model
class WatchTimeData {
  final String videoId;
  final String creatorId;
  int totalWatches;
  int completions;
  int replays;
  double averageWatchPercentage;
  Map<WatchSegment, int> watchSegments;

  WatchTimeData({
    required this.videoId,
    required this.creatorId,
    required this.totalWatches,
    required this.completions,
    required this.replays,
    required this.averageWatchPercentage,
    required this.watchSegments,
  });
}

/// Watch segment enum
enum WatchSegment {
  early, // 0-25%
  mid, // 25-50%
  late, // 50-75%
  complete, // 75-100%
}

/// Session data model
class SessionData {
  final String userId;
  final DateTime startTime;
  int videosWatched;
  int engagementActions;
  Duration sessionDuration;

  SessionData({
    required this.userId,
    required this.startTime,
    required this.videosWatched,
    required this.engagementActions,
    required this.sessionDuration,
  });
}

/// Creator metrics model
class CreatorMetrics {
  final String creatorId;
  int totalVideos;
  int totalViews;
  int totalEngagements;
  DateTime? lastUploadDate;
  double uploadConsistency; // 0-1 score
  double growthVelocity; // % follower growth per week

  CreatorMetrics({
    required this.creatorId,
    required this.totalVideos,
    required this.totalViews,
    required this.totalEngagements,
    this.lastUploadDate,
    this.uploadConsistency = 0.0,
    this.growthVelocity = 0.0,
  });
}
