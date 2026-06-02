import 'package:video_player/video_player.dart';

import 'playback_focus_coordinator.dart';

/// Single active owner: pause non-matching pool entries and publish owner.
class PlaybackActiveOwnerCoordinator {
  const PlaybackActiveOwnerCoordinator();

  void setActiveOwner({
    required String owner,
    required PlaybackFocusCoordinator focus,
    required Map<String, VideoPlayerController> controllerPool,
    required Map<String, String> controllerOwners,
    required Map<String, bool> muteStates,
    required bool Function(String videoId, VideoPlayerController controller)
        isControllerSafe,
    void Function(String message)? log,
  }) {
    if (!focus.ownerMatchesVisibleOwner(owner)) {
      log?.call(
        '🚫 PlaybackManager: Ignoring active owner $owner; '
        'visible owner is ${focus.visibleOwner}',
      );
      return;
    }
    log?.call('🎯 PlaybackManager: Setting active owner to: $owner');
    if (focus.clearBlockOnOwnerSwitch()) {
      log?.call(
        '🎯 PlaybackManager: Clearing stale block (level: 0, reason: cleared) '
        'when switching owner to $owner',
      );
    }
    final List<MapEntry<String, VideoPlayerController>> entries =
        List<MapEntry<String, VideoPlayerController>>.from(
      controllerPool.entries,
    );
    for (final MapEntry<String, VideoPlayerController> entry in entries) {
      final String videoId = entry.key;
      final String? controllerOwner = controllerOwners[videoId];
      final bool belongsToActiveOwner = controllerOwner != null &&
          focus.controllerBelongsToOwner(controllerOwner, owner);
      if (belongsToActiveOwner) {
        continue;
      }
      try {
        if (isControllerSafe(videoId, entry.value)) {
          entry.value.setVolume(0.0);
          muteStates[videoId] = true;
          if (entry.value.value.isInitialized) {
            entry.value.pause();
          }
          log?.call(
            '⏸️ PlaybackManager: Paused and muted video $videoId '
            '(owner: $controllerOwner, activeOwner: $owner)',
          );
        }
      } catch (e) {
        log?.call(
          '⚠️ PlaybackManager: Error pausing non-active owner video: $e',
        );
      }
    }
    focus.publishActiveOwner(owner);
    log?.call(
      '✅ PlaybackManager: Active owner set to: $owner '
      '(blockLevel: ${focus.blockLevel})',
    );
  }
}
