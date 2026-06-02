import '../../../models/home_video.dart';
import '../../../services/algorithm_cache_service.dart';

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
    return cachedFeed;
  }

  Future<void> saveForYouFeed({
    required String userId,
    required List<HomeVideo> videos,
    Map<String, dynamic>? nextCursor,
  }) async {
    if (videos.isEmpty) {
      return;
    }
    final List<HomeVideo> visibleVideos =
        videos.take(30).toList(growable: false);
    await _cacheService.cacheForYouFeed(
      userId: userId,
      videos: visibleVideos,
      nextCursor: sanitizeCursor(nextCursor),
    );
    await _cacheService.cacheLastKnownForYouFeed(videos: visibleVideos);
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
