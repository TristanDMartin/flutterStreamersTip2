import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/home_video.dart';
import '../../../providers/home_provider.dart' as hp;
import '../../../providers/video_service_provider.dart';
import '../../../services/video_service.dart';
import '../../../utils/category_schema.dart';
import '../../../utils/discover_category_rules.dart';
import '../../../utils/home_video_playback.dart';
import '../../../utils/video_document_rules.dart';
import 'discover_source_audit.dart';

/// Home For You + Discover share this eligible set (VideoService ∪ Home, deduped).
class DiscoverEligibleVideosResolver {
  const DiscoverEligibleVideosResolver._();

  static List<HomeVideo> resolveEligible(WidgetRef ref) {
    final List<HomeVideo> merged = mergeCanonicalFeedCandidates(ref);
    final List<HomeVideo> eligible = <HomeVideo>[];
    for (final HomeVideo video in merged) {
      final String? reason = rejectCanonicalFeedVideo(video);
      if (reason != null) {
        if (kDebugMode) {
          logDiscoverSkipHomeVideo(video: video, reason: reason);
        }
        continue;
      }
      eligible.add(video);
      if (kDebugMode) {
        logVideoCategoryFields(video);
      }
    }
    if (kDebugMode) {
      logDiscoverCategoryBucketAudit(eligible);
    }
    return eligible;
  }

  /// Mirrors [HomeViewModel] source priority: VideoService cache, then Home state.
  static List<HomeVideo> mergeCanonicalFeedCandidates(WidgetRef ref) {
    final VideoService videoService = ref.read(videoServiceProvider);
    final List<HomeVideo> fromService = videoService.getAllVideos();
    final List<HomeVideo> fromHome = ref.read(hp.homeProvider).forYouVideos;
    final Map<String, HomeVideo> byId = <String, HomeVideo>{};
    for (final HomeVideo video in fromHome) {
      final String id = video.id.trim();
      if (id.isEmpty) {
        continue;
      }
      byId[id] = video;
    }
    for (final HomeVideo video in fromService) {
      final String id = video.id.trim();
      if (id.isEmpty) {
        continue;
      }
      byId[id] = video;
    }
    return byId.values.toList(growable: false);
  }

  static List<HomeVideo> filterByCategory(
    List<HomeVideo> eligible,
    String selectedCategoryId,
  ) {
    if (isAllCategorySlug(selectedCategoryId)) {
      return eligible;
    }
    return eligible
        .where(
          (HomeVideo video) =>
              homeVideoMatchesDiscoverCategory(video, selectedCategoryId),
        )
        .toList(growable: false);
  }

  static void logCategoryLoadAudit({
    required WidgetRef ref,
    required String selectedCategoryId,
    required List<HomeVideo> eligible,
    required List<HomeVideo> matching,
  }) {
    final int homeCount = ref.read(hp.homeProvider).forYouVideos.length;
    final int serviceCount = ref.read(videoServiceProvider).getAllVideos().length;
    if (kDebugMode) {
      debugPrint(
        'DISCOVER_SOURCE_AUDIT '
        'home=$homeCount '
        'videoService=$serviceCount '
        'discoverAll=${eligible.length} '
        'selected=$selectedCategoryId '
        'matching=${matching.length}',
      );
    }
    logDiscoverSourceAudit(
      buildDiscoverSourceAuditReport(
        selectedCategory: selectedCategoryId,
        homeFeedCount: homeCount,
        rawDocs: eligible.map(homeVideoToFirestoreShape).toList(),
        eligibleDocs: eligible.map(homeVideoToFirestoreShape).toList(),
        matchingDocs: matching.map(homeVideoToFirestoreShape).toList(),
      ),
    );
  }
}

/// Same rules as Home For You + public feed hydration.
bool isDiscoverEligibleHomeVideo(HomeVideo video) {
  return rejectCanonicalFeedVideo(video) == null;
}

