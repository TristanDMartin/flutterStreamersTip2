import 'package:video_player/video_player.dart';

import '../../../utils/video_health_gate.dart';
import '../../../utils/video_url_resolver.dart';

/// Early init gates and health resolution for a feed video cell.
enum VideoCellInitGate {
  none,
  notReadyForFeed,
  delegateMedia3,
  alreadyInitializing,
  quarantined,
  staleGeneration,
  staleControllerVersion,
}

class VideoCellBootstrap {
  const VideoCellBootstrap();

  String? readyPlaybackUrlFromVideo({
    required String status,
    required String videoUrl,
  }) {
    return resolveReadyPlaybackUrl(<String, dynamic>{
      'status': status,
      'isReadyForFeed': true,
      'canonicalPlaybackUrl': videoUrl,
    });
  }

  VideoCellInitGate evaluatePreflight({
    required bool hasReadyPlaybackUrl,
    required bool useMedia3HomePath,
    required bool isInitializing,
    required bool isVideoInitializingElsewhere,
    required bool isQuarantined,
    required int playbackGenerationAtStart,
    required int currentPlaybackGeneration,
    required int controllerVersionAtStart,
    required int currentControllerVersion,
  }) {
    if (!hasReadyPlaybackUrl) {
      return VideoCellInitGate.notReadyForFeed;
    }
    if (useMedia3HomePath) {
      return VideoCellInitGate.delegateMedia3;
    }
    if (isInitializing || isVideoInitializingElsewhere) {
      return VideoCellInitGate.alreadyInitializing;
    }
    if (isQuarantined) {
      return VideoCellInitGate.quarantined;
    }
    if (playbackGenerationAtStart != currentPlaybackGeneration) {
      return VideoCellInitGate.staleGeneration;
    }
    if (controllerVersionAtStart != currentControllerVersion) {
      return VideoCellInitGate.staleControllerVersion;
    }
    return VideoCellInitGate.none;
  }

  Future<VideoPlayableResult> resolvePlayableSource({
    required String videoId,
    required String fallbackUrl,
  }) {
    return VideoHealthGate.instance.resolvePlayableSource(
      videoId,
      cachedData: null,
      fallbackUrl: fallbackUrl,
    );
  }

  bool shouldReuseExistingController({
    required bool isRetry,
    required VideoPlayerController? controller,
    required bool isInitialized,
    required bool isDisposed,
    required bool Function(VideoPlayerController? controller) canUseController,
    required String? lastResolvedUrl,
    required String resolvedUrl,
  }) {
    return !isRetry &&
        controller != null &&
        isInitialized &&
        !isDisposed &&
        canUseController(controller) &&
        lastResolvedUrl == resolvedUrl;
  }
}
