import 'package:video_player/video_player.dart';

/// Tab-switch pause flag and resume-after-tab logic for playback.
class PlaybackTabLifecycleCoordinator {
  bool isPaused = false;

  void pauseForTabSwitch({
    required void Function() onPauseAll,
    void Function(String message)? log,
  }) {
    log?.call('🔄 PlaybackManager: Pausing all for tab switch');
    isPaused = true;
    onPauseAll();
  }

  void resumeAfterTabSwitch({
    required void Function() onRestoreFocus,
    required String? activeVideoId,
    required int blockLevel,
    required String? videoOwner,
    required bool Function(String owner) canPlayOwner,
    required VideoPlayerController? Function(String videoId) resolveController,
    required bool Function(String videoId, VideoPlayerController controller)
        isControllerSafe,
    required void Function(String videoId, bool isMuted) onMuteStateChanged,
    void Function(String message)? log,
  }) {
    log?.call('▶️ PlaybackManager: Resuming after tab switch');
    isPaused = false;
    onRestoreFocus();

    if (activeVideoId == null || blockLevel > 0) {
      log?.call(
        '🎵 PlaybackManager: No active video or blocked, waiting for focus request',
      );
      return;
    }

    if (videoOwner != null && !canPlayOwner(videoOwner)) {
      log?.call(
        '🚫 PlaybackManager: Cannot resume - owner $videoOwner is not active',
      );
      return;
    }

    final VideoPlayerController? controller = resolveController(activeVideoId);
    if (controller == null || !isControllerSafe(activeVideoId, controller)) {
      log?.call(
        '⚠️ PlaybackManager: Active video controller not available, '
        'waiting for focus request',
      );
      return;
    }

    try {
      controller.setVolume(1.0);
      onMuteStateChanged(activeVideoId, false);
      if (!controller.value.isPlaying) {
        controller.play();
        log?.call('▶️ PlaybackManager: Resumed active video $activeVideoId');
      } else {
        log?.call(
          '▶️ PlaybackManager: Active video $activeVideoId already playing',
        );
      }
    } catch (e) {
      log?.call('⚠️ PlaybackManager: Error resuming active video: $e');
    }
  }
}
