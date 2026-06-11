/// Pagination hints when the feed was hydrated from cache / VideoService bootstrap.
abstract final class HomeFeedPagination {
  static const Map<String, dynamic> bootstrapCursor = <String, dynamic>{
    'bootstrap': true,
  };

  static const Map<String, dynamic> exhaustedCursor = <String, dynamic>{
    'exhausted': true,
  };

  static bool isExhausted(Map<String, dynamic>? cursor) {
    return cursor != null && cursor['exhausted'] == true;
  }

  static bool inferHasMoreContent({
    required int videoCount,
    Map<String, dynamic>? nextCursor,
  }) {
    if (videoCount == 0) {
      return false;
    }
    if (isExhausted(nextCursor)) {
      return false;
    }
    return true;
  }

  static Map<String, dynamic>? cursorForFeedUpdate({
    required int videoCount,
    Map<String, dynamic>? nextCursor,
  }) {
    if (isExhausted(nextCursor)) {
      return exhaustedCursor;
    }
    if (nextCursor != null) {
      return nextCursor;
    }
    if (videoCount == 0) {
      return null;
    }
    return bootstrapCursor;
  }
}
