import 'dart:async';
import 'dart:developer';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/home_video.dart';
import 'creator_growth_service.dart';
import 'network_effects_service.dart';
import 'content_diversity_service.dart';
import 'realtime_trending_service.dart';
import 'velocity_scoring_service.dart';
import 'dart:math' as math;

/// Enhanced Algorithm Service - Perfect Feed Algorithm
/// Combines ML recommendations, negative signals, watch history, and real-time learning
class EnhancedAlgorithmService {
  static EnhancedAlgorithmService? _instance;
  static EnhancedAlgorithmService get instance =>
      _instance ??= EnhancedAlgorithmService._();

  EnhancedAlgorithmService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Service instances
  final _creatorGrowth = CreatorGrowthService.instance;
  final _networkEffects = NetworkEffectsService.instance;
  final _contentDiversity = ContentDiversityService.instance;
  final _realtimeTrending = RealtimeTrendingService.instance;
  final _velocityScoring = VelocityScoringService.instance;

  // Cache for user preferences and watch history
  final Map<String, UserPreferenceCache> _userCaches = {};
  final Map<String, DateTime> _lastCacheUpdate = {};
  static const Duration _cacheRefreshInterval = Duration(minutes: 5);

  /// Get personalized feed with all enhancements
  Future<List<HomeVideo>> getPersonalizedFeed({
    required String userId,
    required List<HomeVideo> candidateVideos,
    String? userLocation,
    int limit = 20,
  }) async {
    log('🚀 Enhanced Algorithm: Generating perfect feed for $userId');

    // 1. Load user preferences and watch history (with caching)
    final userCache = await _getUserCache(userId);

    // 2. Filter out watched videos and blocked content
    final filteredVideos = await _filterCandidates(
      candidateVideos,
      userId,
      userCache,
    );

    if (filteredVideos.isEmpty) {
      log('⚠️ Enhanced Algorithm: No videos after filtering, returning original candidates');
      // Return first candidates if filtering removed everything
      final fallback = candidateVideos.take(limit).toList();
      return fallback;
    }

    // 3. Score videos using enhanced scoring
    final scoredVideos = await _scoreVideosEnhanced(
      filteredVideos,
      userId,
      userLocation,
      userCache,
    );

    // 4. Apply diversity rules
    final diversifiedVideos = _contentDiversity.applyDiversityRules(
      scoredVideos.map((sv) => sv.video).toList(),
      userId,
    );

    // 5. Re-wrap with scores and apply final adjustments
    final finalScored = _applyFinalAdjustments(
      diversifiedVideos,
      scoredVideos,
      userId,
      userCache,
      limit,
    );

    log('✅ Enhanced Algorithm: Perfect feed generated - ${finalScored.length} videos');

    return finalScored.take(limit).map((sv) => sv.video).toList();
  }

  /// Filter candidates based on watch history and negative signals
  Future<List<HomeVideo>> _filterCandidates(
    List<HomeVideo> videos,
    String userId,
    UserPreferenceCache cache,
  ) async {
    final filtered = <HomeVideo>[];

    for (final video in videos) {
      // Skip if already watched recently (within last 24 hours)
      if (cache.recentlyWatched.contains(video.id)) {
        continue;
      }

      // Skip if user skipped this video multiple times
      final skipCount = cache.skippedVideos[video.id] ?? 0;
      if (skipCount >= 2) {
        log('⏭️ Filtered out ${video.id} - skipped $skipCount times');
        continue;
      }

      // Skip if user blocked this creator
      if (cache.blockedCreators.contains(video.creator.id)) {
        continue;
      }

      // Skip if video is disliked
      if (cache.dislikedVideos.contains(video.id)) {
        continue;
      }

      filtered.add(video);
    }

    log('🎯 Enhanced Algorithm: Filtered ${videos.length} → ${filtered.length} videos');
    return filtered;
  }

