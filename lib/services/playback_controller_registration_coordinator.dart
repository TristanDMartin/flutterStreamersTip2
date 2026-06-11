import 'dart:async';

import 'package:video_player/video_player.dart';

import '../utils/playback_teardown.dart';
import 'playback_controller_pool.dart';
import 'playback_focus_coordinator.dart';
import 'playback_pool_policy.dart';
import 'playback_warm_window_policy.dart';

/// Registers and unregisters pooled controllers with deferred native teardown.
class PlaybackControllerRegistrationCoordinator {
  const PlaybackControllerRegistrationCoordinator();

  static const int poolRadius = 1;
  static const int maxControllerPoolSize =
      PlaybackPoolPolicy.maxControllerPoolSize;

  void registerController({
    required String videoId,
    required VideoPlayerController controller,
    required PlaybackControllerPool pool,
    required PlaybackFocusCoordinator focus,
    required Map<String, bool> muteStates,
    required Map<String, int> videoIdToIndex,
    required int? currentFeedIndex,
    required bool Function(String id, VideoPlayerController c, DateTime now)
        canEvict,
    required bool Function(String videoId, VideoPlayerController controller)
        isControllerSafe,
    required void Function(
      String event,
      String videoId, {
      int? controllerId,
      String? reason,
    }) onLogControllerEvent,
    required void Function(String videoId) onUnregister,
    required void Function(String videoId) onApplyPendingFocus,
    required VideoPlayerController? Function() getCurrentlyPlayingController,
    required void Function(VideoPlayerController? controller)
        setCurrentlyPlayingController,
    required void Function({
      required String videoId,
      required VideoPlayerController controller,
      required PlaybackControllerPool pool,
      required bool Function(String videoId, VideoPlayerController controller)
          isControllerSafe,
      void Function(String message)? log,
    }) scheduleDeferredPoolControllerDispose,
    String? owner,
    int scrollDirection = 1,
    void Function(String message)? log,
  }) {
    onLogControllerEvent(
      'REGISTER_CONTROLLER',
      videoId,
      controllerId: controller.hashCode,
      reason: 'explicit_register',
    );

    pool.prepareForRegister(videoId);

    final VideoPlayerController? oldController = pool[videoId];
    if (oldController != null && !identical(oldController, controller)) {
      final bool oldAttached = pool.isAttachedTo(videoId, oldController);
      if (oldAttached) {
        onUnregister(videoId);
        log?.call(
          '📌 PlaybackManager: Replaced attached controller for $videoId '
          'with view\'s new controller',
        );
      } else {
        if (isControllerSafe(videoId, oldController)) {
          try {
            oldController.setVolume(0.0);
            oldController.pause();
          } catch (e) {
            log?.call('⚠️ PlaybackManager: Error pausing old controller: $e');
          }
        }
        pool.removePoolEntry(videoId);
        muteStates.remove(videoId);
        if (identical(getCurrentlyPlayingController(), oldController)) {
          setCurrentlyPlayingController(null);
        }
        scheduleDeferredPoolControllerDispose(
          videoId: videoId,
          controller: oldController,
          pool: pool,
          isControllerSafe: isControllerSafe,
          log: log,
        );
      }
    }

    pool.disposed.remove(videoId);

    if (pool.length >= maxControllerPoolSize && !pool.containsKey(videoId)) {
      log?.call(
        '⚠️ PlaybackManager: Pool size limit reached (${pool.length}/'
        '$maxControllerPoolSize), trimming outside warm window before '
        'adding new one',
      );
      final List<String> controllersToDispose = <String>[];
      final DateTime nowForRegister = DateTime.now();
      for (final MapEntry<String, VideoPlayerController> entry
          in pool.entries) {
        final String id = entry.key;
        final int? videoIndex = videoIdToIndex[id];
        final bool outsideWarmWindow = currentFeedIndex == null ||
            videoIndex == null ||
            PlaybackWarmWindowPolicy.isOutsideWarmWindow(
              videoIndex: videoIndex,
              currentIndex: currentFeedIndex,
              direction: scrollDirection,
            );
        if (!outsideWarmWindow) {
          continue;
        }
        if (canEvict(id, entry.value, nowForRegister)) {
          controllersToDispose.add(id);
        }
      }
      for (final String id in controllersToDispose) {
        log?.call(
            '🗑️ PlaybackManager: Evicting controller $id to prevent OOM');
        onUnregister(id);
      }

      if (pool.length >= maxControllerPoolSize) {
        final overflowEntries = pool.entries.where((entry) {
          final String id = entry.key;
          final int? videoIndex = videoIdToIndex[id];
          final bool outsideWarmWindow = currentFeedIndex == null ||
              videoIndex == null ||
              PlaybackWarmWindowPolicy.isOutsideWarmWindow(
                videoIndex: videoIndex,
                currentIndex: currentFeedIndex,
                direction: scrollDirection,
              );
          if (!outsideWarmWindow) return false;
          if (focus.activeVideoId == id || pool.initializing.contains(id)) {
            return false;
          }
          return pool.attached[id] != entry.value.hashCode;
        }).toList()
          ..sort((a, b) {
            final int? indexA = videoIdToIndex[a.key];
            final int? indexB = videoIdToIndex[b.key];
            if (indexA == null) return -1;
            if (indexB == null) return 1;
            if (currentFeedIndex == null) return 0;
            return (indexB - currentFeedIndex).abs().compareTo(
                  (indexA - currentFeedIndex).abs(),
                );
          });

        for (final entry in overflowEntries) {
          if (pool.length < maxControllerPoolSize) break;
          log?.call(
            '🗑️ PlaybackManager: Force-evicting ${entry.key} to keep '
            'permanent $maxControllerPoolSize-controller pool',
          );
          onUnregister(entry.key);
        }
      }
    }

    pool.recordRegister(videoId, controller);

    try {
      if (isControllerSafe(videoId, controller)) {
        controller.setVolume(0.0);
        muteStates[videoId] = true;
        if (focus.blockLevel > 0) {
          controller.pause();
          log?.call(
            '🔇 PlaybackManager: Registered controller is muted and paused '
            '(blocked)',
          );
        } else {
          log?.call(
            '🔇 PlaybackManager: Registered controller is muted (will unmute '
            'on activate)',
          );
        }
      }
    } catch (e) {
      log?.call(
        '⚠️ PlaybackManager: Error muting controller during registration: $e',
      );
      muteStates[videoId] = true;
    }

    if (owner != null) {
      pool.setOwner(videoId, owner);
    }

    onApplyPendingFocus(videoId);
  }

