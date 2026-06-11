import 'dart:async';

import 'package:video_player/video_player.dart';

import '../utils/playback_teardown.dart';
import '../utils/safe_video_controller.dart';
import 'playback_controller_pool.dart';

/// Creates and warms [VideoPlayerController] instances for the global pool.
class PlaybackControllerFactory {
  const PlaybackControllerFactory();

  Future<VideoPlayerController?> waitForInitializingController({
    required String videoId,
    required PlaybackControllerPool pool,
    required bool Function(String videoId, VideoPlayerController controller)
        isControllerSafe,
    int attempts = 40,
    Duration step = const Duration(milliseconds: 50),
    void Function(String message)? log,
  }) async {
    for (int i = 0; i < attempts; i++) {
      final VideoPlayerController? pooled = pool[videoId];
      if (pooled != null && isControllerSafe(videoId, pooled)) {
        try {
          if (pooled.value.isInitialized && !pooled.value.hasError) {
            log?.call(
              '✅ PlaybackManager: Initialization completed while waiting: '
              '$videoId',
            );
            return pooled;
          }
        } catch (e, st) {
          ignorePlaybackTeardownError('global_playback', e, st);
        }
      }
      if (!pool.initializing.contains(videoId)) {
        break;
      }
      await Future<void>.delayed(step);
    }
    return null;
  }

  Future<VideoPlayerController?> getOrCreate({
    required String videoId,
    required String url,
    required PlaybackControllerPool pool,
    required Map<String, DateTime> warmStartedAt,
    required bool Function(String videoId, VideoPlayerController controller)
        isControllerSafe,
    required void Function(
      String videoId,
      VideoPlayerController controller, {
      String? owner,
    }) registerController,
    required Future<VideoPlayerController?> Function(String videoId)
        waitForInitializing,
    required void Function(String videoId, {String? owner}) ensureRoomFor,
    String? owner,
    void Function(String message)? log,
  }) async {
    final VideoPlayerController? existing = pool[videoId];
    if (existing != null && isControllerSafe(videoId, existing)) {
      try {
        if (existing.value.isInitialized && !existing.value.hasError) {
          warmStartedAt.remove(videoId);
          log?.call(
            '✅ PlaybackManager: getOrCreateController reusing existing: '
            '$videoId',
          );
          return existing;
        }
      } catch (e, st) {
        ignorePlaybackTeardownError('global_playback', e, st);
      }
    }

    if (pool.initializing.contains(videoId)) {
      final VideoPlayerController? pooled = await waitForInitializing(videoId);
      if (pooled != null) {
        return pooled;
      }
    }

    if (existing != null && !isControllerSafe(videoId, existing)) {
      pool.controllers.remove(videoId);
      try {
        await existing.dispose();
      } catch (e, st) {
        ignorePlaybackTeardownError('global_playback', e, st);
      }
    }
    if (url.isEmpty) {
      return null;
    }
    Uri uri;
    try {
      uri = Uri.parse(url);
      if (!uri.hasScheme || !uri.hasAuthority) {
        return null;
      }
    } catch (e, st) {
      logPlaybackSwallowed('getOrCreateController.parseUrl', e, st);
      return null;
    }
    ensureRoomFor(videoId, owner: owner);
    pool.markInitializing(videoId);
    warmStartedAt[videoId] = DateTime.now();
    VideoPlayerController? created;
    try {
      created = VideoPlayerController.networkUrl(
        uri,
        videoPlayerOptions: VideoPlayerOptions(
          mixWithOthers: false,
          allowBackgroundPlayback: false,
        ),
      );
      pool.controllers[videoId] = created;
      await created.initialize().timeout(
            const Duration(seconds: 8),
            onTimeout: () =>
                throw TimeoutException('getOrCreateController init 8s'),
          );
      registerController(videoId, created, owner: owner ?? 'home/feed');
      final DateTime? warmStartedAtTime = warmStartedAt[videoId];
      final int? initMs = warmStartedAtTime == null
          ? null
          : DateTime.now().difference(warmStartedAtTime).inMilliseconds;
      log?.call(
        '✅ PlaybackManager: getOrCreateController created and registered: '
        '$videoId${initMs == null ? '' : ' initMs=${initMs}ms'}',
      );
      return created;
    } catch (e) {
      log?.call('❌ PlaybackManager: getOrCreateController failed $videoId: $e');
      pool.controllers.remove(videoId);
      if (created != null) {
        try {
          await created.dispose();
        } catch (disposeError, st) {
          ignorePlaybackTeardownError('global_playback', disposeError, st);
        }
      }
      return null;
    } finally {
      pool.clearInitializing(videoId);
    }
  }
}
