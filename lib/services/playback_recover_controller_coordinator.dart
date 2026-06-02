import 'package:video_player/video_player.dart';

import '../constants/playback_owners.dart';
import '../models/home_video.dart';
import '../utils/video_health_gate.dart';

/// Re-registers a video after unregister + health gate pass.
class PlaybackRecoverControllerCoordinator {
  const PlaybackRecoverControllerCoordinator();

  Future<VideoPlayerController?> recoverFailedController({
    required HomeVideo video,
    required void Function(String videoId) unregisterController,
    required Future<VideoPlayableResult> Function(
      String videoId, {
      String? fallbackUrl,
    }) resolvePlayableSource,
    required Future<VideoPlayerController?> Function(
      String videoId,
      String url, {
      String? owner,
    }) getOrCreateController,
    String owner = PlaybackOwners.home,
    void Function(String message)? log,
  }) async {
    if (video.id.isEmpty) {
      return null;
    }
    unregisterController(video.id);
    final VideoPlayableResult healthResult = await resolvePlayableSource(
      video.id,
      fallbackUrl: video.videoURL.isNotEmpty ? video.videoURL : null,
    );
    if (healthResult is! Playable) {
      log?.call(
        '⚠️ PlaybackManager: recoverFailedController unplayable ${video.id}',
      );
      return null;
    }
    return getOrCreateController(
      video.id,
      healthResult.url,
      owner: owner,
    );
  }
}
