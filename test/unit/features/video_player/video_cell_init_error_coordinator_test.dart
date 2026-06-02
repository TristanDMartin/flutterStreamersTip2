import 'package:flutter_test/flutter_test.dart';
import 'package:streamers_tip/features/video_player/application/video_cell_init_error_classifier.dart';
import 'package:streamers_tip/features/video_player/application/video_cell_init_error_coordinator.dart';

void main() {
  group('VideoCellInitErrorCoordinator', () {
    const VideoCellInitErrorCoordinator coordinator =
        VideoCellInitErrorCoordinator();

    test('planForError schedules network retry when under max', () {
      final VideoCellInitErrorPlan plan = coordinator.planForError(
        error: Exception('SocketException failed host lookup'),
        retryCount: 0,
        maxRetries: 3,
        baseRetryDelay: const Duration(seconds: 2),
      );
      expect(plan.kind, VideoCellInitErrorKind.networkRetry);
      expect(plan.retryDelay, const Duration(seconds: 2));
      expect(plan.clearControllerReference, isTrue);
    });

    test('planForError quarantines format errors', () {
      final VideoCellInitErrorPlan plan = coordinator.planForError(
        error: Exception('codec mime type not supported'),
        retryCount: 0,
        maxRetries: 3,
        baseRetryDelay: const Duration(seconds: 2),
      );
      expect(plan.kind, VideoCellInitErrorKind.format);
      expect(plan.quarantineVideo, isTrue);
      expect(plan.unplayableReason, 'format_not_supported');
    });
  });
}