  /// Enhanced video scoring with ML integration
  Future<List<EnhancedScoredVideo>> _scoreVideosEnhanced(
    List<HomeVideo> videos,
    String userId,
    String? userLocation,
    UserPreferenceCache cache,
  ) async {
    log('🎯 Enhanced Algorithm: Scoring ${videos.length} videos');

    // Use parallel processing for better performance
    final scoredVideos = await Future.wait(
      videos.map((video) => _scoreSingleVideo(
        video,
        userId,
        userLocation,
        cache,
      )),
    );

    // Sort by score
    scoredVideos.sort((a, b) => b.score.compareTo(a.score));

    return scoredVideos;
  }

  /// Score a single video with all enhancements
  ///
  /// This is the core scoring method that applies all enhancement systems to calculate
  /// a personalized score for a single video. It orchestrates multiple boost calculations
  /// and applies them multiplicatively to the base ML score.
  ///
  /// **Scoring Process:**
  /// 1. Calculate ML-based base score (from MLRecommendationService)
  /// 2. Calculate boost multipliers (creator, network, trending, velocity)
  /// 3. Apply negative signal penalties (skips, reports, etc.)
  /// 4. Apply location boost (if user location available)
  /// 5. Apply preference boost (real-time learned preferences)
  /// 6. Apply recency boost (newer videos get slight boost)
  /// 7. Calculate final score by multiplying all factors
  /// 8. Cap at 1000.0 to prevent outliers
  ///
  /// **Scoring Formula:**
  /// ```
  /// Final Score = ML Base Score ×
  ///               Creator Boost ×
  ///               Network Boost ×
  ///               Trending Boost ×
  ///               Velocity Boost ×
  ///               Negative Penalty ×
  ///               Location Boost ×
  ///               Preference Boost ×
  ///               Recency Boost
  /// ```
  ///
  /// **Parameters:**
  /// - [video]: The video to score
  /// - [userId]: Current user ID for personalization
  /// - [userLocation]: Optional user location for location-based boosts
  /// - [cache]: User preference cache for performance
  ///
  /// **Returns:**
  /// EnhancedScoredVideo with final score and detailed breakdown
  ///
  /// **Performance:**
  /// - Makes multiple async calls to various services
  /// - Uses caching to minimize redundant calculations
  /// - Each boost calculation may involve Firestore queries
  Future<EnhancedScoredVideo> _scoreSingleVideo(
    HomeVideo video,
    String userId,
    String? userLocation,
    UserPreferenceCache cache,
  ) async {
    try {
      // 1. Get ML-based base score (using MLRecommendationService)
      final mlScore = await _calculateMLBaseScore(video, userId, cache);

      // 2. Calculate boost multipliers (existing unified algorithm)
      final creatorBoost =
          await _creatorGrowth.getCreatorBoostMultiplier(video.creator.id);
      final networkBoost = await _networkEffects.calculateNetworkBoost(
        userId: userId,
        videoId: video.id,
        creatorId: video.creator.id,
      );
      final trendingBoost =
          await _realtimeTrending.calculateTrendingBoost(video.id);
      final velocityBoost =
          await _velocityScoring.calculateVelocityBoost(video.id);

      // 3. Apply negative signal penalties
      final negativePenalty = _calculateNegativePenalty(video, cache);

      // 4. Apply location boost (if user location available)
      final locationBoost = _calculateLocationBoost(video, userLocation, cache);

      // 5. Apply preference boost (real-time learned preferences)
      final preferenceBoost = _calculatePreferenceBoost(video, cache);

      // 6. Apply recency boost (better calculation)
      final recencyBoost = _calculateRecencyBoost(video);

      // 7. Calculate final score
      double finalScore = mlScore *
          creatorBoost *
          networkBoost *
          trendingBoost *
          velocityBoost *
          negativePenalty *
          locationBoost *
          preferenceBoost *
          recencyBoost;

      // Cap at reasonable max
      finalScore = finalScore.clamp(0.0, 1000.0);

      return EnhancedScoredVideo(
        video: video,
        score: finalScore,
        breakdown: EnhancedScoreBreakdown(
          mlBaseScore: mlScore,
          creatorBoost: creatorBoost,
          networkBoost: networkBoost,
          trendingBoost: trendingBoost,
          velocityBoost: velocityBoost,
          negativePenalty: negativePenalty,
          locationBoost: locationBoost,
          preferenceBoost: preferenceBoost,
          recencyBoost: recencyBoost,
          finalScore: finalScore,
        ),
      );
    } catch (e) {
      log('❌ Enhanced Algorithm: Error scoring video ${video.id}: $e');
      return EnhancedScoredVideo(
        video: video,
        score: video.mlScore,
        breakdown: EnhancedScoreBreakdown(
          mlBaseScore: video.mlScore,
          creatorBoost: 1.0,
          networkBoost: 1.0,
          trendingBoost: 1.0,
          velocityBoost: 1.0,
          negativePenalty: 1.0,
          locationBoost: 1.0,
          preferenceBoost: 1.0,
          recencyBoost: 1.0,
          finalScore: video.mlScore,
        ),
      );
    }
  }

