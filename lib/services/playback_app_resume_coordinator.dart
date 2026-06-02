import 'package:video_player/video_player.dart';

import '../constants/playback_owners.dart';
import 'playback_focus_coordinator.dart';

/// Restores focus after app resume (unblock + active owner + requestFocus).
class PlaybackAppResumeCoordinator {
  const PlaybackAppResumeCoordinator();

  Future<void> recoverInteractionOnAppResume({
    required PlaybackFocusCoordinator focus,
    required Map<String, VideoPlayerController> controllerPool,
    required Map<String, String> controllerOwners,
    required void Function() forceUnblock,
    required void Function(String owner) setActiveOwner,
    required Future<void> Function(String keepVideoId) pauseAllExcept,
    required Future<void> Function(String videoId, String owner) requestFocus,
    required bool Function(String videoId, VideoPlayerController controller)
        isControllerSafe,
    String fallbackOwner = PlaybackOwners.home,
    void Function(String message)? log,
  }) async {
    log?.call('🧯 PlaybackManager: Recovering interaction state on app resume');
    forceUnblock();
    final String? activeId = focus.activeVideoId;
    final String owner = activeId != null
        ? (controllerOwners[activeId] ?? fallbackOwner)
        : fallbackOwner;
    if (focus.activeOwner == null || focus.activeOwner != owner) {
      setActiveOwner(owner);
    }
    if (activeId == null) {
      return;
    }
    final VideoPlayerController? controller = controllerPool[activeId];
    if (controller == null || !isControllerSafe(activeId, controller)) {
      focus.queuePendingFocus(activeId, owner);
      focus.publishActiveVideo(activeId);
      return;
    }
    await pauseAllExcept(activeId);
    await requestFocus(activeId, owner);
  }
}
