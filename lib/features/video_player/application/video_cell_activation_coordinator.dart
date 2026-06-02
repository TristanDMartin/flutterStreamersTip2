import 'package:video_player/video_player.dart';

enum VideoCellFocusAttemptOutcome {
  skippedNotMounted,
  skippedNotCurrent,
  skippedBlocked,
  skippedCannotPlay,
  queuedNoController,
  skippedDuplicate,
  requested,
}

enum VideoCellActivateOutcome {
  notEligible,
  requestedFocus,
  retryNoController,
  retryWhenBlocked,
  retryWhenOwnerActive,
}

/// Focus gating and activation orchestration for a feed video cell.
class VideoCellActivationCoordinator {
  const VideoCellActivationCoordinator();

  VideoCellFocusAttemptOutcome attemptRequestFocus({
    required bool mounted,
    required bool isDisposed,
    required bool isCurrentVideo,
    required String videoId,
    required String ownerKey,
    required bool hasRequestedFocusForVideo,
    required String? lastRequestedVideoId,
    required VideoPlayerController? pooledController,
    required VideoPlayerController? widgetController,
    required bool controllersMatchPool,
    required void Function(String reason) adoptFromPool,
    required bool isPlaybackBlocked,
    required bool canPlayOwner,
    required void Function(String videoId, String owner) setDesiredFocus,
    required String reason,
    void Function(String message)? log,
  }) {
    if (!mounted || isDisposed) {
      log?.call(
        '🚫 VideoPlayer: Skipping focus request ($reason) - widget not '
        'mounted or disposed: $videoId',
      );
      return VideoCellFocusAttemptOutcome.skippedNotMounted;
    }
    if (!isCurrentVideo) {
      log?.call(
        '🚫 VideoPlayer: Skipping focus request ($reason) - video not '
        'current: $videoId',
      );
      return VideoCellFocusAttemptOutcome.skippedNotCurrent;
    }
    if (isPlaybackBlocked) {
      log?.call(
        '🚫 VideoPlayer: Skipping focus request ($reason) - playback '
        'blocked: $videoId',
      );
      return VideoCellFocusAttemptOutcome.skippedBlocked;
    }
    if (!canPlayOwner) {
      log?.call(
        '🚫 VideoPlayer: Skipping focus request ($reason) - owner $ownerKey '
        'cannot play: $videoId',
      );
      return VideoCellFocusAttemptOutcome.skippedCannotPlay;
    }
    if (pooledController == null) {
      log?.call(
        'VVIEW focus id=$videoId reason=$reason controller=null (queuing)',
      );
      setDesiredFocus(videoId, ownerKey);
      return VideoCellFocusAttemptOutcome.queuedNoController;
    }
    if (widgetController == null || !controllersMatchPool) {
      adoptFromPool('attemptRequestFocus');
    }
    if (hasRequestedFocusForVideo && lastRequestedVideoId == videoId) {
      log?.call(
        '⏭️ VideoPlayer: Skipping focus request ($reason) - already requested '
        'for this video: $videoId',
      );
      return VideoCellFocusAttemptOutcome.skippedDuplicate;
    }
    log?.call('VVIEW focus id=$videoId reason=$reason');
    return VideoCellFocusAttemptOutcome.requested;
  }

  VideoCellActivateOutcome activateCurrentVideo({
    required bool mounted,
    required bool isDisposed,
    required bool isCurrentVideo,
    required String videoId,
    required String ownerKey,
    required bool allowRetry,
    required String reason,
    required VideoPlayerController? Function() resolveActiveController,
    required void Function(String reason) adoptFromPoolWhenEmpty,
    required bool isPlaybackBlocked,
    required bool canPlayOwner,
    required void Function(String videoId, String owner) setDesiredFocus,
    required void Function() cancelPendingRetrySubscription,
    required bool Function(String reason) runAttemptRequestFocus,
    void Function(String message)? log,
  }) {
    if (!mounted || isDisposed || !isCurrentVideo) {
      return VideoCellActivateOutcome.notEligible;
    }
    VideoPlayerController? controller = resolveActiveController();
    if (controller == null) {
      adoptFromPoolWhenEmpty('$reason: adopt');
      controller = resolveActiveController();
    }
    if (controller == null) {
      setDesiredFocus(videoId, ownerKey);
      if (allowRetry) {
        return VideoCellActivateOutcome.retryNoController;
      }
      return VideoCellActivateOutcome.notEligible;
    }
    if (isPlaybackBlocked) {
      if (allowRetry) {
        return VideoCellActivateOutcome.retryWhenBlocked;
      }
      return VideoCellActivateOutcome.notEligible;
    }
    if (!canPlayOwner) {
      setDesiredFocus(videoId, ownerKey);
      if (allowRetry) {
        return VideoCellActivateOutcome.retryWhenOwnerActive;
      }
      return VideoCellActivateOutcome.notEligible;
    }
    cancelPendingRetrySubscription();
    if (runAttemptRequestFocus(reason)) {
      return VideoCellActivateOutcome.requestedFocus;
    }
    return VideoCellActivateOutcome.notEligible;
  }
}