  /// Calculate ML-based base score using MLRecommendationService
  Future<double> _calculateMLBaseScore(
    HomeVideo video,
    String userId,
    UserPreferenceCache cache,
  ) async {
    try {
      // Use existing mlScore if available and valid
      if (video.mlScore > 0) {
        // Enhance it with real-time data
        final mlScore = video.mlScore;

        // Get recency score
        final recencyScore = _calculateRecencyScore(video);

        // Get engagement score
        final engagementScore = (video.likes + video.comments) /
            math.max(video.views, 1);

        // Get social affinity (from cache)
        final socialScore = cache.followingIds.contains(video.creator.id)
            ? 1.0
            : (cache.networkAffinity[video.creator.id] ?? 0.5);

        // Get content similarity (from cache)
        final contentScore = _calculateContentSimilarity(video, cache);

        // Get user preference (from cache)
        final preferenceScore = (cache.categoryPreferences[video.categoryId] ??
                0.5) *
            0.5 +
            (cache.creatorPreferences[video.creator.id] ?? 0.5) * 0.5;

        // Weighted enhancement (matching MLRecommendationService weights)
        final enhancedScore = (recencyScore * 0.25) +
            (engagementScore.clamp(0.0, 1.0) * 0.30) +
            (socialScore * 0.20) +
            (contentScore * 0.15) +
            (preferenceScore * 0.10);

        // Combine existing mlScore with enhanced score
        return ((mlScore * 0.4) + (enhancedScore * 0.6)).clamp(0.0, 1.0);
      }

      // Calculate from scratch if no mlScore
      final recencyScore = _calculateRecencyScore(video);
      final engagementScore =
          (video.likes + video.comments) / math.max(video.views, 1);
      final socialScore = cache.followingIds.contains(video.creator.id)
          ? 1.0
          : (cache.networkAffinity[video.creator.id] ?? 0.5);
      final contentScore = _calculateContentSimilarity(video, cache);
      final preferenceScore = (cache.categoryPreferences[video.categoryId] ??
              0.5) *
          0.5 +
          (cache.creatorPreferences[video.creator.id] ?? 0.5) * 0.5;

      final mlScore = (recencyScore * 0.25) +
          (engagementScore.clamp(0.0, 1.0) * 0.30) +
          (socialScore * 0.20) +
          (contentScore * 0.15) +
          (preferenceScore * 0.10);

      return mlScore.clamp(0.0, 1.0);
    } catch (e) {
      log('⚠️ Enhanced Algorithm: Error calculating ML score, using default: $e');
      return video.mlScore > 0 ? video.mlScore : 0.5;
    }
  }

  /// Calculate recency score (improved with actual createdAt)
  double _calculateRecencyScore(HomeVideo video) {
    if (video.createdAt == null) {
      return 0.7; // Default for videos without timestamp
    }

    final now = DateTime.now();
    final createdAt = video.createdAt!.toDate();
    final ageInDays = now.difference(createdAt).inDays;

    // Exponential decay: newer videos get higher scores
    // 7-day half-life means videos older than 7 days get lower scores
    return math.exp(-ageInDays / 7.0).clamp(0.0, 1.0);
  }

