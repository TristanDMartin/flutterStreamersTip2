import 'video_health_gate.dart';
import 'video_url_resolver.dart';

/// Same “public + active + feed-ready” gates as [VideoService] when building
/// the home feed. Unplayable URLs are handled separately via
/// [videoIsPlayableForProfileCount].
bool videoCountsAsPublicPostForStats(Map<String, dynamic> data) {
  if (data['deleted'] == true || data['isDeleted'] == true) {
    return false;
  }
  if (data['isDraft'] == true) {
    return false;
  }
  final String? status = data['status'] as String?;
  final bool isActiveStatus = status == 'active' ||
      status == 'published' ||
      status == 'ready';
  if (!isActiveStatus) {
    return false;
  }
  if (data['isReadyForFeed'] == false) {
    return false;
  }
  final String? visibility = data['visibility'] as String?;
  final String? privacy = data['privacy'] as String?;
  final bool isPublic = visibility == 'public' ||
      privacy == 'Everyone' ||
      privacy == 'Public' ||
      (visibility == null && privacy == null);
  return isPublic;
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
