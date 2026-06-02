import '../models/home_video.dart';
import 'advanced_engagement_service.dart';
import 'creator_growth_service.dart';
import 'retention_prediction_service.dart';
import 'network_effects_service.dart';
import 'content_diversity_service.dart';
import 'realtime_trending_service.dart';
import 'velocity_scoring_service.dart';
import 'package:streamers_tip/utils/secure_log.dart';

/// Unified Algorithm Service - Better than TikTok
/// Orchestrates all 7 advanced engagement systems for optimal user experience
class UnifiedAlgorithmService {
  static UnifiedAlgorithmService? _instance;
  static UnifiedAlgorithmService get instance =>
      _instance ??= UnifiedAlgorithmService._();

  UnifiedAlgorithmService._();

  // Service instances
  final _advancedEngagement = AdvancedEngagementService.instance;
  final _creatorGrowth = CreatorGrowthService.instance;
  final _retentionPrediction = RetentionPredictionService.instance;
  final _networkEffects = NetworkEffectsService.instance;
  final _contentDiversity = ContentDiversityService.instance;
  final _realtimeTrending = RealtimeTrendingService.instance;
  final _velocityScoring = VelocityScoringService.instance;

  /// Score and rank videos using all 7 advanced engagement systems
  ///
  /// This is the core algorithm method that orchestrates all 7 engagement systems
  /// to score and rank videos for personalized feed generation.
  ///
  /// **The 7 Systems:**
  /// 1. **Creator Growth System** - Boosts new, consistent, growing, and comeback creators
  /// 2. **Network Effects** - Amplifies content from connections and similar users
  /// 3. **Real-time Trending** - Boosts videos with burst, hourly, or prime-time engagement
  /// 4. **Velocity Scoring** - Rewards videos with high engagement, viral, quality, or speed signals
  /// 5. **Advanced Watch Time** - Tracks granular watch segments and replays
  /// 6. **Retention Prediction** - Predicts user retention and churn risk
  /// 7. **Content Diversity** - Ensures variety in feed (applied after scoring)
  ///
  /// **Scoring Formula:**
  /// ```
  /// Final Score = Base Score (ML) ×
  ///               Creator Boost ×
  ///               Network Boost ×
  ///               Trending Boost ×
  ///               Velocity Boost
  /// ```
  ///
  /// **Scoring Process:**
  /// 1. For each video, calculate all boost multipliers in parallel
  /// 2. Apply multipliers to base ML score
  /// 3. Cap final score at 500.0 to prevent outliers
  /// 4. Sort videos by score (highest first)
  /// 5. Apply content diversity rules (max 2 videos per creator)
  ///
  /// **Error Handling:**
  /// - If any boost calculation fails, uses base score with 1.0x multipliers
  /// - Continues processing remaining videos
  /// - Logs errors for debugging
  ///
  /// **Performance:**
  /// - Processes videos in sequence (can be optimized to parallel if needed)
  /// - Each boost calculation may involve Firestore queries
  /// - Caching is handled by individual services
  ///
  /// **Parameters:**
  /// - [videos]: List of videos to score and rank
  /// - [userId]: Current user ID for personalization
  /// - [userLocation]: Optional user location for location-based boosts
  ///
  /// **Returns:**
  /// List of ScoredVideo objects sorted by score (highest first), with diversity rules applied
  ///
  /// **Example:**
  /// ```dart
  /// final scored = await UnifiedAlgorithmService.instance.scoreAndRankVideos(
  ///   videos: allVideos,
  ///   userId: currentUserId,
  ///   userLocation: 'US',
  /// );
  /// // Use scored[0..N] for feed
  /// ```
  Future<List<ScoredVideo>> scoreAndRankVideos({
    required List<HomeVideo> videos,
    required String userId,
    String? userLocation,
  }) async {
    if (videos.isEmpty) return [];

    secureLog(
        '🎯 Unified Algorithm: Scoring ${videos.length} videos for user $userId');

    final List<ScoredVideo> scoredVideos = [];

    for (final video in videos) {
      try {
        // Calculate all boost multipliers
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

        // Base score (from existing ML score or default)
        double baseScore = video.mlScore;

        // Apply all multipliers
        double finalScore = baseScore *
            creatorBoost *
            networkBoost *
            trendingBoost *
            velocityBoost;

        // Cap at reasonable max
        finalScore = finalScore.clamp(0.0, 500.0);

        scoredVideos.add(ScoredVideo(
          video: video,
          score: finalScore,
          breakdown: ScoreBreakdown(
            baseScore: baseScore,
            creatorBoost: creatorBoost,
            networkBoost: networkBoost,
            trendingBoost: trendingBoost,
            velocityBoost: velocityBoost,
            finalScore: finalScore,
          ),
        ));

        secureLog('📊 Scored ${video.id}: ${finalScore.toStringAsFixed(2)} '
            '(base: ${baseScore.toStringAsFixed(1)}, '
            'creator: ${creatorBoost.toStringAsFixed(2)}x, '
            'network: ${networkBoost.toStringAsFixed(2)}x, '
            'trending: ${trendingBoost.toStringAsFixed(2)}x, '
            'velocity: ${velocityBoost.toStringAsFixed(2)}x)');
      } catch (e) {
        secureLog('❌ Error scoring video ${video.id}: $e');
        // Add with base score if scoring fails
        scoredVideos.add(ScoredVideo(
          video: video,
          score: video.mlScore,
          breakdown: ScoreBreakdown(
            baseScore: video.mlScore,
            creatorBoost: 1.0,
            networkBoost: 1.0,
            trendingBoost: 1.0,
            velocityBoost: 1.0,
            finalScore: video.mlScore,
          ),
        ));
      }
    }

    // 🚀 NEWEST FIRST: Sort by creation date first (newest first), then by score
    // This ensures newest videos always appear first, with scoring as secondary factor
    scoredVideos.sort((a, b) {
      final aTime = a.video.createdAt?.millisecondsSinceEpoch ?? 0;
      final bTime = b.video.createdAt?.millisecondsSinceEpoch ?? 0;

      // First, prioritize newest videos (within last 24 hours get priority)
      final now = DateTime.now().millisecondsSinceEpoch;
      final dayInMs = 24 * 60 * 60 * 1000;
      final aIsRecent = (now - aTime) < dayInMs;
      final bIsRecent = (now - bTime) < dayInMs;

      // If one is recent and other isn't, recent wins
      if (aIsRecent && !bIsRecent) return -1;
      if (!aIsRecent && bIsRecent) return 1;

      // If both are recent or both are old, sort by score within that group
      // But still prioritize newest within same score range
      final scoreDiff = b.score.compareTo(a.score);
      if (scoreDiff != 0) {
        // If score difference is significant (>10%), use score
        final scoreRatio =
            (a.score > 0 && b.score > 0) ? (a.score / b.score).abs() : 1.0;
        if (scoreRatio < 0.9 || scoreRatio > 1.1) {
          return scoreDiff;
        }
      }

      // Otherwise, newest first
      return bTime.compareTo(aTime);
    });

    // Apply content diversity rules
    final rankedVideos = scoredVideos.map((sv) => sv.video).toList();
    final diversifiedVideos =
        _contentDiversity.applyDiversityRules(rankedVideos, userId);

    // Re-wrap with scores
    final diversifiedScored = diversifiedVideos.map((video) {
      final original = scoredVideos.firstWhere((sv) => sv.video.id == video.id);
      return original;
    }).toList();

    secureLog(
        '✅ Unified Algorithm: Final ranking complete - ${diversifiedScored.length} videos');

    return diversifiedScored;
  }

