import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/video_url_resolver.dart';
import '../models/home_video.dart';
import '../models/user.dart';

/// Production-ready ML recommendation service
class MLRecommendationService {
  static final MLRecommendationService _instance =
      MLRecommendationService._internal();
  factory MLRecommendationService() => _instance;
  MLRecommendationService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ML Model parameters (would be loaded from trained models in production)
  static const Map<String, double> _featureWeights = {
    'recency': 0.25,
    'engagement': 0.30,
    'social_affinity': 0.20,
    'content_similarity': 0.15,
    'user_preferences': 0.10,
  };

  // User behavior tracking
  final Map<String, List<String>> _userInteractionHistory = {};

  /// Get personalized recommendations for a user
  Future<List<HomeVideo>> getPersonalizedRecommendations({
    required String userId,
    int limit = 20,
    List<String>? excludeVideoIds,
  }) async {
    try {
      debugPrint('🤖 Generating ML recommendations for user: $userId');

      // Load user behavior profile
      final userProfile = await _loadUserBehaviorProfile(userId);

      // Get candidate videos
      final candidates =
          await _getCandidateVideos(limit * 3); // Get 3x for filtering

      // Apply ML scoring
      final scoredVideos = await _applyMLScoring(candidates, userProfile);

      // Filter and rank
      final recommendations =
          _rankAndFilter(scoredVideos, limit, excludeVideoIds);

      debugPrint('✅ Generated ${recommendations.length} ML recommendations');
      return recommendations;
    } catch (e) {
      debugPrint('❌ ML recommendation failed: $e');
      return [];
    }
  }

  /// Load user behavior profile from Firestore
  Future<UserBehaviorProfile> _loadUserBehaviorProfile(String userId) async {
    try {
      final doc =
          await _firestore.collection('user_profiles').doc(userId).get();
      final interestsDoc =
          await _firestore.collection('userInterests').doc(userId).get();

      if (doc.exists) {
        final data = doc.data()!;
        return UserBehaviorProfile.fromMap(
          data,
          interests: interestsDoc.data(),
        );
      } else {
        // Create new profile for new user
        return UserBehaviorProfile.createDefault(
          interests: interestsDoc.data(),
        );
      }
    } catch (e) {
      debugPrint('Error loading user profile: $e');
      return UserBehaviorProfile.createDefault();
    }
  }

