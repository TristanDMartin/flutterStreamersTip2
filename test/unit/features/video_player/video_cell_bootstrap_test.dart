import 'package:flutter_test/flutter_test.dart';
import 'package:streamers_tip/features/video_player/application/video_cell_bootstrap.dart';
import 'package:video_player/video_player.dart';

void main() {
  group('VideoCellBootstrap', () {
    const VideoCellBootstrap bootstrap = VideoCellBootstrap();

    test('evaluatePreflight returns notReady when url missing', () {
      expect(
        bootstrap.evaluatePreflight(
          hasReadyPlaybackUrl: false,
          useMedia3HomePath: false,
          isInitializing: false,
          isVideoInitializingElsewhere: false,
          isQuarantined: false,
          playbackGenerationAtStart: 1,
          currentPlaybackGeneration: 1,
          controllerVersionAtStart: 1,
          currentControllerVersion: 1,
        ),
        VideoCellInitGate.notReadyForFeed,
      );
    });

    test('evaluatePreflight returns delegateMedia3 when enabled', () {
      expect(
        bootstrap.evaluatePreflight(
          hasReadyPlaybackUrl: true,
          useMedia3HomePath: true,
          isInitializing: false,
          isVideoInitializingElsewhere: false,
          isQuarantined: false,
          playbackGenerationAtStart: 1,
          currentPlaybackGeneration: 1,
          controllerVersionAtStart: 1,
          currentControllerVersion: 1,
        ),
        VideoCellInitGate.delegateMedia3,
      );
    });

    test('shouldReuseExistingController when url unchanged', () {
      final VideoPlayerController controller =
          VideoPlayerController.networkUrl(
        Uri.parse('https://example.com/v.mp4'),
      );
      expect(
        bootstrap.shouldReuseExistingController(
          isRetry: false,
          controller: controller,
          isInitialized: true,
          isDisposed: false,
          canUseController: (_) => true,
          lastResolvedUrl: 'https://example.com/v.mp4',
          resolvedUrl: 'https://example.com/v.mp4',
        ),
        isTrue,
      );
      expect(
        bootstrap.shouldReuseExistingController(
          isRetry: true,
          controller: controller,
          isInitialized: true,
          isDisposed: false,
          canUseController: (_) => true,
          lastResolvedUrl: 'https://example.com/v.mp4',
          resolvedUrl: 'https://example.com/v.mp4',
        ),
        isFalse,
      );
    });
  });
}