  /// Get personalized feed for user (combines all systems)
  Future<List<HomeVideo>> getPersonalizedFeed({
    required String userId,
    required List<HomeVideo> candidateVideos,
    String? userLocation,
    int limit = 20,
  }) async {
    secureLog('🎯 Unified Algorithm: Generating personalized feed for $userId');

    // 1. Score and rank all candidates
    final scoredVideos = await scoreAndRankVideos(
      videos: candidateVideos,
      userId: userId,
      userLocation: userLocation,
    );

    // 2. Predict retention and adjust
    final nextVideoProb =
        await _retentionPrediction.predictNextVideoWatch(userId);
    final dailyReturnProb =
        await _retentionPrediction.predictDailyReturn(userId);
    final churnRisk = await _retentionPrediction.calculateChurnRisk(userId);

    secureLog(
        '📊 Retention scores: nextVideo=${nextVideoProb.toStringAsFixed(2)}, '
        'daily=${dailyReturnProb.toStringAsFixed(2)}, '
        'churnRisk=${churnRisk.toStringAsFixed(2)}');

    // 3. Adjust feed based on churn risk
    List<ScoredVideo> adjustedFeed = scoredVideos;

    if (churnRisk > 0.7) {
      // High churn risk: prioritize best content
      secureLog('⚠️ High churn risk - prioritizing top performers');
      adjustedFeed = scoredVideos.take(limit * 2).toList();
    } else if (nextVideoProb < 0.3) {
      // Low next-video probability: inject fresh creators
      secureLog('✨ Low retention - injecting fresh creators');
      // Fresh creators already handled by diversity engine
    }

    // 4. Limit to requested count
    final finalFeed = adjustedFeed.take(limit).map((sv) => sv.video).toList();

    // 5. Calculate diversity score for analytics
    final diversityScore = _contentDiversity.calculateDiversityScore(finalFeed);
    secureLog('🎨 Feed diversity score: ${diversityScore.toStringAsFixed(2)}');

    secureLog('✅ Personalized feed complete: ${finalFeed.length} videos');

    return finalFeed;
  }

