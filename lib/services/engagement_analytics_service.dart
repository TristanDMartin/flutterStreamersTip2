import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

enum EngagementEvent {
  videoView,
  videoComplete,
  videoSkip,
  like,
  unlike,
  favorite,
  unfavorite,
  share,
  comment,
  profileView,
  follow,
  unfollow,
}

class EngagementData {
  final String videoId;
  final String userId;
  final EngagementEvent event;
  final DateTime timestamp;
  final Map<String, dynamic> metadata;
  final double engagementScore;

  EngagementData({
    required this.videoId,
    required this.userId,
    required this.event,
    required this.timestamp,
    this.metadata = const {},
    required this.engagementScore,
  });

  Map<String, dynamic> toJson() => {
    'videoId': videoId,
    'userId': userId,
    'event': event.name,
    'timestamp': timestamp.toIso8601String(),
    'metadata': metadata,
    'engagementScore': engagementScore,
  };
}

class MLScoreUpdate {
  final String videoId;
  final double newScore;
  final String reason;
  final DateTime timestamp;

  MLScoreUpdate({
    required this.videoId,
    required this.newScore,
    required this.reason,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'videoId': videoId,
    'newScore': newScore,
    'reason': reason,
    'timestamp': timestamp.toIso8601String(),
  };
}

class EngagementAnalyticsService {
  static final EngagementAnalyticsService _instance = EngagementAnalyticsService._internal();
  factory EngagementAnalyticsService() => _instance;
  EngagementAnalyticsService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Engagement tracking
  final List<EngagementData> _pendingEngagements = [];
  final Map<String, double> _videoEngagementScores = {};
  final Map<String, List<EngagementData>> _userEngagementHistory = {};

  // ML Score tracking
  final Map<String, double> _mlScores = {};
  final List<MLScoreUpdate> _mlScoreUpdates = [];

  // Performance tracking
  Timer? _analyticsTimer;
  Timer? _mlUpdateTimer;

  // Engagement weights for different events
  static const Map<EngagementEvent, double> _engagementWeights = {
    EngagementEvent.videoView: 1.0,
    EngagementEvent.videoComplete: 5.0,
    EngagementEvent.videoSkip: -0.5,
    EngagementEvent.like: 3.0,
    EngagementEvent.unlike: -1.0,
    EngagementEvent.favorite: 4.0,
    EngagementEvent.unfavorite: -1.5,
    EngagementEvent.share: 6.0,
    EngagementEvent.comment: 8.0,
    EngagementEvent.profileView: 2.0,
    EngagementEvent.follow: 5.0,
    EngagementEvent.unfollow: -2.0,
  };

  void initialize() {
    debugPrint('📊 EngagementAnalyticsService initialized');
    _startAnalyticsTimer();
    _startMLUpdateTimer();
    _loadCachedData();
  }

  void dispose() {
    _analyticsTimer?.cancel();
    _mlUpdateTimer?.cancel();
    _syncPendingData();
    debugPrint('📊 EngagementAnalyticsService disposed');
  }

  /// Track a user engagement event
  Future<void> trackEngagement({
    required String videoId,
    required EngagementEvent event,
    Map<String, dynamic> metadata = const {},
  }) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      final engagementData = EngagementData(
        videoId: videoId,
        userId: userId,
        event: event,
        timestamp: DateTime.now(),
        metadata: metadata,
        engagementScore: _calculateEngagementScore(event, metadata),
      );

      // Add to pending engagements
      _pendingEngagements.add(engagementData);

      // Update local engagement scores
      _updateLocalEngagementScore(videoId, engagementData.engagementScore);

      // Update user engagement history
      _userEngagementHistory.putIfAbsent(userId, () => []).add(engagementData);

      // Trigger ML score update if significant event
      if (_isSignificantEvent(event)) {
        await _updateMLScore(videoId);
      }

