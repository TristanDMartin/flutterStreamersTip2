import '../utils/playback_teardown.dart';
import 'package:video_player/video_player.dart';

/// Applies queued focus once a registered controller becomes initialized.
class PlaybackPendingFocusCoordinator {
  const PlaybackPendingFocusCoordinator();

  Future<void> applyPendingFocusIfExists({
    required String videoId,
    required Map<String, String> pendingFocusRequests,
    required VideoPlayerController? Function(String videoId) resolveController,
    required bool Function(String videoId, VideoPlayerController controller)
        isControllerSafe,
    required Future<void> Function(String videoId, String owner) switchActiveTo,
    int retries = 0,
    void Function(String message)? log,
  }) async {
    const int maxRetries = 20;
    if (retries >= maxRetries) {
      log?.call('GPM focus-apply id=$videoId gave up after $maxRetries retries');
      pendingFocusRequests.remove(videoId);
      return;
    }

    final String? pendingOwner = pendingFocusRequests[videoId];
    if (pendingOwner == null) {
      return;
    }

    final VideoPlayerController? controller = resolveController(videoId);
    if (controller == null) {
      pendingFocusRequests.remove(videoId);
      return;
    }

    const int maxWaitMs = 1000;
    const int stepMs = 50;
    final int steps = maxWaitMs ~/ stepMs;
    for (int i = 0; i < steps; i++) {
      try {
        if (isControllerSafe(videoId, controller) &&
            controller.value.isInitialized &&
            !controller.value.hasError) {
          break;
        }
      } catch (e, st) {
        ignorePlaybackTeardownError('global_playback', e, st);
      }
      await Future<void>.delayed(const Duration(milliseconds: stepMs));
    }

    try {
      if (!isControllerSafe(videoId, controller) ||
          !controller.value.isInitialized ||
          controller.value.hasError) {
        log?.call(
          'GPM focus-apply id=$videoId deferred (not ready after '
          '${maxWaitMs}ms), retry ${retries + 1}/$maxRetries',
        );
        Future<void>.delayed(const Duration(milliseconds: 300), () {
          applyPendingFocusIfExists(
            videoId: videoId,
            pendingFocusRequests: pendingFocusRequests,
            resolveController: resolveController,
            isControllerSafe: isControllerSafe,
            switchActiveTo: switchActiveTo,
            retries: retries + 1,
            log: log,
          ).catchError((Object e) {
            log?.call('⚠️ PlaybackManager: Error in deferred pending focus: $e');
          });
        });
        return;
      }
    } catch (e) {
      log?.call('⚠️ PlaybackManager: pending focus apply failed: $e');
      Future<void>.delayed(const Duration(milliseconds: 300), () {
        applyPendingFocusIfExists(
          videoId: videoId,
          pendingFocusRequests: pendingFocusRequests,
          resolveController: resolveController,
          isControllerSafe: isControllerSafe,
          switchActiveTo: switchActiveTo,
          retries: retries + 1,
          log: log,
        ).catchError((Object err) {
          log?.call('⚠️ PlaybackManager: Error in deferred pending focus: $err');
        });
      });
      return;
    }

    pendingFocusRequests.remove(videoId);
    log?.call(
      'GPM focus-apply id=$videoId owner=$pendingOwner (ready after wait)',
    );
    await switchActiveTo(videoId, pendingOwner);
  }
}
