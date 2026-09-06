import '../../../models/home_video.dart';
import '../../../services/algorithm_cache_service.dart';
import '../../../services/public_profile_firestore.dart';
import '../../../utils/home_video_playback.dart';
import '../../../utils/video_document_rules.dart';
import '../domain/home_feed_processing.dart';

/// Disk/memory warm-cache helpers for the home For You feed.
class HomeFeedWarmCache {
  HomeFeedWarmCache(this._cacheService);

  final AlgorithmCacheService _cacheService;

  CachedFeedResult? peekForYouFromMemory() {
    return _cacheService.peekForYouWarmFeed();
  }

  Future<CachedFeedResult?> loadForYouFeed(String? userId) async {
    CachedFeedResult? cachedFeed;
    if (userId != null) {
      cachedFeed = await _cacheService.getCachedForYouFeed(userId);
    }
    cachedFeed ??= await _cacheService.getLastKnownForYouFeed();
    if (cachedFeed == null || cachedFeed.videos.isEmpty) {
      return null;
    }
    final List<HomeVideo> playable = _remotePlayableOnly(cachedFeed.videos);
    final Set<String> ownerIds = playable
        .map((HomeVideo video) => video.creator.id.trim())
        .where((String id) => id.isNotEmpty)
        .toSet();
    final Set<String> renderableOwnerIds =
        await PublicProfileFirestore.instance.filterExistingIds(ownerIds);
    final List<HomeVideo> visible = keepHomeVideosWithRenderableOwners(
      videos: playable,
      renderableOwnerIds: renderableOwnerIds,
    );
    if (visible.isEmpty) {
      return null;
    }
    return CachedFeedResult(
      videos: visible,
      nextCursor: cachedFeed.nextCursor,
    );
  }

  Future<void> saveForYouFeed({
    required String userId,
    required List<HomeVideo> videos,
    Map<String, dynamic>? nextCursor,
  }) async {
    final List<HomeVideo> playable = _remotePlayableOnly(videos);
    if (playable.isEmpty) {
      return;
    }
    final List<HomeVideo> visibleVideos =
        playable.take(30).toList(growable: false);
    await _cacheService.cacheForYouFeed(
      userId: userId,
      videos: visibleVideos,
      nextCursor: sanitizeCursor(nextCursor),
    );
    await _cacheService.cacheLastKnownForYouFeed(videos: visibleVideos);
  }

  /// Never warm-cache Instant Play locals, deleted, or empty/broken URLs.
  static List<HomeVideo> remotePlayableOnly(List<HomeVideo> videos) {
    return videos
        .where(
          (HomeVideo video) =>
              !video.isDeleted &&
              isHomeVideoVisibleInFeed(video) &&
              !isHomeVideoOwnerPendingLocal(video) &&
              !isHomeVideoLocalFileUrl(video.videoURL) &&
              isHomeVideoPlayable(video) &&
              video.videoURL.trim().startsWith('http'),
        )
        .toList(growable: false);
  }

  static List<HomeVideo> _remotePlayableOnly(List<HomeVideo> videos) {
    return remotePlayableOnly(videos);
  }

  static Map<String, dynamic>? sanitizeCursor(Map<String, dynamic>? cursor) {
    if (cursor == null) {
      return null;
    }
    final Map<String, dynamic> safeCursor = <String, dynamic>{};
    for (final MapEntry<String, dynamic> entry in cursor.entries) {
      final Object? value = entry.value;
      if (value == null || value is String || value is num || value is bool) {
        safeCursor[entry.key] = value;
      }
    }
    return safeCursor.isEmpty ? null : safeCursor;
  }
}