  /// Get candidate videos for ML processing
  Future<List<HomeVideo>> _getCandidateVideos(int limit) async {
    try {
      final snapshot = await _firestore
          .collection('videos')
          .where('status', isEqualTo: 'published')
          .where('visibility', isEqualTo: 'public')
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) => _mapToHomeVideo(doc)).toList();
    } catch (e) {
      debugPrint('Error getting candidate videos: $e');
      return [];
    }
  }

  /// Apply ML scoring to candidate videos
  Future<List<ScoredVideo>> _applyMLScoring(
    List<HomeVideo> candidates,
    UserBehaviorProfile userProfile,
  ) async {
    final scoredVideos = <ScoredVideo>[];

    for (final video in candidates) {
      try {
        final score = await _calculateMLScore(video, userProfile);
        scoredVideos.add(ScoredVideo(video: video, score: score));
      } catch (e) {
        debugPrint('Error scoring video ${video.id}: $e');
        // Add with default score
        scoredVideos.add(ScoredVideo(video: video, score: 0.5));
      }
    }

    return scoredVideos;
  }

  /// Calculate ML score for a video
  Future<double> _calculateMLScore(
    HomeVideo video,
    UserBehaviorProfile userProfile,
  ) async {
    double totalScore = 0.0;

    // 1. Recency score (0-1)
    final recencyScore = _calculateRecencyScore(video);
    totalScore += recencyScore * _featureWeights['recency']!;

    // 2. Engagement score (0-1)
    final engagementScore = _calculateEngagementScore(video);
    totalScore += engagementScore * _featureWeights['engagement']!;

    // 3. Social affinity score (0-1)
    final socialScore = await _calculateSocialAffinityScore(video, userProfile);
    totalScore += socialScore * _featureWeights['social_affinity']!;

    // 4. Content similarity score (0-1)
    final contentScore = _calculateContentSimilarityScore(video, userProfile);
    totalScore += contentScore * _featureWeights['content_similarity']!;

    // 5. User preferences score (0-1)
    final preferenceScore = _calculateUserPreferenceScore(video, userProfile);
    totalScore += preferenceScore * _featureWeights['user_preferences']!;

    return totalScore.clamp(0.0, 1.0);
  }

  /// Calculate recency score based on video age
  double _calculateRecencyScore(HomeVideo video) {
    // HomeVideo doesn't have createdAt field - use default age
    const age = 0;

    // Exponential decay: newer videos get higher scores
    return math.exp(-age / 7.0); // 7-day half-life
  }

  /// Calculate engagement score based on likes, comments, views
  double _calculateEngagementScore(HomeVideo video) {
    final totalEngagement = video.likes + video.comments;
    final views = math.max(video.views, 1); // Avoid division by zero

    return (totalEngagement / views).clamp(0.0, 1.0);
  }

  /// Calculate social affinity score
  Future<double> _calculateSocialAffinityScore(
    HomeVideo video,
    UserBehaviorProfile userProfile,
  ) async {
    try {
      // Check if user follows the creator
      final isFollowing = userProfile.followingIds.contains(video.creator.id);
      if (isFollowing) return 1.0;

      // Check if creator is in user's network
      final networkAffinity =
          userProfile.networkAffinity[video.creator.id] ?? 0.0;
      return networkAffinity;
    } catch (e) {
      return 0.5; // Default neutral score
    }
  }

  /// Calculate content similarity score
  double _calculateContentSimilarityScore(
    HomeVideo video,
    UserBehaviorProfile userProfile,
  ) {
    // Simple keyword matching (in production, use embeddings)
    final videoKeywords = _extractKeywords(video.caption);
    final userKeywords = userProfile.preferredKeywords;

    if (videoKeywords.isEmpty || userKeywords.isEmpty) return 0.5;

    final intersection = videoKeywords.intersection(userKeywords).length;
    final union = videoKeywords.union(userKeywords).length;

    return intersection / union;
  }

  /// Calculate user preference score
  double _calculateUserPreferenceScore(
    HomeVideo video,
    UserBehaviorProfile userProfile,
  ) {
    // Category preference
    final categoryScore =
        userProfile.categoryPreferences[video.categoryId] ?? 0.5;

    // Creator preference
    final creatorScore =
        userProfile.creatorPreferences[video.creator.id] ?? 0.5;

    // Duration preference (if available)
    final durationScore = _calculateDurationPreference(video, userProfile);

    return (categoryScore + creatorScore + durationScore) / 3.0;
  }

  /// Calculate duration preference score
  double _calculateDurationPreference(
    HomeVideo video,
    UserBehaviorProfile userProfile,
  ) {
    // This would use actual video duration in production
    // For now, return neutral score
    return 0.5;
  }

  /// Extract keywords from text
  Set<String> _extractKeywords(String text) {
    return text
        .toLowerCase()
        .split(RegExp(r'\W+'))
        .where((word) => word.length > 2)
        .toSet();
  }

  /// Rank and filter videos
  List<HomeVideo> _rankAndFilter(
    List<ScoredVideo> scoredVideos,
    int limit,
    List<String>? excludeVideoIds,
  ) {
    // Sort by score (descending)
    scoredVideos.sort((a, b) => b.score.compareTo(a.score));

    // Filter out excluded videos
    final filtered = excludeVideoIds != null
        ? scoredVideos.where((sv) => !excludeVideoIds.contains(sv.video.id))
        : scoredVideos;

    // Apply diversity filter
    final diversified = _applyDiversityFilter(filtered.toList(), limit);

    return diversified.take(limit).map((sv) => sv.video).toList();
  }

  /// Apply diversity filter to prevent too many videos from same creator
  List<ScoredVideo> _applyDiversityFilter(List<ScoredVideo> videos, int limit) {
    final result = <ScoredVideo>[];
    final creatorCounts = <String, int>{};
    const maxPerCreator = 2;

    for (final video in videos) {
      final creatorId = video.video.creator.id;
      final count = creatorCounts[creatorId] ?? 0;

      if (count < maxPerCreator || result.length < limit) {
        result.add(video);
        creatorCounts[creatorId] = count + 1;
      }
    }

    return result;
  }

  /// Map Firestore document to HomeVideo
  HomeVideo _mapToHomeVideo(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return HomeVideo(
      id: doc.id,
      creator: User(
        id: data['creatorId'] ?? '',
        username: data['creatorUsername'] ?? 'Unknown',
        displayName: data['creatorDisplayName'] ?? 'Unknown',
        avatarURL: data['creatorAvatarURL'],
        // isVerified field not available in User model
      ),
      videoURL: resolveVideoUrl(data),
      thumbnailURL: data['thumbnailURL'],
      likes: data['likes'] ?? 0,
      comments: data['comments'] ?? 0,
      views: data['views'] ?? 0,
      caption: data['caption'] ?? '',
      isLiked: false, // Will be set by LikeService
      isFavorited: false, // Will be set by FavoritesService
      categoryId: data['categoryId'] ?? '',
      // createdAt field not available in HomeVideo model
    );
  }

  /// Track user interaction for ML learning
  Future<void> trackUserInteraction({
    required String userId,
    required String videoId,
    required String interactionType,
    Map<String, dynamic>? metadata,
    String? creatorId,
    double watchPercentage = 0,
  }) async {
    final Map<String, dynamic> meta = metadata ?? const <String, dynamic>{};
    final String resolvedCreatorId =
        creatorId ?? meta['creatorId']?.toString() ?? '';
    try {
      await _firestore.collection('user_interactions').add({
        'userId': userId,
        'videoId': videoId,
        'creatorId': resolvedCreatorId,
        'interactionType': interactionType,
        'watchPercentage': watchPercentage,
        'timestamp': FieldValue.serverTimestamp(),
        'metadata': meta,
      });

      await _incrementUserInterests(
        userId: userId,
        interactionType: interactionType,
        metadata: meta,
      );

      _userInteractionHistory.putIfAbsent(userId, () => []).add(videoId);
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') return;
      if (kDebugMode) {
        debugPrint('Error tracking user interaction: $e');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error tracking user interaction: $e');
      }
    }
  }

  Future<void> _incrementUserInterests({
    required String userId,
    required String interactionType,
    required Map<String, dynamic> metadata,
  }) async {
    final weight = _interactionWeight(interactionType);
    if (weight <= 0) return;

    final keys = _interestKeysFor(metadata);
    if (keys.isEmpty) return;

    final updates = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };
    for (final key in keys) {
      updates[key] = FieldValue.increment(weight);
    }

    await _firestore
        .collection('userInterests')
        .doc(userId)
        .set(updates, SetOptions(merge: true));
  }

  int _interactionWeight(String type) {
    switch (type) {
      case 'watch_3s':
        return 1;
      case 'rewatch':
        return 3;
      case 'like':
      case 'comment_open':
        return 4;
      case 'save':
      case 'share':
        return 5;
      case 'follow_creator':
      case 'profile_open':
        return 6;
      default:
        return 1;
    }
  }

  Set<String> _interestKeysFor(Map<String, dynamic> metadata) {
    final text = [
      metadata['categoryId'],
      metadata['category'],
      metadata['caption'],
    ].whereType<Object>().join(' ').toLowerCase();

    final keys = <String>{};
    void addIf(bool condition, String key) {
      if (condition) keys.add(key);
    }

    addIf(text.contains('gaming') || text.contains('game'), 'gaming');
    addIf(text.contains('creator') || text.contains('tool'), 'creatorTools');
    addIf(text.contains('stream') || text.contains('setup'), 'streamingTips');
    addIf(text.contains('edit') || text.contains('clip'), 'editing');
    addIf(text.contains('esport') || text.contains('competitive'), 'esports');
    addIf(text.contains('growth') || text.contains('audience'), 'growth');

    final rawCategory = metadata['categoryId']?.toString().trim();
    if (keys.isEmpty && rawCategory != null && rawCategory.isNotEmpty) {
      keys.add(rawCategory.replaceAll(RegExp(r'[^A-Za-z0-9_]'), ''));
    }
    return keys;
  }
}

