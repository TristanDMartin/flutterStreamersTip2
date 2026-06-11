import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/video_url_resolver.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/profile_video.dart';
import '../models/insights_data.dart';
import '../models/user.dart' as app_user;
import '../utils/insights_metrics.dart';
import 'package:streamers_tip/utils/app_log.dart';

class CreatorInsightsSnapshot {
  const CreatorInsightsSnapshot({
    required this.insights,
    required this.video,
    required this.lastUpdated,
    required this.isLive,
  });

  final InsightsData insights;
  final ProfileVideo video;
  final DateTime lastUpdated;
  final bool isLive;
}

/// Firebase-backed creator video insights — videos doc is source of truth for counters.
class InsightsFirebaseService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final firebase_auth.FirebaseAuth _auth = firebase_auth.FirebaseAuth.instance;

  final Map<String, List<ProfileVideo>> _userVideosCache = {};
  final Map<String, InsightsData> _insightsCache = {};
  final Map<String, Map<String, dynamic>> _videoInsightsRawCache = {};

  bool _isLoading = false;
  String? _errorMessage;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<List<ProfileVideo>> getUserProfileVideos({
    bool forceRefresh = false,
  }) async {
    final firebase_auth.User? currentUser = _auth.currentUser;
    if (currentUser == null) {
      _setError('User not authenticated');
      return <ProfileVideo>[];
    }
    final String userId = currentUser.uid;
    if (!forceRefresh && _userVideosCache.containsKey(userId)) {
      return _userVideosCache[userId]!;
    }
    _setLoading(true);
    try {
      final QuerySnapshot<Map<String, dynamic>> querySnapshot = await _firestore
          .collection('videos')
          .where('creatorId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get();
      final List<ProfileVideo> videos = <ProfileVideo>[];
      for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
          in querySnapshot.docs) {
        final ProfileVideo? video = _mapToProfileVideo(doc.id, doc.data());
        if (video != null) {
          videos.add(video);
        }
      }
      _userVideosCache[userId] = videos;
      _clearError();
      return videos;
    } catch (e) {
      _setError('Failed to load videos: ${e.toString()}');
      return <ProfileVideo>[];
    } finally {
      _setLoading(false);
    }
  }

  Future<ProfileVideo?> getProfileVideo(String videoId) async {
    final DocumentSnapshot<Map<String, dynamic>> doc =
        await _firestore.collection('videos').doc(videoId).get();
    if (!doc.exists) {
      return null;
    }
    return _mapToProfileVideo(doc.id, doc.data() ?? <String, dynamic>{});
  }

  Future<void> assertCurrentUserOwnsVideo(String videoId) async {
    final firebase_auth.User? user = _auth.currentUser;
    if (user == null) {
      throw StateError('You must be signed in to view insights.');
    }
    final DocumentSnapshot<Map<String, dynamic>> doc =
        await _firestore.collection('videos').doc(videoId).get();
    if (!doc.exists) {
      throw StateError('Video not found.');
    }
    final Map<String, dynamic> data = doc.data() ?? <String, dynamic>{};
    final String? creatorId = data['creatorId'] as String? ??
        data['userId'] as String? ??
        data['uid'] as String?;
    if (creatorId != user.uid) {
      throw StateError('You can only view insights for your own videos.');
    }
  }

  Future<CreatorInsightsSnapshot?> getCreatorInsights({
    required String videoId,
    required int analyticsWindowDays,
  }) async {
    await assertCurrentUserOwnsVideo(videoId);
    final ProfileVideo? video = await getProfileVideo(videoId);
    if (video == null) {
      return null;
    }
    final DocumentSnapshot<Map<String, dynamic>> analyticsDoc =
        await _firestore.collection('videoAnalytics').doc(videoId).get();
    final DocumentSnapshot<Map<String, dynamic>> insightsDoc =
        await _firestore.collection('videoInsights').doc(videoId).get();
    final Map<String, dynamic> videoData =
        (await _firestore.collection('videos').doc(videoId).get()).data() ??
            <String, dynamic>{};
    final Map<String, dynamic> insightsRaw = insightsDoc.exists
        ? (insightsDoc.data() ?? <String, dynamic>{})
        : <String, dynamic>{};
    _videoInsightsRawCache[videoId] = insightsRaw;
    final InsightsData insights = _buildInsightsData(
      videoId: videoId,
      videoData: videoData,
      analyticsData: analyticsDoc.data(),
      insightsData: insightsRaw,
      analyticsWindowDays: analyticsWindowDays,
    );
    _insightsCache[videoId] = insights;
    return CreatorInsightsSnapshot(
      insights: insights,
      video: video,
      lastUpdated: DateTime.now(),
      isLive: true,
    );
  }

  Stream<CreatorInsightsSnapshot?> watchCreatorInsights({
    required String videoId,
    required int analyticsWindowDays,
  }) {
    return _firestore.collection('videos').doc(videoId).snapshots().asyncMap(
      (DocumentSnapshot<Map<String, dynamic>> videoSnapshot) async {
        if (!videoSnapshot.exists) {
          return null;
        }
        try {
          await assertCurrentUserOwnsVideo(videoId);
        } catch (_) {
          return null;
        }
        final Map<String, dynamic> videoData =
            videoSnapshot.data() ?? <String, dynamic>{};
        final ProfileVideo? video = _mapToProfileVideo(videoId, videoData);
        if (video == null) {
          return null;
        }
        final DocumentSnapshot<Map<String, dynamic>> analyticsDoc =
            await _firestore.collection('videoAnalytics').doc(videoId).get();
        final DocumentSnapshot<Map<String, dynamic>> insightsDoc =
            await _firestore.collection('videoInsights').doc(videoId).get();
        final Map<String, dynamic> insightsRaw = insightsDoc.exists
            ? (insightsDoc.data() ?? <String, dynamic>{})
            : _videoInsightsRawCache[videoId] ?? <String, dynamic>{};
        _videoInsightsRawCache[videoId] = insightsRaw;
        final InsightsData insights = _buildInsightsData(
          videoId: videoId,
          videoData: videoData,
          analyticsData: analyticsDoc.data(),
          insightsData: insightsRaw,
          analyticsWindowDays: analyticsWindowDays,
        );
        _insightsCache[videoId] = insights;
        return CreatorInsightsSnapshot(
          insights: insights,
          video: video,
          lastUpdated: DateTime.now(),
          isLive: true,
        );
      },
    );
  }

  Future<InsightsData?> getVideoInsights(String videoId) async {
    final CreatorInsightsSnapshot? snapshot = await getCreatorInsights(
      videoId: videoId,
      analyticsWindowDays: 7,
    );
    return snapshot?.insights;
  }

  Stream<InsightsData?> listenToVideoInsights(String videoId) {
    return watchCreatorInsights(videoId: videoId, analyticsWindowDays: 7)
        .map((CreatorInsightsSnapshot? value) => value?.insights);
  }

  Future<void> updateVideoInsights(
    String videoId,
    Map<String, dynamic> insightsData,
  ) async {
    try {
      await _firestore
          .collection('videoInsights')
          .doc(videoId)
          .set(insightsData, SetOptions(merge: true));
      _insightsCache.remove(videoId);
      _videoInsightsRawCache.remove(videoId);
    } catch (e) {
      _setError('Failed to update insights: ${e.toString()}');
    }
  }

  Future<Map<String, InsightsData>> getBatchInsights(
    List<String> videoIds,
  ) async {
    final Map<String, InsightsData> results = <String, InsightsData>{};
    _setLoading(true);
    try {
      for (final String videoId in videoIds) {
        final CreatorInsightsSnapshot? snapshot = await getCreatorInsights(
          videoId: videoId,
          analyticsWindowDays: 7,
        );
        if (snapshot != null) {
          results[videoId] = snapshot.insights;
        }
      }
      _clearError();
      return results;
    } catch (e) {
      _setError('Failed to load batch insights: ${e.toString()}');
      return <String, InsightsData>{};
    } finally {
      _setLoading(false);
    }
  }

  void clearUserCache(String userId) {
    _userVideosCache.remove(userId);
  }

  void clearAllCache() {
    _userVideosCache.clear();
    _insightsCache.clear();
    _videoInsightsRawCache.clear();
  }

  ProfileVideo? _mapToProfileVideo(
    String videoId,
    Map<String, dynamic> data,
  ) {
    try {
      final String? creatorId = data['creatorId'] as String?;
      if (creatorId == null) {
        return null;
      }
      final Timestamp? createdAtRaw = data['createdAt'] as Timestamp?;
      if (createdAtRaw == null) {
        return null;
      }
      final app_user.User creator = app_user.User(
        id: creatorId,
        username: data['creatorUsername'] ?? 'unknown',
        displayName: data['creatorDisplayName'] ?? 'Unknown User',
      );
      return ProfileVideo(
        id: videoId,
        creator: creator,
        videoURL: resolveVideoUrl(data),
        thumbnailURL: data['thumbnailUrl'] ?? data['thumbnailURL'],
        duration: (data['duration'] ?? 0.0).toDouble(),
        caption: data['caption'] ?? '',
        createdAt: createdAtRaw.toDate(),
        likes: _readInt(data['likes']),
        comments: _readInt(data['comments']),
        views: _readInt(data['views']),
        shares: _readInt(data['shares']),
        isLiked: data['isLiked'] == true,
        isFavorited: data['isFavorited'] == true,
        isDraft: data['isDraft'] == true,
        mlScore: (data['mlScore'] ?? 0.0).toDouble(),
        categoryId: data['categoryId']?.toString() ?? '',
      );
    } catch (e) {
      if (kDebugMode) {
        appLog('Error mapping video data: $e');
      }
      return null;
    }
  }

  InsightsData _buildInsightsData({
    required String videoId,
    required Map<String, dynamic> videoData,
    required Map<String, dynamic>? analyticsData,
    required Map<String, dynamic> insightsData,
    required int analyticsWindowDays,
  }) {
    final Map<String, dynamic> analytics =
        analyticsData ?? <String, dynamic>{};
    final int views = _readInt(analytics['views'], fallback: _readInt(videoData['views']));
    final int likes = _readInt(analytics['likes'], fallback: _readInt(videoData['likes']));
    final int comments =
        _readInt(analytics['comments'], fallback: _readInt(videoData['comments']));
    final int shares =
        _readInt(analytics['shares'], fallback: _readInt(videoData['shares']));
    final int bookmarks = _readInt(
      analytics['favorites'] ?? analytics['bookmarks'],
      fallback: _readInt(videoData['bookmarks'] ?? videoData['favorites']),
    );
    final double watchTime =
        _readDouble(analytics['watchTime'] ?? analytics['totalWatchTime']);
    final int uniqueViewers = _readInt(analytics['uniqueViewers']);
    final double retentionRate = _readDouble(analytics['retentionRate']);
    final double engagementRate = views > 0
        ? InsightsMetrics.engagementRatePercent(
            views: views,
            likes: likes,
            comments: comments,
            shares: shares,
            bookmarks: bookmarks,
          ) / 100
        : _readDouble(analytics['engagementRate']);
    final int windowDays = analyticsWindowDays < 7 ? 7 : analyticsWindowDays;
    return InsightsData(
      videoId: videoId,
      dateRange: DateTime.now().subtract(Duration(days: windowDays)),
      overview: OverviewMetrics(
        totalViews: views,
        totalWatchTime: Duration(seconds: watchTime.round()),
        shares: shares,
        comments: comments,
        retentionRate: retentionRate.clamp(0.0, 1.0),
        trafficSources: _buildTrafficSources(insightsData),
        searchQueries: _buildSearchQueries(insightsData),
      ),
      viewers: ViewerMetrics(
        totalViews: views,
        uniqueViewers: uniqueViewers,
        viewerTypes: _buildViewerTypes(insightsData),
        genderBreakdown: _buildGenderBreakdown(insightsData),
        ageGroups: _buildAgeGroups(insightsData),
        topLocations: _buildTopLocations(insightsData),
      ),
      engagement: EngagementMetrics(
        likes: likes,
        comments: comments,
        shares: shares,
        favorites: bookmarks,
        engagementRate: engagementRate,
        trends: _buildEngagementTrends(insightsData),
      ),
    );
  }

  ViewerTypes _buildViewerTypes(Map<String, dynamic> data) {
    final Map<String, dynamic>? raw =
        data['viewerTypes'] is Map<String, dynamic>
            ? data['viewerTypes'] as Map<String, dynamic>
            : null;
    return ViewerTypes(
      newViewers: _readInt(raw?['newViewers'] ?? data['newViewers']),
      returningViewers:
          _readInt(raw?['returningViewers'] ?? data['returningViewers']),
    );
  }

  GenderBreakdown _buildGenderBreakdown(Map<String, dynamic> data) {
    final Map<String, dynamic>? raw =
        data['genderBreakdown'] is Map<String, dynamic>
            ? data['genderBreakdown'] as Map<String, dynamic>
            : data['gender'] is Map<String, dynamic>
                ? data['gender'] as Map<String, dynamic>
                : null;
    return GenderBreakdown(
      male: _readInt(raw?['male']),
      female: _readInt(raw?['female']),
      other: _readInt(raw?['other']),
      unknown: _readInt(raw?['unknown']),
    );
  }

  List<TrafficSource> _buildTrafficSources(Map<String, dynamic> data) {
    final List<dynamic> sources = data['trafficSources'] as List<dynamic>? ?? [];
    return sources
        .whereType<Map<String, dynamic>>()
        .map(
          (Map<String, dynamic> source) => TrafficSource(
            source: source['source']?.toString() ?? 'Unknown',
            views: _readInt(source['views']),
            percentage: _readDouble(source['percentage']),
          ),
        )
        .where((TrafficSource source) => source.views > 0)
        .toList();
  }

  List<String> _buildSearchQueries(Map<String, dynamic> data) {
    return List<String>.from(data['searchQueries'] ?? <dynamic>[]);
  }

  List<AgeGroup> _buildAgeGroups(Map<String, dynamic> data) {
    final Object? raw = data['ageGroups'];
    if (raw is! Map) {
      return const <AgeGroup>[];
    }
    final Map<String, dynamic> ageData = Map<String, dynamic>.from(raw);
    final int total = ageData.values.fold<int>(
      0,
      (int sum, dynamic value) => sum + _readInt(value),
    );
    if (total <= 0) {
      return const <AgeGroup>[];
    }
    return ageData.entries
        .map((MapEntry<String, dynamic> entry) {
          final int count = _readInt(entry.value);
          return AgeGroup(
            range: entry.key,
            count: count,
            percentage: total > 0 ? (count / total) * 100 : 0,
          );
        })
        .where((AgeGroup group) => group.count > 0)
        .toList();
  }

  List<Location> _buildTopLocations(Map<String, dynamic> data) {
    final Object? raw = data['countries'] ?? data['topLocations'];
    if (raw is! Map) {
      return const <Location>[];
    }
    final Map<String, dynamic> locationData = Map<String, dynamic>.from(raw);
    final int total = locationData.values.fold<int>(
      0,
      (int sum, dynamic value) => sum + _readInt(value),
    );
    if (total <= 0) {
      return const <Location>[];
    }
    return locationData.entries
        .map((MapEntry<String, dynamic> entry) {
          final int views = _readInt(entry.value);
          return Location(
            name: entry.key,
            views: views,
            percentage: total > 0 ? (views / total) * 100 : 0,
          );
        })
        .where((Location location) => location.views > 0)
        .toList();
  }

  List<EngagementTrend> _buildEngagementTrends(Map<String, dynamic> data) {
    final List<dynamic> trendsData =
        data['dailyEngagement'] as List<dynamic>? ?? <dynamic>[];
    return trendsData
        .whereType<Map<String, dynamic>>()
        .map(
          (Map<String, dynamic> day) => EngagementTrend(
            date: DateTime.tryParse(day['date']?.toString() ?? '') ??
                DateTime.now(),
            likes: _readInt(day['likes']),
            comments: _readInt(day['comments']),
            shares: _readInt(day['shares']),
            favorites: _readInt(day['favorites']),
          ),
        )
        .toList();
  }

  int _readInt(Object? value, {int fallback = 0}) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.round();
    }
    if (value is String) {
      return int.tryParse(value) ?? fallback;
    }
    return fallback;
  }

  double _readDouble(Object? value, {double fallback = 0}) {
    if (value is double) {
      return value;
    }
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value) ?? fallback;
    }
    return fallback;
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _errorMessage = error;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}

final ChangeNotifierProvider<InsightsFirebaseService>
    insightsFirebaseServiceProvider =
    ChangeNotifierProvider<InsightsFirebaseService>((Ref ref) {
  return InsightsFirebaseService();
});
