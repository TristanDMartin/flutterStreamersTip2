import 'package:video_player/video_player.dart';

import 'playback_controller_pool.dart';
import 'playback_focus_coordinator.dart';

/// Activates a single video: [requestFocus] and [switchActiveTo].
class PlaybackFocusActivationCoordinator {
  const PlaybackFocusActivationCoordinator();

  Future<void> switchActiveTo({
    required String newVideoId,
    required String owner,
    required int activationEpoch,
    required int Function() bumpActivationEpoch,
    required bool Function(int epoch) isStaleEpoch,
    required PlaybackFocusCoordinator focus,
    required PlaybackControllerPool pool,
    required Map<String, String> controllerOwners,
    required Map<String, bool> muteStates,
    required VideoPlayerController? Function() getCurrentlyPlayingController,
    required void Function(VideoPlayerController? controller)
        setCurrentlyPlayingController,
    required bool Function(String owner) ownerMatchesVisible,
    required void Function(String owner) setActiveOwner,
    required bool Function(String owner) canPlay,
    required Future<void> Function(String keepVideoId) muteAllExcept,
    required Future<void> Function(VideoPlayerController controller)
        safePauseAndMute,
    required Future<void> Function(VideoPlayerController controller)
        ensurePlayingUnmuted,
    required bool Function(String videoId, VideoPlayerController controller)
        isControllerSafe,
    void Function(String message)? log,
  }) async {
    final int myEpoch = bumpActivationEpoch();
    log?.call('GPM switch start id=$newVideoId owner=$owner epoch=$myEpoch');

    if (!ownerMatchesVisible(owner)) {
      final VideoPlayerController? c = pool[newVideoId];
      if (c != null && isControllerSafe(newVideoId, c)) {
        await safePauseAndMute(c);
        muteStates[newVideoId] = true;
      }
      log?.call(
        '🚫 PlaybackManager: switchActiveTo denied for owner $owner '
        '(visibleOwner: ${focus.visibleOwner})',
      );
      return;
    }

    if (focus.blockLevel == 0 && focus.activeOwner != owner) {
      log?.call(
        '🎯 PlaybackManager: Switching active owner from ${focus.activeOwner} '
        'to $owner',
      );
      setActiveOwner(owner);
    }

    if (!canPlay(owner)) {
      final VideoPlayerController? c = pool[newVideoId];
      if (c != null && isControllerSafe(newVideoId, c)) {
        await safePauseAndMute(c);
        muteStates[newVideoId] = true;
      }
      log?.call('🚫 PlaybackManager: switchActiveTo denied for owner $owner');
      return;
    }

    final VideoPlayerController? controller = pool[newVideoId];
    if (controller == null || !isControllerSafe(newVideoId, controller)) {
      controllerOwners[newVideoId] = owner;
      focus.publishActiveSession(videoId: newVideoId, owner: owner);
      log?.call(
        'GPM focus-queued id=$newVideoId (missing/unsafe in switchActiveTo)',
      );
      focus.queuePendingFocus(newVideoId, owner);
      return;
    }

    if (focus.activeVideoId == newVideoId &&
        controllerOwners[newVideoId] == owner) {
      await muteAllExcept(newVideoId);
      if (isStaleEpoch(myEpoch)) {
        log?.call(
          'GPM switch abort id=$newVideoId epoch=$myEpoch (stale after mute)',
        );
        return;
      }
      await ensurePlayingUnmuted(controller);
      return;
    }

    await muteAllExcept(newVideoId);
    if (isStaleEpoch(myEpoch)) {
      log?.call(
        'GPM switch abort id=$newVideoId epoch=$myEpoch (stale after muteAll)',
      );
      return;
    }

    final VideoPlayerController? previousPlaying =
        getCurrentlyPlayingController();
    if (previousPlaying != null && !identical(previousPlaying, controller)) {
      await safePauseAndMute(previousPlaying);
    }
    setCurrentlyPlayingController(null);

    focus.publishActiveVideo(newVideoId);
    controllerOwners[newVideoId] = owner;

    if (!isControllerSafe(newVideoId, controller)) {
      log?.call(
        '⚠️ PlaybackManager: Controller became unsafe for $newVideoId after '
        'mute-all',
      );
      return;
    }

    await ensurePlayingUnmuted(controller);
    log?.call('GPM switch end id=$newVideoId epoch=$myEpoch');
  }

