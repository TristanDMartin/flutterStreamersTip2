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
  List<HomeVideo> applyDiversityRules(
    List<HomeVideo> videos,
    String userId,
  ) {
    if (videos.length < 3) return videos; // Not enough to diversify

    log('🎨 Applying diversity rules to ${videos.length} videos');

    List<HomeVideo> diversified = [];
    String? lastCreatorId;
    int sameCreatorCount = 0;
    int videosSinceLastCategory = 0;
    int videosSinceLastFreshCreator = 0;
    String? lastCategory;
    final Set<String> seenCreators = {};

    for (int i = 0; i < videos.length; i++) {
      final video = videos[i];
      bool shouldInsert = true;

      // Rule 1: Max 2 videos from same creator in a row
      if (video.creator.id == lastCreatorId) {
        sameCreatorCount++;
        if (sameCreatorCount >= MAX_SAME_CREATOR_IN_ROW) {
          // Skip this video, find different creator
          final alternateVideo = _findDifferentCreator(
            videos.sublist(i),
            lastCreatorId!,
          );

          if (alternateVideo != null) {
            diversified.add(alternateVideo);
            videos.remove(alternateVideo);
            lastCreatorId = alternateVideo.creator.id;
            sameCreatorCount = 1;
            seenCreators.add(alternateVideo.creator.id);
            log('🔄 Swapped creator: ${video.creator.username} → ${alternateVideo.creator.username}');
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
          videos.sublist(i),
          lastCategory,
        );

        if (differentCategory != null) {
          diversified.add(differentCategory);
          videos.remove(differentCategory);
          lastCategory = differentCategory.categoryId;
          videosSinceLastCategory = 0;
          seenCreators.add(differentCategory.creator.id);
          log('🎯 Category rotation: ${video.categoryId} → ${differentCategory.categoryId}');
          continue;
        }
      }
      lastCategory = video.categoryId;

      // Rule 3: Fresh creator injection every 10 videos
      videosSinceLastFreshCreator++;
      if (videosSinceLastFreshCreator >= FRESH_CREATOR_INJECTION_INTERVAL) {
        final freshCreator = _findFreshCreator(
          videos.sublist(i),
          seenCreators,
        );

        if (freshCreator != null) {
          diversified.add(freshCreator);
          videos.remove(freshCreator);
          seenCreators.add(freshCreator.creator.id);
          videosSinceLastFreshCreator = 0;
          log('✨ Fresh creator injected: ${freshCreator.creator.username}');
          continue;
        }
      }

      // Add video if it passed all rules
      if (shouldInsert) {
        diversified.add(video);
        seenCreators.add(video.creator.id);
      }
    }

    log('✅ Diversity applied: ${videos.length} → ${diversified.length} videos');
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
