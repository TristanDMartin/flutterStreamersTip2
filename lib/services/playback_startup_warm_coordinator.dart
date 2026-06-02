import 'dart:async';

import '../constants/playback_owners.dart';
import '../models/home_video.dart';
import 'playback_preload_order.dart';
import '../utils/secure_log.dart';

/// Coordinates startup warm-window preloads with generation cancellation.
class PlaybackStartupWarmCoordinator {
  int _generation = 0;

  int beginWarmWindow() => ++_generation;

  bool isCurrentGeneration(int generation) => generation == _generation;

  void preloadStartupWindow({
    required List<HomeVideo> videos,
    required int startIndex,
    required bool requestFocusOnStart,
    required void Function(int index, String videoId) onSyncMapping,
    required void Function(int index) onUpdatePinSet,
    required Future<void> Function(int index, HomeVideo video) onEnsureReady,
    required Future<void> Function(String videoId, String owner) onRequestFocus,
    required void Function(int index) onDisposeFarControllers,
    void Function(String message)? log,
  }) {
    if (videos.isEmpty) {
      return;
    }
    final int safeIndex = startIndex.clamp(0, videos.length - 1);
    final int generation = beginWarmWindow();
    log?.call(
      '🚀 PlaybackManager: Startup warm window from index $safeIndex '
      '(videos=${videos.length})',
    );

    Future<void>(() async {
      final List<int> indices = computePlaybackPreloadIndices(
        index: safeIndex,
        videoCount: videos.length,
        direction: 1,
        backwardRadius: 1,
        forwardRadius: 1,
      );

      for (final int index in indices) {
        final HomeVideo video = videos[index];
        if (video.id.isNotEmpty) {
          onSyncMapping(index, video.id);
        }
      }
      onUpdatePinSet(safeIndex);

      if (isCurrentGeneration(generation)) {
        final HomeVideo currentVideo = videos[safeIndex];
        await onEnsureReady(safeIndex, currentVideo);
        if (requestFocusOnStart) {
          await onRequestFocus(currentVideo.id, PlaybackOwners.home);
        }
      }

      for (final int index in indices) {
        if (index == safeIndex) {
          continue;
        }
        if (!isCurrentGeneration(generation)) {
          return;
        }
        unawaited(onEnsureReady(index, videos[index]));
      }
      onDisposeFarControllers(safeIndex);
    }).catchError((Object e, StackTrace stackTrace) {
      secureLog('⚠️ PlaybackManager: Startup warm window failed: $e');
      secureLog('Stack trace: $stackTrace');
    });
  }
}