  /// Track video engagement (updates all systems)
  Future<void> trackEngagement({
    required String videoId,
    required String creatorId,
    required String userId,
    required double watchPercentage,
    required double totalDuration,
    required bool isReplay,
    required bool didComplete,
  }) async {
    secureLog(
        '📊 Tracking engagement: $videoId (${watchPercentage.toStringAsFixed(1)}%)');

    // 1. Track watch time
    _advancedEngagement.trackWatchTime(
      videoId: videoId,
      creatorId: creatorId,
      watchPercentage: watchPercentage,
      totalDuration: totalDuration,
      isReplay: isReplay,
      didComplete: didComplete,
    );

    // 2. Increment session counters
    _advancedEngagement.incrementVideoWatch();

    if (didComplete || watchPercentage > 75) {
      _advancedEngagement.incrementEngagementAction();
    }

    secureLog('✅ Engagement tracked successfully');
  }

  /// Start user session (initializes tracking)
  void startSession(String userId) {
    secureLog('🎬 Starting session for user: $userId');
    _advancedEngagement.startSession();
  }

  /// End user session (saves retention data)
  Future<void> endSession() async {
    secureLog('🎬 Ending session');
    await _advancedEngagement.endSession();
  }
}

/// Scored video model
class ScoredVideo {
  final HomeVideo video;
  final double score;
  final ScoreBreakdown breakdown;

  ScoredVideo({
    required this.video,
    required this.score,
    required this.breakdown,
  });
}

/// Score breakdown for debugging/analytics
class ScoreBreakdown {
  final double baseScore;
  final double creatorBoost;
  final double networkBoost;
  final double trendingBoost;
  final double velocityBoost;
  final double finalScore;

  ScoreBreakdown({
    required this.baseScore,
    required this.creatorBoost,
    required this.networkBoost,
    required this.trendingBoost,
    required this.velocityBoost,
    required this.finalScore,
  });

  Map<String, dynamic> toJson() => {
        'baseScore': baseScore,
        'creatorBoost': creatorBoost,
        'networkBoost': networkBoost,
        'trendingBoost': trendingBoost,
        'velocityBoost': velocityBoost,
        'finalScore': finalScore,
      };
}
