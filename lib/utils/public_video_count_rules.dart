import 'post_count_rules.dart';
import 'video_document_rules.dart';
import 'video_health_gate.dart';
import 'video_url_resolver.dart';

/// Same rules as website `users.postCount` (see [videoCountsAsUserPost]).
bool videoCountsAsPublicPostForStats(Map<String, dynamic> data) {
  if (data['isDraft'] == true) {
    return false;
  }
  return videoCountsAsUserPost(data);
}

bool videoIsPublicFeedVisible(Map<String, dynamic> data) {
  return isVideoEligibleForPublicFeed(data);
}

/// Owner matches [userId] using the same owner keys as [getOwnerId].
bool videoOwnerIsUser(Map<String, dynamic> data, String userId) {
  final String? owner = getOwnerId(data);
  return owner != null && owner == userId;
}

/// Matches [VideoService] — skips videos with no playable URL (same as feed grid).
Future<bool> videoIsPlayableForProfileCount(
  String videoId,
  Map<String, dynamic> data,
) async {
  final String url = resolveVideoUrl(data);
  final VideoPlayableResult result =
      await VideoHealthGate.instance.resolvePlayableSource(
    videoId,
    cachedData: data,
    fallbackUrl: url.isEmpty ? null : url,
  );
  return result is Playable;
}