  /// Calculate recency boost (additional boost on top of ML score)
  double _calculateRecencyBoost(HomeVideo video) {
    if (video.createdAt == null) return 1.0;

    final now = DateTime.now();
    final createdAt = video.createdAt!.toDate();
    final ageInHours = now.difference(createdAt).inHours;

    // Boost very recent videos (last 6 hours)
    if (ageInHours < 6) return 1.3;
    // Boost recent videos (last 24 hours)
    if (ageInHours < 24) return 1.15;
    // Slight boost for videos from last 7 days
    if (ageInHours < 168) return 1.05;
    return 1.0;
  }

  /// Calculate negative signal penalty
  double _calculateNegativePenalty(
    HomeVideo video,
    UserPreferenceCache cache,
  ) {
    double penalty = 1.0;

    // Penalize if user skipped this video once (but not filtered out)
    final skipCount = cache.skippedVideos[video.id] ?? 0;
    if (skipCount == 1) {
      penalty *= 0.7; // 30% penalty for one skip
    }

    // Penalize if user has low watch percentage for this creator
    final creatorWatchData = cache.creatorWatchData[video.creator.id];
    if (creatorWatchData != null && creatorWatchData.averageWatchPercentage < 30) {
      penalty *= 0.8; // 20% penalty for low engagement with creator
    }

    return penalty;
  }

  /// Calculate location-based boost
  double _calculateLocationBoost(
    HomeVideo video,
    String? userLocation,
    UserPreferenceCache cache,
  ) {
    if (userLocation == null || userLocation.isEmpty) return 1.0;

    // Boost videos from creators in same location
    // This would require location data in video/creator model
    // For now, return neutral
    return 1.0;
  }

  /// Calculate preference boost from real-time learned preferences
  double _calculatePreferenceBoost(
    HomeVideo video,
    UserPreferenceCache cache,
  ) {
    double boost = 1.0;

    // Category preference boost
    final categoryPref = cache.categoryPreferences[video.categoryId];
    if (categoryPref != null && categoryPref > 0.7) {
      boost *= 1.2; // 20% boost for preferred categories
    }

    // Creator preference boost
    final creatorPref = cache.creatorPreferences[video.creator.id];
    if (creatorPref != null && creatorPref > 0.7) {
      boost *= 1.3; // 30% boost for preferred creators
    }

    // Duration preference (if video has duration)
    if (video.duration != null && video.duration! > 0) {
      final preferredDuration = cache.preferredDuration;
      if (preferredDuration != null) {
        final durationDiff =
            (video.duration! - preferredDuration).abs() / preferredDuration;
        if (durationDiff < 0.2) {
          // Within 20% of preferred duration
          boost *= 1.15;
        }
      }
    }

    return boost;
  }

  /// Calculate content similarity score
  double _calculateContentSimilarity(
    HomeVideo video,
    UserPreferenceCache cache,
  ) {
    if (cache.preferredKeywords.isEmpty) return 0.5;

    final videoKeywords = _extractKeywords(video.caption);
    if (videoKeywords.isEmpty) return 0.5;

    final intersection = videoKeywords.intersection(cache.preferredKeywords).length;
    final union = videoKeywords.union(cache.preferredKeywords).length;

    return intersection / union;
  }

  /// Extract keywords from text
  Set<String> _extractKeywords(String text) {
    return text
        .toLowerCase()
        .split(RegExp(r'\W+'))
        .where((word) => word.length > 2)
        .toSet();
  }

