import '../../../models/home_video.dart';

/// Aggregated counters for For You feed load diagnostics.
class FeedStats {
  FeedStats({
    required this.fetched,
    required this.rejectedPreHydration,
    required this.hydrated,
    required this.skippedDuringHydration,
    required this.skipReasons,
    this.ranked,
    this.poolSize,
    this.activeControllers,
  });

  final int fetched;
  final int rejectedPreHydration;
  final int hydrated;
  final int skippedDuringHydration;
  final Map<String, int> skipReasons;
  final int? ranked;
  final int? poolSize;
  final int? activeControllers;

  int get filtered => rejectedPreHydration + skippedDuringHydration;
  int get visible => hydrated;

  void logTo(void Function(String message) log) {
    log(
      '📊 FeedStats: fetched=$fetched, rejectedPreHydration=$rejectedPreHydration, '
      'skippedDuringHydration=$skippedDuringHydration, visible=$visible',
    );
    if (skipReasons.isNotEmpty) {
      log('📊 FeedStats skipReasons: $skipReasons');
    }
    if (ranked != null) {
      log('📊 FeedStats ranked=$ranked');
    }
    if (poolSize != null || activeControllers != null) {
      log(
        '📊 FeedStats playback poolSize=$poolSize '
        'activeControllers=$activeControllers',
      );
    }
  }
}

/// Uploads newer than this stay at the front of the feed regardless of diversity.
const Duration kFreshUploadBoostWindow = Duration(minutes: 30);

bool isFreshUpload(HomeVideo video, {DateTime? now}) {
  final DateTime? createdAt = video.createdAt?.toDate();
  if (createdAt == null) {
    return false;
  }
  final DateTime clock = now ?? DateTime.now();
  return clock.difference(createdAt) <= kFreshUploadBoostWindow;
}
