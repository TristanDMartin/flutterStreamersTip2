import 'package:flutter_test/flutter_test.dart';
import 'package:streamers_tip/features/video_player/application/video_cell_activation_coordinator.dart';
import 'package:video_player/video_player.dart';

void main() {
  group('VideoCellActivationCoordinator', () {
    const VideoCellActivationCoordinator coordinator =
        VideoCellActivationCoordinator();

    test('attemptRequestFocus returns requested when gates pass', () {
      final VideoPlayerController controller =
          VideoPlayerController.networkUrl(
        Uri.parse('https://example.com/v.mp4'),
      );
      final VideoCellFocusAttemptOutcome outcome =
          coordinator.attemptRequestFocus(
        mounted: true,
        isDisposed: false,
        isCurrentVideo: true,
        videoId: 'v1',
        ownerKey: 'home/forYou',
        hasRequestedFocusForVideo: false,
        lastRequestedVideoId: null,
        pooledController: controller,
        widgetController: controller,
        controllersMatchPool: true,
        adoptFromPool: (_) {},
        isPlaybackBlocked: false,
        canPlayOwner: true,
        setDesiredFocus: (_, __) {},
        reason: 'test',
      );
      expect(outcome, VideoCellFocusAttemptOutcome.requested);
    });

    test('activateCurrentVideo retries when blocked', () {
      var adoptCalled = false;
      final VideoCellActivateOutcome outcome =
          coordinator.activateCurrentVideo(
        mounted: true,
        isDisposed: false,
        isCurrentVideo: true,
        videoId: 'v1',
        ownerKey: 'home',
        allowRetry: true,
        reason: 'test',
        resolveActiveController: () => VideoPlayerController.networkUrl(
          Uri.parse('https://example.com/v.mp4'),
        ),
        adoptFromPoolWhenEmpty: (_) => adoptCalled = true,
        isPlaybackBlocked: true,
        canPlayOwner: true,
        setDesiredFocus: (_, __) {},
        cancelPendingRetrySubscription: () {},
        runAttemptRequestFocus: (_) => false,
      );
      expect(outcome, VideoCellActivateOutcome.retryWhenBlocked);
      expect(adoptCalled, isFalse);
    });
  });
}