  /// Apply final adjustments based on retention predictions
  List<EnhancedScoredVideo> _applyFinalAdjustments(
    List<HomeVideo> diversifiedVideos,
    List<EnhancedScoredVideo> scoredVideos,
    String userId,
    UserPreferenceCache cache,
    int limit,
  ) {
    final Map<String, EnhancedScoredVideo> scoredMap = {
      for (final sv in scoredVideos) sv.video.id: sv,
    };

    final finalScored = <EnhancedScoredVideo>[];
    for (final video in diversifiedVideos) {
      final scored = scoredMap[video.id];
      if (scored != null) {
        finalScored.add(scored);
      }
    }

    // Adjust for cold start users (users with < 10 watched videos)
    if (cache.totalVideosWatched < 10) {
      log('🌱 Enhanced Algorithm: Cold start user - boosting trending content');
      // Boost trending/velocity for new users
      for (int i = 0; i < finalScored.length; i++) {
        final sv = finalScored[i];
        final breakdown = sv.breakdown;
        if (breakdown.trendingBoost > 1.5 || breakdown.velocityBoost > 1.5) {
          final adjustedScore = sv.score * 1.2;
          finalScored[i] = EnhancedScoredVideo(
            video: sv.video,
            score: adjustedScore,
            breakdown: breakdown,
          );
        }
      }
      // Re-sort after adjustments
      finalScored.sort((a, b) => b.score.compareTo(a.score));
    }

    return finalScored;
  }

  /// Get user cache (with refresh logic)
  Future<UserPreferenceCache> _getUserCache(String userId) async {
    final now = DateTime.now();
    final lastUpdate = _lastCacheUpdate[userId];

    // Return cached if recent
    if (lastUpdate != null &&
        now.difference(lastUpdate) < _cacheRefreshInterval &&
        _userCaches.containsKey(userId)) {
      return _userCaches[userId]!;
    }

    // Load fresh cache
    final cache = await _loadUserCache(userId);
    _userCaches[userId] = cache;
    _lastCacheUpdate[userId] = now;

    return cache;
  }