      debugPrint('📊 Tracked engagement: ${event.name} for video $videoId (score: ${engagementData.engagementScore})');
    } catch (e) {
      debugPrint('❌ Error tracking engagement: $e');
    }
  }

  /// Calculate engagement score for an event
  double _calculateEngagementScore(EngagementEvent event, Map<String, dynamic> metadata) {
    double baseScore = _engagementWeights[event] ?? 0.0;
    
    // Apply multipliers based on metadata
    if (metadata.containsKey('watchTime')) {
      final watchTime = metadata['watchTime'] as double? ?? 0.0;
      if (watchTime > 0.8) {
        baseScore *= 1.5; // High completion rate
      } else if (watchTime < 0.2) baseScore *= 0.5; // Low completion rate
    }

    if (metadata.containsKey('isReplay')) {
      baseScore *= 1.2; // Replay indicates high interest
    }

    if (metadata.containsKey('timeOfDay')) {
      final hour = DateTime.now().hour;
      if (hour >= 19 && hour <= 23) baseScore *= 1.1; // Prime time
    }

    return baseScore;
  }

  /// Check if event should trigger ML score update
  bool _isSignificantEvent(EngagementEvent event) {
    return [
      EngagementEvent.videoComplete,
      EngagementEvent.like,
      EngagementEvent.favorite,
      EngagementEvent.share,
      EngagementEvent.comment,
    ].contains(event);
  }

  /// Update local engagement score
  void _updateLocalEngagementScore(String videoId, double score) {
    _videoEngagementScores.update(
      videoId,
      (existing) => existing + score,
      ifAbsent: () => score,
    );
  }

  /// Update ML score for a video
  Future<void> _updateMLScore(String videoId) async {
    try {
      final currentScore = _mlScores[videoId] ?? 0.5;
      final engagementScore = _videoEngagementScores[videoId] ?? 0.0;
      
      // Calculate new ML score using weighted average
      final newScore = _calculateNewMLScore(currentScore, engagementScore);
      
      if ((newScore - currentScore).abs() > 0.05) { // Only update if significant change
        _mlScores[videoId] = newScore;
        
        final update = MLScoreUpdate(
          videoId: videoId,
          newScore: newScore,
          reason: 'Engagement-based update',
          timestamp: DateTime.now(),
        );
        
        _mlScoreUpdates.add(update);
        
        // Update in Firestore
        await _firestore.collection('videos').doc(videoId).update({
          'mlScore': newScore,
          'lastMLUpdate': FieldValue.serverTimestamp(),
        });
        
        debugPrint('📊 Updated ML score for $videoId: $currentScore -> $newScore');
      }
    } catch (e) {
      debugPrint('❌ Error updating ML score: $e');
    }
  }

  /// Calculate new ML score based on engagement
  double _calculateNewMLScore(double currentScore, double engagementScore) {
    // Normalize engagement score to 0-1 range
    final normalizedEngagement = (engagementScore / 100).clamp(0.0, 1.0);
    
    // Weighted average: 70% current score, 30% new engagement
    final newScore = (currentScore * 0.7) + (normalizedEngagement * 0.3);
    
    return newScore.clamp(0.0, 1.0);
  }

  /// Get current ML score for a video
  double getMLScore(String videoId) {
    return _mlScores[videoId] ?? 0.5;
  }

  /// Get engagement score for a video
  double getEngagementScore(String videoId) {
    return _videoEngagementScores[videoId] ?? 0.0;
  }

  /// Get user engagement history
  List<EngagementData> getUserEngagementHistory(String userId) {
    return _userEngagementHistory[userId] ?? [];
  }

  /// Get top performing videos by engagement
  List<String> getTopPerformingVideos({int limit = 10}) {
    final sortedVideos = _videoEngagementScores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    return sortedVideos.take(limit).map((e) => e.key).toList();
  }

  /// Get ML score updates
  List<MLScoreUpdate> getMLScoreUpdates() {
    return List.from(_mlScoreUpdates);
  }

  /// Start analytics timer for batch processing
  void _startAnalyticsTimer() {
    _analyticsTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      _syncPendingData();
    });
  }

  /// Start ML update timer
  void _startMLUpdateTimer() {
    _mlUpdateTimer = Timer.periodic(const Duration(minutes: 10), (timer) {
      _processMLUpdates();
    });
  }

  /// Sync pending engagement data to Firestore
  Future<void> _syncPendingData() async {
    if (_pendingEngagements.isEmpty) return;

    try {
      final batch = _firestore.batch();
      
      for (final engagement in _pendingEngagements) {
        final docRef = _firestore
            .collection('engagement_analytics')
            .doc('${engagement.userId}_${engagement.videoId}_${engagement.timestamp.millisecondsSinceEpoch}');
        
        batch.set(docRef, engagement.toJson());
      }
      
      await batch.commit();
      _pendingEngagements.clear();
      
      debugPrint('📊 Synced ${_pendingEngagements.length} engagement events');
    } catch (e) {
      debugPrint('❌ Error syncing engagement data: $e');
    }
  }

  /// Process ML score updates
  Future<void> _processMLUpdates() async {
    if (_mlScoreUpdates.isEmpty) return;

    try {
      final batch = _firestore.batch();
      
      for (final update in _mlScoreUpdates) {
        final docRef = _firestore
            .collection('ml_score_updates')
            .doc('${update.videoId}_${update.timestamp.millisecondsSinceEpoch}');
        
        batch.set(docRef, update.toJson());
      }
      
      await batch.commit();
      _mlScoreUpdates.clear();
      
      debugPrint('📊 Synced ${_mlScoreUpdates.length} ML score updates');
    } catch (e) {
      debugPrint('❌ Error syncing ML updates: $e');
    }
  }

  /// Load cached data from Firestore
  Future<void> _loadCachedData() async {
    try {
      // Load recent engagement scores
      final engagementSnapshot = await _firestore
          .collection('engagement_analytics')
          .where('timestamp', isGreaterThan: DateTime.now().subtract(const Duration(days: 7)))
          .limit(1000)
          .get();

      for (final doc in engagementSnapshot.docs) {
        final data = doc.data();
        final videoId = data['videoId'] as String? ?? '';
        final score = (data['engagementScore'] as num?)?.toDouble() ?? 0.0;
        
        if (videoId.isNotEmpty) {
          _updateLocalEngagementScore(videoId, score);
        }
      }

      // Load ML scores
      final mlSnapshot = await _firestore
          .collection('videos')
          .where('mlScore', isNull: false)
          .limit(500)
          .get();

      for (final doc in mlSnapshot.docs) {
        final videoId = doc.id;
        final mlScore = (doc.data()['mlScore'] as num?)?.toDouble() ?? 0.5;
        _mlScores[videoId] = mlScore;
      }

      debugPrint('📊 Loaded cached analytics data');
    } catch (e) {
      debugPrint('❌ Error loading cached data: $e');
    }
  }

  /// Generate analytics report
  Map<String, dynamic> generateAnalyticsReport() {
    final totalEngagements = _pendingEngagements.length;
    final totalVideos = _videoEngagementScores.length;
    final avgMLScore = _mlScores.values.isNotEmpty 
        ? _mlScores.values.reduce((a, b) => a + b) / _mlScores.length 
        : 0.5;

    return {
      'totalEngagements': totalEngagements,
      'totalVideos': totalVideos,
      'averageMLScore': avgMLScore,
      'topPerformingVideos': getTopPerformingVideos(limit: 5),
      'recentMLUpdates': _mlScoreUpdates.take(10).map((u) => u.toJson()).toList(),
    };
  }
}
