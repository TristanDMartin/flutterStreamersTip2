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
    'isDeleted': video.status.toLowerCase() == 'deleted',
    'deleted': video.status.toLowerCase() == 'deleted',
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

int? resolvePostsCountOverride({
  required List<HomeVideo> userVideos,
  required List<HomeVideo> allVideos,
  required bool isVideoServiceLoading,
}) {
  if (userVideos.isEmpty &&
      (isVideoServiceLoading || allVideos.isEmpty)) {
    return null;
  }
  return userVideos.where(homeVideoCountsAsUserPost).length;
}
