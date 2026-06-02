import 'package:video_player/video_player.dart';

import '../../../utils/video_health_gate.dart';
import 'video_cell_bootstrap.dart';

enum VideoCellAttachOutcome {
  reuseExisting,
  attached,
  abortedStale,
  abortedUnmounted,
  getOrCreateFailed,
}

/// Binds a pooled controller after health gate passes.
class VideoCellInitAttachCoordinator {
  const VideoCellInitAttachCoordinator({
    VideoCellBootstrap bootstrap = const VideoCellBootstrap(),
  }) : _bootstrap = bootstrap;

  final VideoCellBootstrap _bootstrap;

  Future<VideoCellAttachOutcome> attachPlayable({
    required String videoId,
    required String ownerKey,
    required Playable playable,
    required bool isRetry,
    required int playbackGenerationAtStart,
    required int currentPlaybackGeneration,
    required int controllerVersionAtStart,
    required int currentControllerVersion,
    required VideoPlayerController? existingController,
    required bool isInitialized,
    required bool isDisposed,
    required String? lastResolvedUrl,
    required bool isCurrentVideo,
    required bool mounted,
    required bool Function(VideoPlayerController? controller) canUseController,
    required Future<void> Function(VideoPlayerController oldController)
        detachAndPauseOldController,
    required Future<VideoPlayerController?> Function(String url)
        getOrCreateController,
    required Future<void> Function(VideoPlayerController stale)
        disposeStaleController,
    required Future<void> Function(
      VideoPlayerController controller,
      String url,
    ) wireController,
    required Future<void> Function(String reason) activateCurrentVideo,
    required void Function() notifyPlaySuccess,
    required void Function(String message)? log,
  }) async {
    final String url = playable.url;
    if (_bootstrap.shouldReuseExistingController(
      isRetry: isRetry,
      controller: existingController,
      isInitialized: isInitialized,
      isDisposed: isDisposed,
      canUseController: canUseController,
      lastResolvedUrl: lastResolvedUrl,
      resolvedUrl: url,
    )) {
      log?.call(
        '✅ VideoPlayer: Reusing existing controller for $videoId '
        '(same URL, no retry)',
      );
      if (isCurrentVideo && mounted) {
        await activateCurrentVideo(
          '_initializeVideo: reuse existing controller',
        );
      }
      return VideoCellAttachOutcome.reuseExisting;
    }
    if (existingController != null) {
      await detachAndPauseOldController(existingController);
    }
    final VideoPlayerController? controllerFromManager =
        await getOrCreateController(url);
    if (controllerFromManager == null) {
      return VideoCellAttachOutcome.getOrCreateFailed;
    }
    if (playbackGenerationAtStart != currentPlaybackGeneration ||
        controllerVersionAtStart != currentControllerVersion) {
      log?.call(
        '🔄 VideoPlayer: Generation/version changed during getOrCreateController, '
        'aborting',
      );
      await disposeStaleController(controllerFromManager);
      return VideoCellAttachOutcome.abortedStale;
    }
    if (isDisposed || !mounted) {
      await disposeStaleController(controllerFromManager);
      return VideoCellAttachOutcome.abortedUnmounted;
    }
    await wireController(controllerFromManager, url);
    if (isDisposed || !mounted) {
      return VideoCellAttachOutcome.abortedUnmounted;
    }
    if (isCurrentVideo && mounted && !isDisposed) {
      await activateCurrentVideo(
        '_initializeVideo: controller initialized and current',
      );
      notifyPlaySuccess();
    }
    return VideoCellAttachOutcome.attached;
  }
}
