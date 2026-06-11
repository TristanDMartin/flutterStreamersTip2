import 'package:video_player/video_player.dart';

import 'playback_loop_coordinator.dart';

/// Vertical feed index ↔ videoId mapping and saved playback positions.
class PlaybackFeedIndexTracker {
  int? currentFeedIndex;
  int lastScrollDirection = 1;
  final Map<int, String> indexToVideoId = <int, String>{};
  final Map<String, int> videoIdToIndex = <String, int>{};
  final Map<int, Duration> lastKnownPositions = <int, Duration>{};

  String? videoIdAt(int index) => indexToVideoId[index];

  Duration? lastPositionAt(int index) => lastKnownPositions[index];

  void clear() {
    currentFeedIndex = null;
    lastScrollDirection = 1;
    indexToVideoId.clear();
    videoIdToIndex.clear();
    lastKnownPositions.clear();
  }

  void syncMapping({
    required int index,
    required String videoId,
    void Function(String staleVideoId)? onClearStaleFocus,
    void Function(String message)? log,
  }) {
    final String? previousVideoAtIndex = indexToVideoId[index];
    if (previousVideoAtIndex != null && previousVideoAtIndex != videoId) {
      videoIdToIndex.remove(previousVideoAtIndex);
      onClearStaleFocus?.call(previousVideoAtIndex);
      log?.call(
        '🧹 PlaybackManager: Cleared stale feed mapping index=$index '
        'oldVideo=$previousVideoAtIndex',
      );
    }

    final int? previousIndexForVideo = videoIdToIndex[videoId];
    if (previousIndexForVideo != null && previousIndexForVideo != index) {
      indexToVideoId.remove(previousIndexForVideo);
      log?.call(
        '🧹 PlaybackManager: Removed stale reverse mapping video=$videoId '
        'oldIndex=$previousIndexForVideo',
      );
    }

    indexToVideoId[index] = videoId;
    videoIdToIndex[videoId] = index;
  }

  void savePositionForIndex({
    required int index,
    required VideoPlayerController? Function(int index) resolveController,
    required bool Function(String videoId, VideoPlayerController controller)
        isControllerSafe,
    void Function(String message)? log,
    bool logSuccess = false,
  }) {
    final VideoPlayerController? controller = resolveController(index);
    if (controller == null) {
      return;
    }
    final String? videoId = indexToVideoId[index];
    if (videoId == null || !isControllerSafe(videoId, controller)) {
      return;
    }
    try {
      if (!controller.value.isInitialized) {
        return;
      }
      lastKnownPositions[index] = PlaybackLoopCoordinator.clampResumePosition(
        controller.value.position,
        controller.value.duration,
      );
      if (logSuccess) {
        log?.call(
          '💾 PlaybackManager: Saved position '
          '${controller.value.position.inSeconds}s for index $index',
        );
      }
    } catch (e) {
      log?.call('⚠️ PlaybackManager: Error saving position for index $index: $e');
    }
  }

  void saveCurrentPosition({
    required VideoPlayerController? Function(int index) resolveController,
    required bool Function(String videoId, VideoPlayerController controller)
        isControllerSafe,
    void Function(String message)? log,
  }) {
    if (currentFeedIndex == null) {
      return;
    }
    savePositionForIndex(
      index: currentFeedIndex!,
      resolveController: resolveController,
      isControllerSafe: isControllerSafe,
      log: log,
      logSuccess: true,
    );
  }
}
