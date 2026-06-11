import 'package:video_player/video_player.dart';

import '../constants/playback_owners.dart';
import '../models/home_video.dart';
import '../utils/video_health_gate.dart';
import 'playback_feed_index_tracker.dart';

/// Warms a controller for a feed index (health gate + pool + optional seek).
class PlaybackVisibleIndexCoordinator {
  const PlaybackVisibleIndexCoordinator();

  Future<void> onVisibleIndexChanged({
    required int newIndex,
    required HomeVideo video,
    required int requestGeneration,
    required bool Function() isRequestStale,
    required PlaybackFeedIndexTracker feedIndex,
    required void Function(int index) savePositionForIndex,
    required void Function(int index, String videoId) syncFeedIndexMapping,
    required void Function(String videoId) clearDesiredFocus,
    required void Function(String owner, {String? exceptVideoId})
        clearDesiredFocusForOwner,
    required VideoPlayerController? Function(String videoId) getPooledController,
    required Future<VideoPlayerController?> Function(String videoId)
        waitForInitializing,
    required Future<VideoPlayerController?> Function(
      String videoId,
      String url, {
      String? owner,
    }) getOrCreateController,
    required Future<void> Function(String videoId, String owner) requestFocus,
    required Future<VideoPlayableResult> Function(
      String videoId, {
      String? fallbackUrl,
    }) resolvePlayableSource,
    required bool Function(String videoId, VideoPlayerController controller)
        isControllerReady,
    void Function(String message)? log,
  }) async {
    if (newIndex < 0) {
      log?.call('⚠️ PlaybackManager: Invalid index $newIndex, ignoring');
      return;
    }
    if (video.id.isEmpty || video.videoURL.isEmpty) {
      log?.call(
        '⚠️ PlaybackManager: Invalid video object, ignoring index change',
      );
      return;
    }
    log?.call(
      '📺 PlaybackManager: Visible index changed to $newIndex '
      '(video: ${video.id})',
    );
    try {
      final int? previousIndex = feedIndex.currentFeedIndex;
      final String? previousVideoId =
          previousIndex != null ? feedIndex.videoIdAt(previousIndex) : null;
      if (previousIndex != null && newIndex > previousIndex) {
        feedIndex.lastScrollDirection = 1;
      } else if (previousIndex != null && newIndex < previousIndex) {
        feedIndex.lastScrollDirection = -1;
      }
      if (feedIndex.currentFeedIndex != null) {
        savePositionForIndex(feedIndex.currentFeedIndex!);
      }
      feedIndex.currentFeedIndex = newIndex;
      syncFeedIndexMapping(newIndex, video.id);
      if (previousVideoId != null && previousVideoId != video.id) {
        clearDesiredFocus(previousVideoId);
      }
    } catch (e) {
      log?.call('❌ PlaybackManager: Error updating index mappings: $e');
      return;
    }
    final String targetVideoId = video.id;
    final int requestedIndex = newIndex;
    if (isRequestStale()) {
      log?.call(
        '⏭️ PlaybackManager: Stale visible-index request ignored '
        '(gen=$requestGeneration) for $targetVideoId at $requestedIndex',
      );
      return;
    }
    clearDesiredFocusForOwner(
      PlaybackOwners.home,
      exceptVideoId: targetVideoId,
    );

    VideoPlayerController? controller = getPooledController(targetVideoId);
    if (controller != null && !isControllerReady(targetVideoId, controller)) {
      controller = null;
    }
    controller ??= await waitForInitializing(targetVideoId).catchError(
      (Object _) => null,
    );
    if (isRequestStale()) {
      log?.call(
        '⏭️ PlaybackManager: Stale visible-index request ignored after wait '
        '(gen=$requestGeneration) for $targetVideoId',
      );
      return;
    }
    if (controller != null && isControllerReady(targetVideoId, controller)) {
      log?.call(
        '✅ PlaybackManager: Using pooled controller for $targetVideoId '
        'at index $requestedIndex',
      );
      if (isRequestStale() ||
          feedIndex.currentFeedIndex != requestedIndex ||
          feedIndex.videoIdAt(requestedIndex) != targetVideoId) {
        log?.call(
          '⏭️ PlaybackManager: Stale pooled-controller request ignored for '
          '$targetVideoId',
        );
        return;
      }
      await requestFocus(targetVideoId, PlaybackOwners.home);
      return;
    }

    log?.call(
      '⚠️ PlaybackManager: PRELOAD_MISS index=$requestedIndex '
      'video=$targetVideoId — initializing on visible-index change',
    );
    final VideoPlayableResult healthResult = await resolvePlayableSource(
      targetVideoId,
      fallbackUrl: video.videoURL.isNotEmpty ? video.videoURL : null,
    );
    if (isRequestStale() ||
        feedIndex.currentFeedIndex != requestedIndex ||
        feedIndex.videoIdAt(requestedIndex) != targetVideoId) {
      log?.call(
        '⏭️ PlaybackManager: Stale visible-index request ignored for '
        '$targetVideoId at $requestedIndex '
        '(current=${feedIndex.currentFeedIndex})',
      );
      return;
    }
    if (healthResult is Unplayable) {
      log?.call(
        '⚠️ PlaybackManager: Video $targetVideoId unplayable: '
        '${healthResult.reason}',
      );
      return;
    }
    final String playableUrl = (healthResult as Playable).url;
    controller = await getOrCreateController(
      targetVideoId,
      playableUrl,
      owner: PlaybackOwners.home,
    ).catchError((Object e) {
      log?.call(
        '⚠️ PlaybackManager: getOrCreateController failed for '
        '$targetVideoId: $e',
      );
      return null;
    });
    if (controller == null) return;
    if (isRequestStale() ||
        feedIndex.currentFeedIndex != requestedIndex ||
        feedIndex.videoIdAt(requestedIndex) != targetVideoId) {
      log?.call(
        '⏭️ PlaybackManager: Controller ready for stale video $targetVideoId; '
        'leaving muted',
      );
      try {
        await controller.setVolume(0.0);
        await controller.pause();
      } catch (_) {}
      return;
    }
    await requestFocus(targetVideoId, PlaybackOwners.home);
  }
}
