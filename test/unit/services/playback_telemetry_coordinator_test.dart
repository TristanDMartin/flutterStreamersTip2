import 'package:flutter_test/flutter_test.dart';
import 'package:streamers_tip/services/playback_controller_pool.dart';
import 'package:streamers_tip/services/playback_focus_coordinator.dart';
import 'package:streamers_tip/services/playback_telemetry_coordinator.dart';

void main() {
  group('PlaybackTelemetryCoordinator', () {
    const PlaybackTelemetryCoordinator coordinator =
        PlaybackTelemetryCoordinator();

    test('logControllerEvent triggers pool snapshot on CREATE', () {
      final List<String> logs = <String>[];
      var snapshotCount = 0;
      coordinator.logControllerEvent(
        event: 'CREATE_CONTROLLER',
        videoId: 'v1',
        pool: PlaybackControllerPool(),
        pinnedVideoIds: <String>{},
        initializingControllers: <String>{},
        cooldownUntil: <String, DateTime>{},
        onPoolSnapshot: ({String? reason}) => snapshotCount++,
        log: logs.add,
      );
      expect(snapshotCount, 1);
      expect(logs.any((String l) => l.contains('CREATE_CONTROLLER')), isTrue);
    });

    test('logTelemetry includes block level', () {
      final List<String> logs = <String>[];
      final PlaybackFocusCoordinator focus = PlaybackFocusCoordinator();
      focus.incrementBlock(reason: 'test');
      coordinator.logTelemetry(
        focus: focus,
        event: 'pause_all',
        log: logs.add,
      );
      expect(logs.single, contains('blocked=1'));
    });
  });
}