  /// Load user preference cache from Firestore
  Future<UserPreferenceCache> _loadUserCache(String userId) async {
    try {
      // Load watch history
      final watchHistorySnapshot = await _firestore
          .collection('user_watch_history')
          .where('userId', isEqualTo: userId)
          .where('timestamp',
              isGreaterThan: Timestamp.fromDate(
                  DateTime.now().subtract(const Duration(days: 1))))
          .orderBy('timestamp', descending: true)
          .limit(100)
          .get();

      final recentlyWatched = watchHistorySnapshot.docs
          .map((doc) => doc.data()['videoId'] as String)
          .toSet();

      // Load skipped videos
      final skippedSnapshot = await _firestore
          .collection('user_interactions')
          .where('userId', isEqualTo: userId)
          .where('interactionType', isEqualTo: 'skip')
          .get();

      final skippedVideos = <String, int>{};
      for (final doc in skippedSnapshot.docs) {
        final videoId = doc.data()['videoId'] as String;
        skippedVideos[videoId] = (skippedVideos[videoId] ?? 0) + 1;
      }

      // Load disliked videos
      final dislikedSnapshot = await _firestore
          .collection('user_interactions')
          .where('userId', isEqualTo: userId)
          .where('interactionType', isEqualTo: 'dislike')
          .get();

      final dislikedVideos = dislikedSnapshot.docs
          .map((doc) => doc.data()['videoId'] as String)
          .toSet();

      // Load blocked creators
      final blockedSnapshot = await _firestore
          .collection('user_blocks')
          .where('blockerId', isEqualTo: userId)
          .get();

      final blockedCreators = blockedSnapshot.docs
          .map((doc) => doc.data()['blockedUserId'] as String)
          .toSet();

      // Load following list
      final userDoc =
          await _firestore.collection('users').doc(userId).get();
      final followingIds = (userDoc.data()?['following'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toSet() ??
          <String>{};

      // Load category and creator preferences from engagement data
      final preferencesDoc = await _firestore
          .collection('user_preferences')
          .doc(userId)
          .get();

      final preferencesData = preferencesDoc.data() ?? {};

      final categoryPreferences =
          Map<String, double>.from(preferencesData['categoryPreferences'] ?? {});
      final creatorPreferences =
          Map<String, double>.from(preferencesData['creatorPreferences'] ?? {});

      // Load network affinity
      final networkAffinity =
          Map<String, double>.from(preferencesData['networkAffinity'] ?? {});

      // Load preferred keywords
      final preferredKeywords = (preferencesData['preferredKeywords'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toSet() ??
          <String>{};

      // Load creator watch data
      final creatorWatchData = <String, CreatorWatchData>{};
      final watchDataSnapshot = await _firestore
          .collection('engagement')
          .where('userId', isEqualTo: userId)
          .get();

      for (final doc in watchDataSnapshot.docs) {
        final data = doc.data();
        final creatorId = data['creatorId'] as String?;
        if (creatorId != null) {
          final existing = creatorWatchData[creatorId] ?? CreatorWatchData();
          existing.totalWatches += 1;
          existing.averageWatchPercentage = (existing.averageWatchPercentage *
                      (existing.totalWatches - 1) +
                  (data['averageWatchPercentage'] as num? ?? 0.0).toDouble()) /
              existing.totalWatches;
          creatorWatchData[creatorId] = existing;
        }
      }

      // Load preferred duration
      final preferredDuration =
          (preferencesData['preferredDuration'] as num?)?.toDouble();

      return UserPreferenceCache(
        userId: userId,
        recentlyWatched: recentlyWatched,
        skippedVideos: skippedVideos,
        dislikedVideos: dislikedVideos,
        blockedCreators: blockedCreators,
        followingIds: followingIds,
        categoryPreferences: categoryPreferences,
        creatorPreferences: creatorPreferences,
        networkAffinity: networkAffinity,
        preferredKeywords: preferredKeywords,
        creatorWatchData: creatorWatchData,
        preferredDuration: preferredDuration,
        totalVideosWatched: watchHistorySnapshot.docs.length,
      );
    } catch (e) {
      if (e.toString().contains('permission-denied') ||
          e.toString().contains('PERMISSION_DENIED')) {
        return UserPreferenceCache.empty(userId);
      }
      log('❌ Enhanced Algorithm: Error loading user cache: $e');
      return UserPreferenceCache.empty(userId);
    }
  }

  /// Track video skip (negative signal)
  Future<void> trackSkip({
    required String videoId,
    required String creatorId,
    required String userId,
    double watchPercentage = 0.0,
  }) async {
    try {
      await _firestore.collection('user_interactions').add({
        'userId': userId,
        'videoId': videoId,
        'creatorId': creatorId,
        'interactionType': 'skip',
        'watchPercentage': watchPercentage,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Invalidate cache for this user
      _userCaches.remove(userId);
      _lastCacheUpdate.remove(userId);

      log('⏭️ Enhanced Algorithm: Tracked skip for video $videoId (watched ${watchPercentage.toStringAsFixed(1)}%)');
    } catch (e) {
      log('❌ Enhanced Algorithm: Error tracking skip: $e');
    }
  }

  /// Track video watch (for watch history)
  Future<void> trackWatch({
    required String videoId,
    required String userId,
    double watchPercentage = 0.0,
  }) async {
    try {
      // Only track if watched more than 50% (meaningful watch)
      if (watchPercentage < 50.0) return;

      await _firestore.collection('user_watch_history').add({
        'userId': userId,
        'videoId': videoId,
        'watchPercentage': watchPercentage,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Invalidate cache for this user
      _userCaches.remove(userId);
      _lastCacheUpdate.remove(userId);

      log('👁️ Enhanced Algorithm: Tracked watch for video $videoId (${watchPercentage.toStringAsFixed(1)}%)');
    } catch (e) {
      log('❌ Enhanced Algorithm: Error tracking watch: $e');
    }
  }

  /// Update user preferences based on engagement (real-time learning)
  Future<void> updatePreferences({
    required String userId,
    required String videoId,
    required String creatorId,
    required String categoryId,
    required double watchPercentage,
    List<String>? keywords,
  }) async {
    try {
      final prefsRef = _firestore.collection('user_preferences').doc(userId);

      // Update category preference
      if (watchPercentage > 75) {
        // High engagement - increase preference
        await prefsRef.set({
          'categoryPreferences.$categoryId': FieldValue.increment(0.05),
        }, SetOptions(merge: true));

        await prefsRef.set({
          'creatorPreferences.$creatorId': FieldValue.increment(0.05),
        }, SetOptions(merge: true));
      } else if (watchPercentage < 25) {
        // Low engagement - decrease preference
        await prefsRef.set({
          'categoryPreferences.$categoryId': FieldValue.increment(-0.02),
        }, SetOptions(merge: true));
      }

      // Update preferred keywords
      if (keywords != null && keywords.isNotEmpty) {
        await prefsRef.set({
          'preferredKeywords': FieldValue.arrayUnion(keywords),
        }, SetOptions(merge: true));
      }

      // Update preferred duration (if video has duration)
      // This would require duration in the video model

      // Invalidate cache
      _userCaches.remove(userId);
      _lastCacheUpdate.remove(userId);

      log('🎯 Enhanced Algorithm: Updated preferences for user $userId');
    } catch (e) {
      log('❌ Enhanced Algorithm: Error updating preferences: $e');
    }
  }
}

/// User preference cache model
class UserPreferenceCache {
  final String userId;
  final Set<String> recentlyWatched;
  final Map<String, int> skippedVideos;
  final Set<String> dislikedVideos;
  final Set<String> blockedCreators;
  final Set<String> followingIds;
  final Map<String, double> categoryPreferences;
  final Map<String, double> creatorPreferences;
  final Map<String, double> networkAffinity;
  final Set<String> preferredKeywords;
  final Map<String, CreatorWatchData> creatorWatchData;
  final double? preferredDuration;
  final int totalVideosWatched;

  UserPreferenceCache({
    required this.userId,
    required this.recentlyWatched,
    required this.skippedVideos,
    required this.dislikedVideos,
    required this.blockedCreators,
    required this.followingIds,
    required this.categoryPreferences,
    required this.creatorPreferences,
    required this.networkAffinity,
    required this.preferredKeywords,
    required this.creatorWatchData,
    this.preferredDuration,
    required this.totalVideosWatched,
  });

  factory UserPreferenceCache.empty(String userId) {
    return UserPreferenceCache(
      userId: userId,
      recentlyWatched: {},
      skippedVideos: {},
      dislikedVideos: {},
      blockedCreators: {},
      followingIds: {},
      categoryPreferences: {},
      creatorPreferences: {},
      networkAffinity: {},
      preferredKeywords: {},
      creatorWatchData: {},
      totalVideosWatched: 0,
    );
  }
}

/// Creator watch data model
class CreatorWatchData {
  int totalWatches = 0;
  double averageWatchPercentage = 0.0;
}

/// Enhanced scored video model
class EnhancedScoredVideo {
  final HomeVideo video;
  final double score;
  final EnhancedScoreBreakdown breakdown;

  EnhancedScoredVideo({
    required this.video,
    required this.score,
    required this.breakdown,
  });
}

/// Enhanced score breakdown
class EnhancedScoreBreakdown {
  final double mlBaseScore;
  final double creatorBoost;
  final double networkBoost;
  final double trendingBoost;
  final double velocityBoost;
  final double negativePenalty;
  final double locationBoost;
  final double preferenceBoost;
  final double recencyBoost;
  final double finalScore;

  EnhancedScoreBreakdown({
    required this.mlBaseScore,
    required this.creatorBoost,
    required this.networkBoost,
    required this.trendingBoost,
    required this.velocityBoost,
    required this.negativePenalty,
    required this.locationBoost,
    required this.preferenceBoost,
    required this.recencyBoost,
    required this.finalScore,
  });

  Map<String, dynamic> toJson() => {
        'mlBaseScore': mlBaseScore,
        'creatorBoost': creatorBoost,
        'networkBoost': networkBoost,
        'trendingBoost': trendingBoost,
        'velocityBoost': velocityBoost,
        'negativePenalty': negativePenalty,
        'locationBoost': locationBoost,
        'preferenceBoost': preferenceBoost,
        'recencyBoost': recencyBoost,
        'finalScore': finalScore,
      };
}