  Future<void> requestFocus({
    required String videoId,
    required String owner,
    required PlaybackFocusCoordinator focus,
    required Map<String, String> pendingFocusRequests,
    required PlaybackControllerPool pool,
    required Map<String, String> controllerOwners,
    required Map<String, bool> muteStates,
    required VideoPlayerController? Function() getCurrentlyPlayingController,
    required bool Function(String owner) ownerMatchesVisible,
    required void Function(String owner) setActiveOwner,
    required bool Function(String owner) canPlay,
    required void Function() pauseAll,
    required Future<void> Function(String keepVideoId) muteAllExcept,
    required Future<void> Function(String videoId, String owner) switchActiveTo,
    required Future<void> Function(VideoPlayerController controller)
        safePauseAndMute,
    required Future<void> Function(VideoPlayerController controller)
        ensurePlayingUnmuted,
    required bool Function(String videoId, VideoPlayerController controller)
        isControllerSafe,
    void Function(String message)? log,
  }) async {
    if (focus.activeVideoId == videoId &&
        focus.activeOwner == owner &&
        pendingFocusRequests[videoId] == owner) {
      log?.call(
        '🎯 PlaybackManager: Duplicate focus request ignored for $videoId',
      );
      return;
    }
    final VideoPlayerController? currentlyPlaying =
        getCurrentlyPlayingController();
    if (focus.activeVideoId == videoId &&
        focus.activeOwner == owner &&
        currentlyPlaying != null) {
      final VideoPlayerController? controller = pool[videoId];
      if (controller != null &&
          identical(controller, currentlyPlaying) &&
          isControllerSafe(videoId, controller)) {
        if (!controller.value.isPlaying) {
          log?.call(
            '🎯 PlaybackManager: Active but paused — force play for $videoId',
          );
          await ensurePlayingUnmuted(controller);
          return;
        }
        log?.call('🎯 PlaybackManager: Focus already active for $videoId');
        return;
      }
    }
    log?.call('🎯 PlaybackManager: Requesting focus for $videoId from $owner');

    if (!ownerMatchesVisible(owner)) {
      final VideoPlayerController? controller = pool[videoId];
      if (controller != null && isControllerSafe(videoId, controller)) {
        await safePauseAndMute(controller);
        muteStates[videoId] = true;
      }
      log?.call(
        '🚫 PlaybackManager: Ignoring focus for owner $owner '
        '(visibleOwner: ${focus.visibleOwner})',
      );
      return;
    }

    if (focus.activeOwner == null) {
      log?.call(
        '🔧 PlaybackManager: Active owner is null, auto-setting to $owner for '
        'instant playback',
      );
      setActiveOwner(owner);
    } else if (focus.blockLevel == 0 && focus.activeOwner != owner) {
      log?.call(
        '🎯 PlaybackManager: requestFocus switching owner from '
        '${focus.activeOwner} to $owner',
      );
      setActiveOwner(owner);
    }

    if (!canPlay(owner)) {
      log?.call(
        '🚫 PlaybackManager: Owner $owner cannot play, not requesting focus '
        '(activeOwner: ${focus.activeOwner}, blockLevel: ${focus.blockLevel})',
      );
      pauseAll();
      return;
    }

    final VideoPlayerController? controller = pool[videoId];
    if (controller == null || !isControllerSafe(videoId, controller)) {
      controllerOwners[videoId] = owner;
      focus.publishActiveSession(videoId: videoId, owner: owner);
      log?.call(
        'GPM focus-queued id=$videoId owner=$owner (pooled? false safe? false)',
      );
      focus.queuePendingFocus(videoId, owner);
      return;
    }

    log?.call('GPM focus id=$videoId owner=$owner pooled? true safe? true');
    await switchActiveTo(videoId, owner);
  }
}
