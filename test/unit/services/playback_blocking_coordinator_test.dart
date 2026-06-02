import 'package:flutter_test/flutter_test.dart';
import 'package:streamers_tip/services/playback_blocking_coordinator.dart';
import 'package:streamers_tip/services/playback_focus_coordinator.dart';

void main() {
  group('PlaybackBlockingCoordinator', () {
    const PlaybackBlockingCoordinator coordinator =
        PlaybackBlockingCoordinator();
    late PlaybackFocusCoordinator focus;

    setUp(() {
      focus = PlaybackFocusCoordinator();
    });

    test('block increments level and pauses', () {
      var paused = false;
      final List<String> events = <String>[];

      coordinator.block(
        focus: focus,
        pauseAll: () => paused = true,
        onTelemetry: (String event, {String? reason}) => events.add(event),
        reason: 'camera',
      );

      expect(focus.blockLevel, 1);
      expect(focus.blockReason, 'camera');
      expect(paused, isTrue);
      expect(events, <String>['block']);
    });

    test('unblock decrements nested blocks', () {
      coordinator.block(
        focus: focus,
        pauseAll: () {},
        onTelemetry: (_, {reason}) {},
        reason: 'a',
      );
      coordinator.block(
        focus: focus,
        pauseAll: () {},
        onTelemetry: (_, {reason}) {},
        reason: 'b',
      );
      coordinator.unblock(
        focus: focus,
        onTelemetry: (_, {reason}) {},
      );
      expect(focus.blockLevel, 1);
      coordinator.unblock(
        focus: focus,
        onTelemetry: (_, {reason}) {},
      );
      expect(focus.blockLevel, 0);
      expect(focus.blockReason, isNull);
    });
  });
}
