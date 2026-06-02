import '../../../models/home_video.dart';
import '../../../services/video_service.dart' as video_service;

/// Fresh videos produced by a background VideoService refresh.
class HomeFeedBackgroundRefreshVideos {
  const HomeFeedBackgroundRefreshVideos({
    required this.videos,
  });

  final List<HomeVideo> videos;
}

/// Refreshes home feed data and runs post-load engagement sync.
class HomeFeedBackgroundRefreshCoordinator {
  HomeFeedBackgroundRefreshCoordinator({
    required video_service.VideoService videoService,
    this.engagementSyncTimeout = const Duration(seconds: 5),
    void Function(String message)? log,
  })  : _videoService = videoService,
        _log = log ?? _noopLog;

  final video_service.VideoService _videoService;
  final Duration engagementSyncTimeout;
  final void Function(String message) _log;

  Future<HomeFeedBackgroundRefreshVideos?> fetchRefreshedVideos() async {
    await _videoService.refresh();
    final List<HomeVideo> freshVideos = _videoService.getAllVideos();
    if (freshVideos.isEmpty) {
      return null;
    }
    _log(
      '✅ Background refresh: ${freshVideos.length} videos (incl. new uploads)',
    );
    return HomeFeedBackgroundRefreshVideos(videos: freshVideos);
  }

  Future<void> syncEngagementStates({
    required Future<void> Function() syncLikeStates,
    required Future<void> Function() syncFavoriteStates,
    required Future<void> Function() syncCommentCounts,
  }) async {
    await Future.wait(<Future<void>>[
      syncLikeStates(),
      syncFavoriteStates(),
      syncCommentCounts(),
    ]).timeout(engagementSyncTimeout);
    _log('✅ Video states synced successfully');
  }

  static void _noopLog(String message) {}
}