  void unregisterController({
    required String videoId,
    required PlaybackControllerPool pool,
    required PlaybackFocusCoordinator focus,
    required Map<String, bool> muteStates,
    required Map<String, DateTime> warmStartedAt,
    required Map<String, DateTime> focusRequestedAt,
    required Set<String> firstFrameLoggedKeys,
    required bool Function(String videoId, VideoPlayerController controller)
        isControllerSafe,
    required VideoPlayerController? Function() getCurrentlyPlayingController,
    required void Function(VideoPlayerController? controller)
        setCurrentlyPlayingController,
    required void Function({
      required String videoId,
      required VideoPlayerController controller,
      required PlaybackControllerPool pool,
      required bool Function(String videoId, VideoPlayerController controller)
          isControllerSafe,
      void Function(String message)? log,
    }) disposeControllerAfterPause,
    void Function(String message)? log,
  }) {
    log?.call(
        '🗑️ PlaybackManager: Unregistering controller for video $videoId');
    final VideoPlayerController? controller = pool[videoId];
    final bool isAttached =
        controller != null && pool.isAttachedTo(videoId, controller);
    pool.markDetached(videoId);
    pool.createdAt.remove(videoId);
    if (focus.activeVideoId == videoId) {
      focus.publishActiveVideo(null);
      if (controller != null &&
          identical(getCurrentlyPlayingController(), controller)) {
        setCurrentlyPlayingController(null);
      }
    }
    pool.removePoolEntry(videoId);
    muteStates.remove(videoId);
    warmStartedAt.remove(videoId);
    focusRequestedAt.remove(videoId);
    firstFrameLoggedKeys.removeWhere(
      (String entry) => entry.startsWith('$videoId:'),
    );
    if (controller != null && !isAttached) {
      disposeControllerAfterPause(
        videoId: videoId,
        controller: controller,
        pool: pool,
        isControllerSafe: isControllerSafe,
        log: log,
      );
    } else if (controller != null && isAttached) {
      log?.call(
        '📌 PlaybackManager: Controller still attached, skipping dispose '
        '(view will dispose): $videoId',
      );
    }
  }

  void scheduleDeferredPoolControllerDispose({
    required String videoId,
    required VideoPlayerController controller,
    required PlaybackControllerPool pool,
    required bool Function(String videoId, VideoPlayerController controller)
        isControllerSafe,
    void Function(String message)? log,
  }) {
    final int controllerId = controller.hashCode;
    unawaited(() async {
      await Future<void>.delayed(const Duration(milliseconds: 400));
      if (pool[videoId] == controller) {
        return;
      }
      if (pool.attached[videoId] == controllerId) {
        return;
      }
      try {
        if (isControllerSafe(videoId, controller)) {
          await controller.setVolume(0.0).catchError(
            (Object e, StackTrace st) {
              ignorePlaybackTeardownError('global_playback', e, st);
            },
          );
          await controller.pause().catchError(
            (Object e, StackTrace st) {
              ignorePlaybackTeardownError('global_playback', e, st);
            },
          );
        }
        await Future<void>.delayed(const Duration(milliseconds: 350));
        await controller.dispose();
        pool.markDisposed(videoId);
        log?.call(
            '🗑️ PlaybackManager: Deferred dispose completed for $videoId');
      } catch (e) {
        log?.call(
            '⚠️ PlaybackManager: Error in deferred dispose for $videoId: $e');
      }
    }());
  }

  void disposeControllerAfterPause({
    required String videoId,
    required VideoPlayerController controller,
    required PlaybackControllerPool pool,
    required bool Function(String videoId, VideoPlayerController controller)
        isControllerSafe,
    void Function(String message)? log,
  }) {
    unawaited(() async {
      try {
        if (!isControllerSafe(videoId, controller)) {
          log?.call(
            '⚠️ PlaybackManager: Controller for video $videoId already '
            'disposed or invalid',
          );
          return;
        }
        await controller.setVolume(0.0).catchError(
          (Object e, StackTrace st) {
            ignorePlaybackTeardownError('global_playback', e, st);
          },
        );
        await controller.pause().catchError(
          (Object e, StackTrace st) {
            ignorePlaybackTeardownError('global_playback', e, st);
          },
        );
        await Future<void>.delayed(const Duration(milliseconds: 350));
        await controller.dispose();
        pool.markDisposed(videoId);
        log?.call(
            '🗑️ PlaybackManager: Disposed controller for video $videoId');
      } catch (e, st) {
        ignorePlaybackTeardownError('global_playback', e, st);
        log?.call(
          '❌ PlaybackManager: Error disposing controller for video $videoId: $e',
        );
      }
    }());
  }
}
