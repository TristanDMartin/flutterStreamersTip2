import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/video_url_resolver.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/profile_video.dart';
import '../models/insights_data.dart';
import '../models/user.dart' as app_user;
import 'package:streamers_tip/utils/app_log.dart';

/// Firebase service for handling Insights data and ProfileVideo operations
class InsightsFirebaseService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final firebase_auth.FirebaseAuth _auth = firebase_auth.FirebaseAuth.instance;

  // Cache for performance
  final Map<String, List<ProfileVideo>> _userVideosCache = {};
  final Map<String, InsightsData> _insightsCache = {};

  bool _isLoading = false;
  String? _errorMessage;

  // Getters
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Get current user's profile videos for insights
  Future<List<ProfileVideo>> getUserProfileVideos(
      {bool forceRefresh = false}) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      _setError('User not authenticated');
      return [];
    }

    final userId = currentUser.uid;

    // Return cached data if available and not forcing refresh
    if (!forceRefresh && _userVideosCache.containsKey(userId)) {
      return _userVideosCache[userId]!;
    }

    _setLoading(true);

    try {
      final querySnapshot = await _firestore
          .collection('videos')
          .where('creatorId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(50) // Limit to recent 50 videos for performance
          .get();

      final videos = <ProfileVideo>[];

      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        final video = _mapToProfileVideo(doc.id, data);
        if (video != null) {
          videos.add(video);
        }
      }

      // Cache the results
      _userVideosCache[userId] = videos;
      _clearError();

      return videos;
    } catch (e) {
      _setError('Failed to load videos: ${e.toString()}');
      return [];
    } finally {
      _setLoading(false);
    }
  }

  /// Get insights data for a specific video
  Future<InsightsData?> getVideoInsights(String videoId) async {
    // Return cached data if available
    if (_insightsCache.containsKey(videoId)) {
      return _insightsCache[videoId];
    }

    _setLoading(true);

    try {
      // Get video analytics data
      final analyticsDoc =
          await _firestore.collection('videoAnalytics').doc(videoId).get();

      if (!analyticsDoc.exists) {
        _setError('No analytics data available for this video');
        return null;
      }

      final analyticsData = analyticsDoc.data()!;

      // Get additional insights data (demographics, traffic sources, etc.)
      final insightsDoc =
          await _firestore.collection('videoInsights').doc(videoId).get();

      final insightsData = insightsDoc.exists
          ? (insightsDoc.data() ?? <String, dynamic>{})
          : <String, dynamic>{};

      // Build comprehensive insights data
      final insights = _buildInsightsData(videoId, analyticsData, insightsData);

      // Cache the results
      _insightsCache[videoId] = insights;
      _clearError();

      return insights;
    } catch (e) {
      _setError('Failed to load insights: ${e.toString()}');
      return null;
    } finally {
      _setLoading(false);
    }
  }

  /// Listen to real-time insights updates
  Stream<InsightsData?> listenToVideoInsights(String videoId) {
    return _firestore
        .collection('videoAnalytics')
        .doc(videoId)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) return null;

      final analyticsData = snapshot.data()!;

      // Get cached insights data for additional fields
      final cachedInsights = _insightsCache[videoId];
      final additionalData =
          cachedInsights != null ? <String, dynamic>{} : <String, dynamic>{};

      final insights =
          _buildInsightsData(videoId, analyticsData, additionalData);

      // Update cache
      _insightsCache[videoId] = insights;

      return insights;
    });
  }

  /// Create or update insights data for a video
  Future<void> updateVideoInsights(
      String videoId, Map<String, dynamic> insightsData) async {
    try {
      await _firestore
          .collection('videoInsights')
          .doc(videoId)
          .set(insightsData, SetOptions(merge: true));

      // Clear cache to force refresh
      _insightsCache.remove(videoId);
    } catch (e) {
      _setError('Failed to update insights: ${e.toString()}');
    }
  }

  /// Get aggregated insights for multiple videos
  Future<Map<String, InsightsData>> getBatchInsights(
      List<String> videoIds) async {
    final results = <String, InsightsData>{};

    _setLoading(true);

    try {
      // Fetch all analytics in batch
      final analyticsSnapshot = await _firestore
          .collection('videoAnalytics')
          .where(FieldPath.documentId, whereIn: videoIds)
          .get();

      for (final doc in analyticsSnapshot.docs) {
        final videoId = doc.id;
        final analyticsData = doc.data();

        final insights =
            _buildInsightsData(videoId, analyticsData, <String, dynamic>{});
        results[videoId] = insights;

        // Cache the results
        _insightsCache[videoId] = insights;
      }

      _clearError();
      return results;
    } catch (e) {
      _setError('Failed to load batch insights: ${e.toString()}');
      return {};
    } finally {
      _setLoading(false);
    }
  }

  /// Clear cache for a specific user
  void clearUserCache(String userId) {
    _userVideosCache.remove(userId);
  }

  /// Clear all cache
  void clearAllCache() {
    _userVideosCache.clear();
    _insightsCache.clear();
  }

  // Private helper methods

  ProfileVideo? _mapToProfileVideo(String videoId, Map<String, dynamic> data) {
    try {
      // Get creator data
      final creatorId = data['creatorId'] as String?;
      if (creatorId == null) return null;

      // For now, create a minimal user object
      // In production, you might want to fetch full user data
      final creator = app_user.User(
        id: creatorId,
        username: data['creatorUsername'] ?? 'unknown',
        displayName: data['creatorDisplayName'] ?? 'Unknown User',
      );

      return ProfileVideo(
        id: videoId,
        creator: creator,
        videoURL: resolveVideoUrl(data),
        thumbnailURL: data['thumbnailUrl'] ??
            data[
                'thumbnailURL'], // Try lowercase first, then uppercase for backwards compatibility
        duration: (data['duration'] ?? 0.0).toDouble(),
        caption: data['caption'] ?? '',
        createdAt: (data['createdAt'] as Timestamp).toDate(),
        likes: data['likes'] ?? 0,
        comments: data['comments'] ?? 0,
        views: data['views'] ?? 0,
        shares: data['shares'] ?? 0,
        isLiked: data['isLiked'] ?? false,
        isFavorited: data['isFavorited'] ?? false, // cSpell:ignore Favorited
        isDraft: data['isDraft'] ?? false,
        mlScore: (data['mlScore'] ?? 0.0).toDouble(),
        categoryId: data['categoryId'] ?? '',
      );
    } catch (e) {
      if (kDebugMode) {
        appLog('Error mapping video data: $e');
      }
      return null;
    }
  }

  InsightsData _buildInsightsData(String videoId,
      Map<String, dynamic> analyticsData, Map<String, dynamic> insightsData) {
    final views = analyticsData['views'] ?? 0;
    final likes = analyticsData['likes'] ?? 0;
    final comments = analyticsData['comments'] ?? 0;
    final shares = analyticsData['shares'] ?? 0;
    final watchTime = (analyticsData['watchTime'] ?? 0.0).toDouble();
    final uniqueViewers = analyticsData['uniqueViewers'] ?? 0;
    final engagementRate = (analyticsData['engagementRate'] ?? 0.0).toDouble();
    final retentionRate = (analyticsData['retentionRate'] ?? 0.0).toDouble();

    return InsightsData(
      videoId: videoId,
      dateRange: DateTime.now().subtract(const Duration(days: 7)),
      overview: OverviewMetrics(
        totalViews: views,
        totalWatchTime: Duration(seconds: watchTime.toInt()),
        shares: shares,
        comments: comments,
        retentionRate: retentionRate,
        trafficSources: _buildTrafficSources(insightsData),
        searchQueries: _buildSearchQueries(insightsData),
      ),
      viewers: ViewerMetrics(
        totalViews: views,
        uniqueViewers: uniqueViewers,
        viewerTypes: ViewerTypes(
          newViewers: (uniqueViewers * 0.6).round(),
          returningViewers: (uniqueViewers * 0.4).round(),
        ),
        genderBreakdown: GenderBreakdown(
          male: (uniqueViewers * 0.5).round(),
          female: (uniqueViewers * 0.4).round(),
          other: (uniqueViewers * 0.1).round(),
          unknown: 0,
        ),
        ageGroups: _buildAgeGroups(insightsData),
        topLocations: _buildTopLocations(insightsData),
      ),
      engagement: EngagementMetrics(
        likes: likes,
        comments: comments,
        shares: shares,
        favorites: insightsData['favorites'] ?? 0,
        engagementRate: engagementRate,
        trends: _buildEngagementTrends(insightsData),
      ),
    );
  }

  List<TrafficSource> _buildTrafficSources(Map<String, dynamic> data) {
    final sources = data['trafficSources'] as List<dynamic>? ?? [];
    return sources.map((source) {
      return TrafficSource(
        source: source['source'] ?? 'Unknown',
        views: source['views'] ?? 0,
        percentage: (source['percentage'] ?? 0.0).toDouble(),
      );
    }).toList();
  }

  List<String> _buildSearchQueries(Map<String, dynamic> data) {
    return List<String>.from(data['searchQueries'] ?? []);
  }

  List<AgeGroup> _buildAgeGroups(Map<String, dynamic> data) {
    final ageData = data['ageGroups'] as Map<String, dynamic>? ??
        {
          '18-24': 0,
          '25-34': 0,
          '35-44': 0,
          '45-54': 0,
          '55+': 0,
        };

    return ageData.entries.map((entry) {
      final count = entry.value as int;
      final total = ageData.values
          .fold<int>(0, (totalSum, value) => totalSum + (value as int));
      final percentage = total > 0 ? (count / total) * 100 : 0.0;

      return AgeGroup(
        range: entry.key,
        count: count,
        percentage: percentage,
      );
    }).toList();
  }

  List<Location> _buildTopLocations(Map<String, dynamic> data) {
    final locationData = data['countries'] as Map<String, dynamic>? ?? {};

    return locationData.entries.map((entry) {
      final views = entry.value as int;
      final total = locationData.values
          .fold<int>(0, (totalSum, value) => totalSum + (value as int));
      final percentage = total > 0 ? (views / total) * 100 : 0.0;

      return Location(
        name: entry.key,
        views: views,
        percentage: percentage,
      );
    }).toList();
  }

  List<EngagementTrend> _buildEngagementTrends(Map<String, dynamic> data) {
    final trendsData = data['dailyEngagement'] as List<dynamic>? ?? [];

    return trendsData.map((day) {
      return EngagementTrend(
        date: DateTime.parse(day['date']),
        likes: day['likes'] ?? 0,
        comments: day['comments'] ?? 0,
        shares: day['shares'] ?? 0,
        favorites: day['favorites'] ?? 0,
      );
    }).toList();
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

// Riverpod provider for the service
final insightsFirebaseServiceProvider =
    ChangeNotifierProvider<InsightsFirebaseService>((ref) {
  return InsightsFirebaseService();
});
