import '../models/home_video.dart';

/// Mirrors `shouldCountPost` in [cloud_functions/index.js] — single ruleset for
/// app profile stats, reconcile, and website `users.postCount`.
const Set<String> kCountablePostStatuses = <String>{
  'ready',
  'published',
  'active',
};

const Set<String> kExcludedPostStatuses = <String>{
  'draft',
  'scheduled',
  'processing',
  'failed',
  'archived',
  'deleted',
  'hidden',
  'moderation',
  'private',
};

const Set<String> kCountablePostPrivacyLevels = <String>{
  'everyone',
  'connections',
  'public',
  'followers',
};

/// Keep in sync with website `PROFILE_VIDEOS_PAGE_SIZE`.
const int kProfileVideosPageSize = 30;

/// True when a Firestore video doc should increment [users.postCount].
bool videoCountsAsUserPost(Map<String, dynamic> data) {
  if (data['deleted'] == true || data['isDeleted'] == true) {
    return false;
  }
  if (data['visible'] == false) {
    return false;
  }
  final String status = (data['status'] as String? ?? 'draft').toLowerCase();
  if (!kCountablePostStatuses.contains(status)) {
    return false;
  }
  if (kExcludedPostStatuses.contains(status)) {
    return false;
  }
  final String privacy = _readPrivacyForPostCount(data);
  if (!kCountablePostPrivacyLevels.contains(privacy)) {
    return false;
  }
  return true;
}

bool homeVideoCountsAsUserPost(HomeVideo video) {
  if (video.isDraft) {
    return false;
  }
  return videoCountsAsUserPost(<String, dynamic>{
    'status': video.status,
    'privacy': _privacyFromHomeVideoVisibility(video.visibility),
    'visible': true,
    'isDeleted': video.isDeleted || video.status.toLowerCase() == 'deleted',
    'deleted': video.isDeleted || video.status.toLowerCase() == 'deleted',
    'deletedAt': video.deletedAt,
  });
}

String _readPrivacyForPostCount(Map<String, dynamic> data) {
  final String? privacy = (data['privacy'] as String?)?.trim();
  if (privacy != null && privacy.isNotEmpty) {
    return privacy.toLowerCase();
  }
  final String? visibility = (data['visibility'] as String?)?.trim();
  if (visibility != null && visibility.isNotEmpty) {
    return _privacyFromHomeVideoVisibility(visibility);
  }
  return 'private';
}

String _privacyFromHomeVideoVisibility(String visibility) {
  final String lower = visibility.toLowerCase();
  switch (lower) {
    case 'public':
      return 'public';
    case 'followers':
      return 'followers';
    case 'connections':
      return 'connections';
    case 'everyone':
      return 'everyone';
    default:
      return lower;
  }
}

/// Canonical displayed post count — keep in sync with website
/// `resolveDisplayedPostCount` in lib/video/profileVideos.ts.
int resolveDisplayedPostCount({
  required int loadedVideoCount,
  required bool feedLoading,
  required bool hasMore,
  required int storedCount,
  int? totalCountFromApi,
}) {
  if (feedLoading) {
    return storedCount;
  }
  if (totalCountFromApi != null) {
    return totalCountFromApi;
  }
  if (!hasMore) {
    return loadedVideoCount;
  }
  if (loadedVideoCount < kProfileVideosPageSize) {
    return loadedVideoCount;
  }
  return storedCount;
}

/// Profile/Streamer hero override. Returns null so [UserStatsRow] keeps the
/// live doc counter while the feed is still priming.
int? resolvePostsCountOverride({
  required List<HomeVideo> userVideos,
  required List<HomeVideo> allVideos,
  required bool isVideoServiceLoading,
  int storedCount = 0,
}) {
  final bool feedPriming =
      userVideos.isEmpty && (isVideoServiceLoading || allVideos.isEmpty);
  if (feedPriming) {
    return null;
  }
  final int loadedCountable =
      userVideos.where(homeVideoCountsAsUserPost).length;
  // Approximate hasMore: still loading a full page+ of this user's videos.
  final bool hasMore =
      isVideoServiceLoading && loadedCountable >= kProfileVideosPageSize;
  return resolveDisplayedPostCount(
    loadedVideoCount: loadedCountable,
    feedLoading: false,
    hasMore: hasMore,
    storedCount: storedCount > 0 ? storedCount : loadedCountable,
  );
}