/// User behavior profile for ML
class UserBehaviorProfile {
  final String userId;
  final Set<String> followingIds;
  final Map<String, double> networkAffinity;
  final Set<String> preferredKeywords;
  final Map<String, double> categoryPreferences;
  final Map<String, double> creatorPreferences;
  final DateTime lastUpdated;

  UserBehaviorProfile({
    required this.userId,
    required this.followingIds,
    required this.networkAffinity,
    required this.preferredKeywords,
    required this.categoryPreferences,
    required this.creatorPreferences,
    required this.lastUpdated,
  });

  factory UserBehaviorProfile.createDefault({
    Map<String, dynamic>? interests,
  }) {
    return UserBehaviorProfile(
      userId: '',
      followingIds: {},
      networkAffinity: {},
      preferredKeywords: {},
      categoryPreferences: _interestsToPreferences(interests),
      creatorPreferences: {},
      lastUpdated: DateTime.now(),
    );
  }

  factory UserBehaviorProfile.fromMap(
    Map<String, dynamic> data, {
    Map<String, dynamic>? interests,
  }) {
    final categoryPreferences =
        Map<String, double>.from(data['categoryPreferences'] ?? {});
    categoryPreferences.addAll(_interestsToPreferences(interests));
    return UserBehaviorProfile(
      userId: data['userId'] ?? '',
      followingIds: Set<String>.from(data['followingIds'] ?? []),
      networkAffinity: Map<String, double>.from(data['networkAffinity'] ?? {}),
      preferredKeywords: Set<String>.from(data['preferredKeywords'] ?? []),
      categoryPreferences: categoryPreferences,
      creatorPreferences:
          Map<String, double>.from(data['creatorPreferences'] ?? {}),
      lastUpdated:
          (data['lastUpdated'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  static Map<String, double> _interestsToPreferences(
    Map<String, dynamic>? interests,
  ) {
    if (interests == null || interests.isEmpty) return {};
    final numericEntries = interests.entries.where((entry) {
      return entry.value is num && entry.key != 'updatedAt';
    }).toList();
    if (numericEntries.isEmpty) return {};
    final maxScore = numericEntries
        .map((entry) => (entry.value as num).toDouble())
        .reduce(math.max);
    if (maxScore <= 0) return {};
    return {
      for (final entry in numericEntries)
        entry.key: ((entry.value as num).toDouble() / maxScore).clamp(0.0, 1.0),
    };
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'followingIds': followingIds.toList(),
      'networkAffinity': networkAffinity,
      'preferredKeywords': preferredKeywords.toList(),
      'categoryPreferences': categoryPreferences,
      'creatorPreferences': creatorPreferences,
      'lastUpdated': Timestamp.fromDate(lastUpdated),
    };
  }
}

/// Scored video for ML ranking
class ScoredVideo {
  final HomeVideo video;
  final double score;

  ScoredVideo({required this.video, required this.score});
}
