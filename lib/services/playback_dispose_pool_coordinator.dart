import 'package:video_player/video_player.dart';

import 'playback_controller_pool.dart';
import 'playback_feed_index_tracker.dart';
import 'playback_focus_coordinator.dart';

/// Disposes pooled controllers and clears feed/focus metadata.
class PlaybackDisposePoolCoordinator {
  const PlaybackDisposePoolCoordinator();

  void disposeAll({
    required PlaybackControllerPool pool,
    required PlaybackFocusCoordinator focus,
    required PlaybackFeedIndexTracker feedIndex,
    required Map<String, bool> muteStates,
    required Map<String, DateTime> warmStartedAt,
    required Map<String, DateTime> focusRequestedAt,
    required Set<String> firstFrameLoggedKeys,
    required void Function() clearTabPaused,
    required bool Function(String videoId, VideoPlayerController controller)
        isControllerSafe,
    required void Function(String videoId, VideoPlayerController controller)
        disposeControllerAfterPause,
    void Function(String message)? log,
  }) {
    log?.call('🚨 PlaybackManager: Disposing all controllers');
    for (final MapEntry<String, VideoPlayerController> entry
        in pool.controllers.entries) {
      final String videoId = entry.key;
      final VideoPlayerController controller = entry.value;
      final bool isAttached = pool.isAttachedTo(videoId, controller);
      if (isAttached) {
        log?.call(
          '📌 PlaybackManager: Skipping attached controller for $videoId',
        );
        continue;
      }
      try {
        if (isControllerSafe(videoId, controller)) {
          disposeControllerAfterPause(videoId, controller);
        } else {
          log?.call(
            '⚠️ PlaybackManager: Controller for video $videoId already '
            'disposed or invalid',
          );
        }
      } catch (e) {
        log?.call(
          '❌ PlaybackManager: Error disposing controller for video '
          '$videoId: $e',
        );
      }
    }
    pool.clearAll();
    muteStates.clear();
    feedIndex.clear();
    warmStartedAt.clear();
    focusRequestedAt.clear();
    firstFrameLoggedKeys.clear();
    focus.resetFocusState();
    clearTabPaused();
    log?.call(
      '✅ PlaybackManager: All controllers disposed and state cleared',
    );
  }

  void disposeControllersForOwner({
    required String owner,
    required PlaybackFocusCoordinator focus,
    required Map<String, String> controllerOwners,
    required void Function(String videoId) unregisterController,
    void Function(String message)? log,
  }) {
    log?.call('🗑️ PlaybackManager: Disposing controllers for owner: $owner');
    final List<String> toDispose = <String>[];
    for (final MapEntry<String, String> entry in controllerOwners.entries) {
      if (entry.value == owner) {
        toDispose.add(entry.key);
      }
    }
    final bool isDisposingActiveOwner = focus.isDisposingActiveOwner(owner);
    for (final String videoId in toDispose) {
      log?.call(
        '🗑️ PlaybackManager: Disposing controller for video $videoId '
        '(owner: $owner)',
      );
      unregisterController(videoId);
    }
    if (isDisposingActiveOwner) {
      final bool hasRemainingControllers = controllerOwners.values.any(
        (String o) => o == owner || o.startsWith('$owner/'),
      );
      if (!hasRemainingControllers) {
        log?.call(
          '🗑️ PlaybackManager: All controllers for active owner $owner '
          'disposed, clearing active owner',
        );
        focus.publishActiveOwner(null);
      }
    }
    log?.call(
      '✅ PlaybackManager: Disposed ${toDispose.length} controllers for '
      'owner: $owner',
    );
  }
}
