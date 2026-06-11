import 'package:video_player/video_player.dart';

import '../constants/playback_owners.dart';
import '../models/home_video.dart';
import '../utils/video_health_gate.dart';
import 'playback_controller_pool.dart';
import 'playback_loop_coordinator.dart';

/// Warms a controller for a feed index (health gate + pool + optional seek).
class PlaybackEnsureReadyCoordinator {
  const PlaybackEnsureReadyCoordinator();

  Future<void> ensureControllerReady({
    required int index,
    required HomeVideo video,
    required PlaybackControllerPool pool,
    required Set<String> initializingControllers,
    required Map<int, Duration> lastKnownPositions,
    required bool Function(String videoId, VideoPlayerController controller)
        isControllerSafe,
    required Future<VideoPlayerController?> Function(String videoId)
        waitForInitializing,
    required Future<VideoPlayableResult> Function(
      String videoId, {
      String? fallbackUrl,
    }) resolvePlayableSource,
    required Future<VideoPlayerController?> Function(
      String videoId,
      String url, {
      String? owner,
    }) getOrCreateController,
    required void Function(int index, String videoId) syncFeedIndexMapping,
    String controllerOwner = PlaybackOwners.home,
    void Function(String message)? log,
  }) async {
    if (index < 0) {
      log?.call('⚠️ PlaybackManager: Invalid index $index, returning early');
      return;
    }
    if (video.id.isEmpty || video.videoURL.isEmpty) {
      log?.call(
        '⚠️ PlaybackManager: Invalid video object: id=${video.id}, '
        'url=${video.videoURL}, returning early',
      );
      return;
    }
    final String videoId = video.id;
    VideoPlayerController? controller = pool[videoId];
    if (controller != null && isControllerSafe(videoId, controller)) {
      try {
        if (controller.value.isInitialized && !controller.value.hasError) {
          log?.call(
            '✅ PlaybackManager: Controller already ready for index $index',
          );
          return;
        }
      } catch (e) {
        log?.call('⚠️ PlaybackManager: Error checking controller state: $e');
      }
    }
    if (initializingControllers.contains(videoId)) {
      log?.call(
        '⚠️ PlaybackManager: Controller for $videoId is already being '
        'initialized, waiting...',
      );
      final VideoPlayerController? existing =
          await waitForInitializing(videoId);
      if (existing != null) {
        log?.call('✅ PlaybackManager: Controller became ready during wait');
      }
      return;
    }
    log?.call(
      '🔄 PlaybackManager: Ensuring controller for index $index, video $videoId',
    );
    final VideoPlayableResult healthResult = await resolvePlayableSource(
      videoId,
      fallbackUrl: video.videoURL.isNotEmpty ? video.videoURL : null,
    );
    if (healthResult is Unplayable) {
      log?.call(
        '⚠️ PlaybackManager: Video $videoId unplayable: ${healthResult.reason}',
      );
      return;
    }
    final String playableUrl = (healthResult as Playable).url;
    try {
      controller = await getOrCreateController(
        videoId,
        playableUrl,
        owner: controllerOwner,
      );
      if (controller == null) {
        return;
      }
      syncFeedIndexMapping(index, videoId);
      Duration? lastPos = lastKnownPositions[index];
      if (lastPos != null && lastPos > Duration.zero) {
        final Duration duration = controller.value.duration;
        lastPos = PlaybackLoopCoordinator.clampResumePosition(
          lastPos,
          duration,
        );
      }
      if (lastPos != null && lastPos > Duration.zero) {
        try {
          await controller.seekTo(lastPos).timeout(
            const Duration(seconds: 2),
            onTimeout: () {
              log?.call('⏱️ PlaybackManager: Seek timeout for $videoId');
            },
          );
          log?.call(
            '⏪ PlaybackManager: Seeked to last position ${lastPos.inSeconds}s',
          );
        } catch (e) {
          log?.call(
            '⚠️ PlaybackManager: Error seeking to last position: $e',
          );
        }
      }
      log?.call('✅ PlaybackManager: Controller ready for index $index');
    } catch (e, stackTrace) {
      log?.call('❌ PlaybackManager: Error creating controller: $e');
      log?.call('Stack trace: $stackTrace');
    }
  }
}
