import 'package:video_player/video_player.dart';

import 'playback_focus_coordinator.dart';

/// Ducks or restores volume on the active pooled controller.
class PlaybackVolumeCoordinator {
  const PlaybackVolumeCoordinator();

  Future<void> setActiveVideoVolume({
    required double volume,
    required PlaybackFocusCoordinator focus,
    required Map<String, VideoPlayerController> controllerPool,
    required Map<String, String> controllerOwners,
    required Map<String, bool> muteStates,
    required bool Function(String videoId, VideoPlayerController controller)
        isControllerSafe,
    required void Function(
      String event, {
      String? videoId,
      String? owner,
      double? volume,
    }) onTelemetry,
    void Function(String message)? log,
  }) async {
    final String? activeId = focus.activeVideoId;
    if (activeId == null || focus.blockLevel > 0) {
      return;
    }
    final VideoPlayerController? controller = controllerPool[activeId];
    if (controller == null || !isControllerSafe(activeId, controller)) {
      return;
    }
    final double clampedVolume = volume.clamp(0.0, 1.0).toDouble();
    try {
      await controller.setVolume(clampedVolume);
      muteStates[activeId] = clampedVolume == 0.0;
      onTelemetry(
        'active_volume',
        videoId: activeId,
        owner: controllerOwners[activeId],
        volume: clampedVolume,
      );
    } catch (e) {
      log?.call('⚠️ PlaybackManager: Error setting active video volume: $e');
    }
  }
}