String? rejectDiscoverEligibleHomeVideo(HomeVideo video) {
  return rejectCanonicalFeedVideo(video);
}

String? rejectCanonicalFeedVideo(HomeVideo video) {
  if (!isHomeVideoVisibleInFeed(video)) {
    return 'not_visible_in_feed';
  }
  final String visibility = video.visibility.toLowerCase();
  if (visibility == 'private' ||
      visibility == 'followers_only' ||
      visibility == 'followers') {
    return 'visibility';
  }
  if (!isHomeVideoPlayable(video)) {
    if (video.videoURL.trim().isEmpty) {
      return 'no_playable_url';
    }
    return 'status:${video.status}';
  }
  return null;
}

String normalizeVideoCategorySlug(HomeVideo video) {
  return categoryIdFromVideoDocument(homeVideoToFirestoreShape(video));
}

bool homeVideoMatchesDiscoverCategory(
  HomeVideo video,
  String selectedCategoryId,
) {
  if (isAllCategorySlug(selectedCategoryId)) {
    return true;
  }
  return matchesDiscoverCategory(
    homeVideoToFirestoreShape(video),
    selectedCategoryId,
  );
}

Map<String, dynamic> homeVideoToFirestoreShape(HomeVideo video) {
  final String rawCategory = video.categoryId.trim();
  final Map<String, dynamic> data = <String, dynamic>{
    'id': video.id,
    'userId': video.creator.id,
    'creatorId': video.creator.id,
    'creator_id': video.creator.id,
    'creator_username': video.creator.username,
    'creator_display_name': video.creator.displayName,
    'category': rawCategory.isNotEmpty ? rawCategory : null,
    'categoryId': rawCategory.isNotEmpty ? rawCategory : null,
    'category_id': rawCategory.isNotEmpty ? rawCategory : null,
    'videoUrl': video.videoURL,
    'videoURL': video.videoURL,
    'hlsUrl': video.videoURL,
    'status': video.status,
    'visibility': video.visibility,
    'isDeleted': false,
  };
  final String categoryId = categoryIdFromVideoDocument(data);
  data['categoryId'] = categoryId;
  data['category'] = categoryId;
  data['category_id'] = categoryId;
  data['categoryName'] = categoryDisplayNameForId(categoryId);
  return data;
}

void logVideoCategoryFields(HomeVideo video) {
  if (!kDebugMode) {
    return;
  }
  final String raw = video.categoryId.trim();
  final String normalized = normalizeVideoCategorySlug(video);
  debugPrint(
    'VIDEO_CATEGORY '
    '${video.id} '
    'category=$raw '
    'categoryId=$normalized',
  );
}

void logDiscoverCategoryBucketAudit(List<HomeVideo> allVideos) {
  if (!kDebugMode) {
    return;
  }
  int gamingVideos = 0;
  int fpsVideos = 0;
  int generalVideos = 0;
  for (final HomeVideo video in allVideos) {
    final String slug = normalizeVideoCategorySlug(video);
    if (slug == 'gaming') {
      gamingVideos++;
    } else if (slug == 'fps') {
      fpsVideos++;
    } else if (slug == 'general') {
      generalVideos++;
    }
  }
  debugPrint(
    'DISCOVER_AUDIT '
    'total=${allVideos.length} '
    'gaming=$gamingVideos '
    'fps=$fpsVideos '
    'general=$generalVideos',
  );
}

void logDiscoverSkipHomeVideo({
  required HomeVideo video,
  required String reason,
}) {
  if (!kDebugMode) {
    return;
  }
  debugPrint(
    'DISCOVER_SKIP '
    'video=${video.id} '
    'reason=$reason '
    'category=${video.categoryId} '
    'categoryId=${normalizeVideoCategorySlug(video)} '
    'status=${video.status} '
    'playback=${video.videoURL.isNotEmpty}',
  );
}
