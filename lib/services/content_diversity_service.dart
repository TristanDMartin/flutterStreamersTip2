import 'dart:developer';
import '../models/home_video.dart';

/// Content diversity service - Prevents creator fatigue
/// Implements TikTok-style content rotation and fresh creator injection
class ContentDiversityService {
  static ContentDiversityService? _instance;
  static ContentDiversityService get instance =>
      _instance ??= ContentDiversityService._();

  ContentDiversityService._();

  // Diversity constraints
  static const int MAX_SAME_CREATOR_IN_ROW = 2;
  static const int CATEGORY_ROTATION_INTERVAL = 7; // Every 7 videos
  static const int FRESH_CREATOR_INJECTION_INTERVAL = 10; // Every 10 videos

  /// Apply diversity rules to a list of videos
  /// 🚀 NEWEST FIRST: Diversity rules respect newest-first order - only swap within same time window
  List<HomeVideo> applyDiversityRules(
    List<HomeVideo> videos,
    String userId,
  ) {
    if (videos.length < 3) return videos; // Not enough to diversify

    log('🎨 Applying diversity rules to ${videos.length} videos (respecting newest-first order)');

    // 🚀 NEWEST FIRST: Group videos by time windows to preserve newest-first order
    // Only apply diversity within same time window (e.g., same day)
    final now = DateTime.now().millisecondsSinceEpoch;
    final dayInMs = 24 * 60 * 60 * 1000;

    // Separate videos into recent (last 24h) and older
    final recentVideos = <HomeVideo>[];
    final olderVideos = <HomeVideo>[];

    for (final video in videos) {
      final videoTime = video.createdAt?.millisecondsSinceEpoch ?? 0;
      if ((now - videoTime) < dayInMs) {
        recentVideos.add(video);
      } else {
        olderVideos.add(video);
      }
    }

    // Apply diversity rules separately to each group (preserves newest-first)
    final diversifiedRecent = _applyDiversityToGroup(recentVideos, userId);
    final diversifiedOlder = _applyDiversityToGroup(olderVideos, userId);

    // Combine: recent first (newest), then older
    final diversified = [...diversifiedRecent, ...diversifiedOlder];

    log('✅ Diversity applied: ${videos.length} → ${diversified.length} videos (newest-first preserved)');
    return diversified;
  }

  /// Apply diversity rules to a single group of videos (same time window)
  List<HomeVideo> _applyDiversityToGroup(
      List<HomeVideo> videos, String userId) {
    if (videos.length < 3) return videos;

    List<HomeVideo> diversified = [];
    String? lastCreatorId;
    int sameCreatorCount = 0;
    int videosSinceLastCategory = 0;
    int videosSinceLastFreshCreator = 0;
    String? lastCategory;
    final Set<String> seenCreators = {};
    final List<HomeVideo> remainingVideos = List.from(videos);

    for (int i = 0; i < remainingVideos.length; i++) {
      final video = remainingVideos[i];
      bool shouldInsert = true;

      // Rule 1: Max 2 videos from same creator in a row
      if (video.creator.id == lastCreatorId) {
        sameCreatorCount++;
        if (sameCreatorCount >= MAX_SAME_CREATOR_IN_ROW) {
          // Skip this video, find different creator (but keep newest-first order)
          final alternateVideo = _findDifferentCreator(
            remainingVideos.sublist(i + 1),
            lastCreatorId!,
          );

          if (alternateVideo != null) {
            diversified.add(alternateVideo);
            remainingVideos.remove(alternateVideo);
            lastCreatorId = alternateVideo.creator.id;
            sameCreatorCount = 1;
            seenCreators.add(alternateVideo.creator.id);
            log('🔄 Swapped creator: ${video.creator.username} → ${alternateVideo.creator.username}');
            i--; // Adjust index after removal
            continue;
          }
        }
      } else {
        sameCreatorCount = 1;
        lastCreatorId = video.creator.id;
      }

      // Rule 2: Category rotation every 7 videos
      videosSinceLastCategory++;
      if (videosSinceLastCategory >= CATEGORY_ROTATION_INTERVAL) {
        final differentCategory = _findDifferentCategory(
          remainingVideos.sublist(i + 1),
          lastCategory,
        );

        if (differentCategory != null) {
          diversified.add(differentCategory);
          remainingVideos.remove(differentCategory);
          lastCategory = differentCategory.categoryId;
          videosSinceLastCategory = 0;
          seenCreators.add(differentCategory.creator.id);
          log('🎯 Category rotation: ${video.categoryId} → ${differentCategory.categoryId}');
          i--; // Adjust index after removal
          continue;
        }
      }
      lastCategory = video.categoryId;

      // Rule 3: Fresh creator injection every 10 videos
      videosSinceLastFreshCreator++;
      if (videosSinceLastFreshCreator >= FRESH_CREATOR_INJECTION_INTERVAL) {
        final freshCreator = _findFreshCreator(
          remainingVideos.sublist(i + 1),
          seenCreators,
        );

        if (freshCreator != null) {
          diversified.add(freshCreator);
          remainingVideos.remove(freshCreator);
          seenCreators.add(freshCreator.creator.id);
          videosSinceLastFreshCreator = 0;
          log('✨ Fresh creator injected: ${freshCreator.creator.username}');
          i--; // Adjust index after removal
          continue;
        }
      }

      // Add video if it passed all rules
      if (shouldInsert) {
        diversified.add(video);
        seenCreators.add(video.creator.id);
      }
    }

    return diversified;
  }

  /// Find video from different creator
  HomeVideo? _findDifferentCreator(
      List<HomeVideo> videos, String excludeCreatorId) {
    for (final video in videos) {
      if (video.creator.id != excludeCreatorId) {
        return video;
      }
    }
    return null;
  }

  /// Find video from different category
  HomeVideo? _findDifferentCategory(
      List<HomeVideo> videos, String? excludeCategory) {
    for (final video in videos) {
      if (video.categoryId != excludeCategory && video.categoryId.isNotEmpty) {
        return video;
      }
    }
    return null;
  }

  /// Find video from fresh creator (not seen yet)
  HomeVideo? _findFreshCreator(
      List<HomeVideo> videos, Set<String> seenCreators) {
    for (final video in videos) {
      if (!seenCreators.contains(video.creator.id)) {
        return video;
      }
    }
    return null;
  }

  /// Calculate diversity score for feed (0-1, higher = more diverse)
  double calculateDiversityScore(List<HomeVideo> videos) {
    if (videos.isEmpty) return 0.0;

    final uniqueCreators = videos.map((v) => v.creator.id).toSet().length;
    final uniqueCategories = videos
        .map((v) => v.categoryId)
        .where((c) => c.isNotEmpty)
        .toSet()
        .length;

    // Ideal: 80% unique creators, 50% unique categories
    final creatorDiversity = uniqueCreators / videos.length;
    final categoryDiversity = uniqueCategories / (videos.length / 2);

    final score = (creatorDiversity * 0.7) + (categoryDiversity * 0.3);

    log('📊 Diversity score: ${score.toStringAsFixed(2)} (${uniqueCreators} creators, ${uniqueCategories} categories)');

    return score.clamp(0.0, 1.0);
  }
}
