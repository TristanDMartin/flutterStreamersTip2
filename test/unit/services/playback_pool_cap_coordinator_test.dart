import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streamers_tip/constants/playback_owners.dart';
import 'package:streamers_tip/services/playback_controller_pool.dart';
import 'package:streamers_tip/services/playback_feed_index_tracker.dart';
import 'package:streamers_tip/services/playback_pool_cap_coordinator.dart';
import 'package:video_player/video_player.dart';

class _FakeController extends Fake implements VideoPlayerController {
  @override
  VideoPlayerValue get value => const VideoPlayerValue(
        duration: Duration(seconds: 30),
        size: Size(100, 100),
        isInitialized: true,
      );
}

void main() {
  group('PlaybackPoolCapCoordinator', () {
    const PlaybackPoolCapCoordinator coordinator =
        PlaybackPoolCapCoordinator();

    test('ownerConflictsWithVisibleSurface flags home vs discover', () {
      expect(
        PlaybackPoolCapCoordinator.ownerConflictsWithVisibleSurface(
          PlaybackOwners.home,
          PlaybackOwners.discover,
        ),
        isTrue,
      );
      expect(
        PlaybackPoolCapCoordinator.ownerConflictsWithVisibleSurface(
          PlaybackOwners.discoverPlayer,
          PlaybackOwners.home,
        ),
        isTrue,
      );
      expect(
        PlaybackPoolCapCoordinator.ownerConflictsWithVisibleSurface(
          PlaybackOwners.home,
          PlaybackOwners.home,
        ),
        isFalse,
      );
    });

    test('enforcePoolCap evicts farthest ids until size is at most three', () {
      final PlaybackControllerPool pool = PlaybackControllerPool();
      final PlaybackFeedIndexTracker feedIndex = PlaybackFeedIndexTracker();
      feedIndex.currentFeedIndex = 0;
      feedIndex.syncMapping(index: 0, videoId: 'v0');
      feedIndex.syncMapping(index: 1, videoId: 'v1');
      feedIndex.syncMapping(index: 5, videoId: 'v5');
      final List<String> unregistered = <String>[];
      for (final String id in <String>['v0', 'v1', 'v2', 'v3', 'v5']) {
        pool.recordRegister(id, _FakeController());
        pool.setOwner(id, PlaybackOwners.home);
      }
      expect(pool.length, 5);
      final int evicted = coordinator.enforcePoolCap(
        pool: pool,
        feedIndex: feedIndex,
        activeVideoId: 'v0',
        isActiveVideo: (String id) => id == 'v0',
        onUnregister: (String id) {
          unregistered.add(id);
          pool.removePoolEntry(id);
        },
        onPoolAudit: (_, __, {String? reason}) {},
        maxSize: 3,
        reason: 'test',
      );
      expect(evicted, 2);
      expect(pool.length, 3);
      expect(unregistered, containsAll(<String>['v2', 'v3']));
      expect(unregistered, isNot(contains('v0')));
      expect(pool.containsKey('v0'), isTrue);
      expect(pool.containsKey('v5'), isTrue);
    });
  });
}
