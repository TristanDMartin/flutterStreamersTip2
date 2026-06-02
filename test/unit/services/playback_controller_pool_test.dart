import 'package:flutter_test/flutter_test.dart';
import 'package:streamers_tip/services/playback_controller_pool.dart';
import 'package:video_player/video_player.dart';

void main() {
  group('PlaybackControllerPool', () {
    late PlaybackControllerPool pool;

    setUp(() {
      pool = PlaybackControllerPool();
    });

    test('updatePinSet protects neighbors with controllers', () {
      pool.controllers['v0'] = VideoPlayerController.networkUrl(
        Uri.parse('https://example.com/0.mp4'),
      );
      pool.controllers['v1'] = VideoPlayerController.networkUrl(
        Uri.parse('https://example.com/1.mp4'),
      );
      pool.controllers['v2'] = VideoPlayerController.networkUrl(
        Uri.parse('https://example.com/2.mp4'),
      );
      pool.updatePinSet(
        currentIndex: 1,
        indexToVideoId: <int, String>{0: 'v0', 1: 'v1', 2: 'v2'},
      );
      expect(pool.pinnedVideoIds, <String>{'v0', 'v1', 'v2'});
    });

    test('canEvict rejects active and initializing ids', () {
      final VideoPlayerController controller = VideoPlayerController.networkUrl(
        Uri.parse('https://example.com/a.mp4'),
      );
      pool.controllers['active'] = controller;
      pool.initializing.add('init');
      pool.createdAt['active'] = DateTime.now().subtract(
        const Duration(seconds: 10),
      );
      pool.createdAt['init'] = DateTime.now().subtract(
        const Duration(seconds: 10),
      );
      final DateTime now = DateTime.now();
      expect(
        pool.canEvict(
          id: 'active',
          controller: controller,
          now: now,
          activeVideoId: 'active',
        ),
        isFalse,
      );
      expect(
        pool.canEvict(
          id: 'init',
          controller: controller,
          now: now,
          activeVideoId: null,
        ),
        isFalse,
      );
    });

    test('clearAll resets pool metadata', () {
      pool.controllers['x'] = VideoPlayerController.networkUrl(
        Uri.parse('https://example.com/x.mp4'),
      );
      pool.owners['x'] = 'home';
      pool.pinnedVideoIds.add('x');
      pool.clearAll();
      expect(pool.length, 0);
      expect(pool.pinnedVideoIds, isEmpty);
      expect(pool.owners, isEmpty);
    });

    test('snapshotTokenFor encodes pin init cooldown flags', () {
      pool.initializing.add('v1');
      pool.cooldownUntil['v2'] = DateTime.now();
      pool.pinnedVideoIds.add('v3');
      expect(pool.snapshotTokenFor('v1'), 'v1[-I-]');
      expect(pool.snapshotTokenFor('v2'), 'v2[--C]');
      expect(pool.snapshotTokenFor('v3'), 'v3[P--]');
    });
  });
}
