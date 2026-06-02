import 'package:video_player/video_player.dart';

/// Pauses and mutes every controller in the pool (mute-first ordering).
class PlaybackPauseAllCoordinator {
  const PlaybackPauseAllCoordinator();

  void pauseAll({
    required Map<String, VideoPlayerController> controllerPool,
    required Map<String, bool> muteStates,
    required void Function(String videoId) onControllerUnsafeRemove,
    required bool Function(String videoId, VideoPlayerController controller)
        isControllerSafe,
    required void Function(VideoPlayerController? controller)
        setCurrentlyPlayingController,
    void Function(String message)? log,
  }) {
    log?.call('⏸️ PlaybackManager: Pausing and muting ALL videos');
    setCurrentlyPlayingController(null);
    final List<MapEntry<String, VideoPlayerController>> entries =
        List<MapEntry<String, VideoPlayerController>>.from(
      controllerPool.entries,
    );
    int pausedCount = 0;
    int mutedCount = 0;
    for (final MapEntry<String, VideoPlayerController> entry in entries) {
      final String videoId = entry.key;
      final VideoPlayerController controller = entry.value;
      try {
        if (!isControllerSafe(videoId, controller)) {
          log?.call(
            '⚠️ PlaybackManager: Controller for video $videoId is not safe',
          );
          continue;
        }
        try {
          controller.setVolume(0.0);
          muteStates[videoId] = true;
          mutedCount++;
          if (controller.value.isInitialized) {
            controller.pause();
            pausedCount++;
          }
          log?.call('⏸️ PlaybackManager: Paused and muted video $videoId');
        } catch (e) {
          log?.call(
            '❌ PlaybackManager: Error pausing video $videoId '
            '(controller disposed): $e',
          );
          onControllerUnsafeRemove(videoId);
        }
      } catch (e) {
        log?.call('❌ PlaybackManager: Error pausing video $videoId: $e');
      }
    }
    log?.call(
      '✅ PlaybackManager: Paused $pausedCount videos, muted $mutedCount videos',
    );
  }
}
