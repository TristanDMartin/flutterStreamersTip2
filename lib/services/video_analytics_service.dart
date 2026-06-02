import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:streamers_tip/utils/swallow_non_fatal.dart';

class VideoAnalytics {
  final String videoId;
  final int views;
  final int likes;
  final int comments;
  final int shares;
  final double watchTime; // in seconds
  final double engagementRate;
  final double retentionRate;
  final int audienceReach;
  final int uniqueViewers;
  final double averageWatchTime;
  final double completionRate;
  final DateTime lastUpdated;

  VideoAnalytics({
    required this.videoId,
    required this.views,
    required this.likes,
    required this.comments,
    required this.shares,
    required this.watchTime,
    required this.engagementRate,
    required this.retentionRate,
    required this.audienceReach,
    required this.uniqueViewers,
    required this.averageWatchTime,
    required this.completionRate,
    required this.lastUpdated,
  });

  factory VideoAnalytics.fromMap(String videoId, Map<String, dynamic> data) {
    return VideoAnalytics(
      videoId: videoId,
      views: data['views'] ?? 0,
      likes: data['likes'] ?? 0,
      comments: data['comments'] ?? 0,
      shares: data['shares'] ?? 0,
      watchTime: (data['watchTime'] ?? 0.0).toDouble(),
      engagementRate: (data['engagementRate'] ?? 0.0).toDouble(),
      retentionRate: (data['retentionRate'] ?? 0.0).toDouble(),
      audienceReach: data['audienceReach'] ?? 0,
      uniqueViewers: data['uniqueViewers'] ?? 0,
      averageWatchTime: (data['averageWatchTime'] ?? 0.0).toDouble(),
      completionRate: (data['completionRate'] ?? 0.0).toDouble(),
      lastUpdated: data['lastUpdated'] is Timestamp
          ? (data['lastUpdated'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'videoId': videoId,
      'views': views,
      'likes': likes,
      'comments': comments,
      'shares': shares,
      'watchTime': watchTime,
      'engagementRate': engagementRate,
      'retentionRate': retentionRate,
      'audienceReach': audienceReach,
      'uniqueViewers': uniqueViewers,
      'averageWatchTime': averageWatchTime,
      'completionRate': completionRate,
      'lastUpdated': Timestamp.fromDate(lastUpdated),
    };
  }
}

class VideoAnalyticsService extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final Map<String, VideoAnalytics> _videoAnalytics = {};
  bool _isLoading = false;

  Map<String, VideoAnalytics> get videoAnalytics =>
      Map.unmodifiable(_videoAnalytics);
  bool get isLoading => _isLoading;

  Future<void> trackVideoView(String videoId, String? userId) async {
    final analyticsRef = _db.collection('videoAnalytics').doc(videoId);
    try {
      await _db.runTransaction((transaction) async {
        final analyticsDoc = await transaction.get(analyticsRef);
        Map<String, dynamic> newData = {};
        if (analyticsDoc.exists) {
          final data = analyticsDoc.data() ?? {};
          final currentViews = data['views'] ?? 0;
          final currentUniqueViewers = data['uniqueViewers'] ?? 0;
          final viewers = List<String>.from(data['viewers'] ?? []);
          newData = Map<String, dynamic>.from(data);
          newData['views'] = currentViews + 1;
          newData['lastUpdated'] = Timestamp.now();
          if (userId != null && !viewers.contains(userId)) {
            newData['uniqueViewers'] = currentUniqueViewers + 1;
            newData['viewers'] = [...viewers, userId];
          }
        } else {
          newData = {
            'videoId': videoId,
            'views': 1,
            'likes': 0,
            'comments': 0,
            'shares': 0,
            'watchTime': 0.0,
            'engagementRate': 0.0,
            'retentionRate': 0.0,
            'audienceReach': 0,
            'uniqueViewers': userId != null ? 1 : 0,
            'averageWatchTime': 0.0,
            'completionRate': 0.0,
            'viewers': userId != null ? [userId] : [],
            'lastUpdated': Timestamp.now(),
          };
        }
        transaction.set(analyticsRef, newData);
      });
      await fetchAnalytics(videoId);
    } catch (e, st) {
      swallowNonFatal('VideoAnalyticsService.trackVideoView', e, st);
    }
  }

  Future<void> trackVideoLike(String videoId, bool isLiked) async {
    final analyticsRef = _db.collection('videoAnalytics').doc(videoId);

    try {
      await _db.runTransaction((transaction) async {
        final analyticsDoc = await transaction.get(analyticsRef);

        Map<String, dynamic> newData = {};

        if (analyticsDoc.exists) {
          final data = analyticsDoc.data() ?? {};
          final currentLikes = data['likes'] ?? 0;

          newData = Map<String, dynamic>.from(data);
          newData['likes'] = isLiked
              ? currentLikes + 1
              : (currentLikes - 1).clamp(0, double.infinity).toInt();
          newData['lastUpdated'] = Timestamp.now();

          // Update engagement rate
          final views = data['views'] ?? 1;
          final newLikes = newData['likes'] ?? 0;
          final comments = data['comments'] ?? 0;
          final shares = data['shares'] ?? 0;

          final engagement = (newLikes + comments + shares) / views;
          newData['engagementRate'] = engagement;
        } else {
          // Create new analytics if doesn't exist
          newData = {
            'videoId': videoId,
            'views': 0,
            'likes': isLiked ? 1 : 0,
            'comments': 0,
            'shares': 0,
            'watchTime': 0.0,
            'engagementRate': 0.0,
            'retentionRate': 0.0,
            'audienceReach': 0,
            'uniqueViewers': 0,
            'averageWatchTime': 0.0,
            'completionRate': 0.0,
            'lastUpdated': Timestamp.now(),
          };
        }

        transaction.set(analyticsRef, newData);
      });

      // appLog('✅ Successfully tracked video like for video: $videoId');
      await fetchAnalytics(videoId);
    } catch (error) {
      // appLog('❌ Error tracking video like: $error');
    }
  }

  Future<void> trackVideoComment(String videoId) async {
    final analyticsRef = _db.collection('videoAnalytics').doc(videoId);

    try {
      await _db.runTransaction((transaction) async {
        final analyticsDoc = await transaction.get(analyticsRef);

        Map<String, dynamic> newData = {};

        if (analyticsDoc.exists) {
          final data = analyticsDoc.data() ?? {};
          final currentComments = data['comments'] ?? 0;

          newData = Map<String, dynamic>.from(data);
          newData['comments'] = currentComments + 1;
          newData['lastUpdated'] = Timestamp.now();

          // Update engagement rate
          final views = data['views'] ?? 1;
          final likes = data['likes'] ?? 0;
          final newComments = newData['comments'] ?? 0;
          final shares = data['shares'] ?? 0;

          final engagement = (likes + newComments + shares) / views;
          newData['engagementRate'] = engagement;
        } else {
          // Create new analytics if doesn't exist
          newData = {
            'videoId': videoId,
            'views': 0,
            'likes': 0,
            'comments': 1,
            'shares': 0,
            'watchTime': 0.0,
            'engagementRate': 0.0,
            'retentionRate': 0.0,
            'audienceReach': 0,
            'uniqueViewers': 0,
            'averageWatchTime': 0.0,
            'completionRate': 0.0,
            'lastUpdated': Timestamp.now(),
          };
        }

        transaction.set(analyticsRef, newData);
      });

      // appLog('✅ Successfully tracked video comment for video: $videoId');
      await fetchAnalytics(videoId);
    } catch (error) {
      // appLog('❌ Error tracking video comment: $error');
    }
  }

  Future<void> trackVideoShare(String videoId) async {
    final analyticsRef = _db.collection('videoAnalytics').doc(videoId);

    try {
      await _db.runTransaction((transaction) async {
        final analyticsDoc = await transaction.get(analyticsRef);

        Map<String, dynamic> newData = {};

        if (analyticsDoc.exists) {
          final data = analyticsDoc.data() ?? {};
          final currentShares = data['shares'] ?? 0;

          newData = Map<String, dynamic>.from(data);
          newData['shares'] = currentShares + 1;
          newData['lastUpdated'] = Timestamp.now();

          // Update engagement rate
          final views = data['views'] ?? 1;
          final likes = data['likes'] ?? 0;
          final comments = data['comments'] ?? 0;
          final newShares = newData['shares'] ?? 0;

          final engagement = (likes + comments + newShares) / views;
          newData['engagementRate'] = engagement;
        } else {
          // Create new analytics if doesn't exist
          newData = {
            'videoId': videoId,
            'views': 0,
            'likes': 0,
            'comments': 0,
            'shares': 1,
            'watchTime': 0.0,
            'engagementRate': 0.0,
            'retentionRate': 0.0,
            'audienceReach': 0,
            'uniqueViewers': 0,
            'averageWatchTime': 0.0,
            'completionRate': 0.0,
            'lastUpdated': Timestamp.now(),
          };
        }

        transaction.set(analyticsRef, newData);
      });

      // appLog('✅ Successfully tracked video share for video: $videoId');
      await fetchAnalytics(videoId);
    } catch (error) {
      // appLog('❌ Error tracking video share: $error');
    }
  }

  Future<void> trackWatchTime(String videoId, double watchTime) async {
    final analyticsRef = _db.collection('videoAnalytics').doc(videoId);

    try {
      await _db.runTransaction((transaction) async {
        final analyticsDoc = await transaction.get(analyticsRef);

        Map<String, dynamic> newData = {};

        if (analyticsDoc.exists) {
          final data = analyticsDoc.data() ?? {};
          final currentWatchTime = (data['watchTime'] ?? 0.0).toDouble();
          final currentViews = data['views'] ?? 1;

          newData = Map<String, dynamic>.from(data);
          newData['watchTime'] = currentWatchTime + watchTime;
          newData['averageWatchTime'] =
              (currentWatchTime + watchTime) / currentViews;
          newData['lastUpdated'] = Timestamp.now();
        } else {
          // Create new analytics if doesn't exist
          newData = {
            'videoId': videoId,
            'views': 0,
            'likes': 0,
            'comments': 0,
            'shares': 0,
            'watchTime': watchTime,
            'engagementRate': 0.0,
            'retentionRate': 0.0,
            'audienceReach': 0,
            'uniqueViewers': 0,
            'averageWatchTime': watchTime,
            'completionRate': 0.0,
            'lastUpdated': Timestamp.now(),
          };
        }

        transaction.set(analyticsRef, newData);
      });

      // appLog('✅ Successfully tracked watch time for video: $videoId');
      await fetchAnalytics(videoId);
    } catch (error) {
      // appLog('❌ Error tracking watch time: $error');
    }
  }

  // MARK: - Analytics Fetching

  Future<void> fetchAnalytics(String videoId) async {
    _isLoading = true;
    notifyListeners();

    try {
      final document =
          await _db.collection('videoAnalytics').doc(videoId).get();

      if (document.exists && document.data() != null) {
        final analytics = VideoAnalytics.fromMap(videoId, document.data()!);
        _videoAnalytics[videoId] = analytics;
        // appLog('✅ Successfully fetched analytics for video: $videoId');
      } else {
        // appLog('📊 No analytics data found for video: $videoId');
      }
    } catch (error) {
      // appLog('❌ Error fetching analytics for video $videoId: $error');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchAnalyticsForVideos(List<String> videoIds) async {
    _isLoading = true;
    notifyListeners();

    try {
      for (final videoId in videoIds) {
        await fetchAnalytics(videoId);
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // MARK: - Real-time Listeners

  StreamSubscription<DocumentSnapshot>? _analyticsListener;

  void startListeningToAnalytics(String videoId) {
    _analyticsListener?.cancel();

    _analyticsListener =
        _db.collection('videoAnalytics').doc(videoId).snapshots().listen(
      (documentSnapshot) {
        if (documentSnapshot.exists && documentSnapshot.data() != null) {
          final analytics =
              VideoAnalytics.fromMap(videoId, documentSnapshot.data()!);
          _videoAnalytics[videoId] = analytics;
          // appLog('🔄 Real-time analytics update for video: $videoId');
          notifyListeners();
        }
      },
      onError: (error) {
        // appLog('❌ Error listening to analytics for video $videoId: $error');
      },
    );
  }

  void stopListeningToAnalytics() {
    _analyticsListener?.cancel();
    _analyticsListener = null;
  }

  // MARK: - Cleanup

  @override
  void dispose() {
    stopListeningToAnalytics();
    super.dispose();
  }
}
