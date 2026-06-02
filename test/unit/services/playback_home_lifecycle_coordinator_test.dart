import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streamers_tip/constants/playback_owners.dart';
import 'package:streamers_tip/services/playback_home_lifecycle_coordinator.dart';

void main() {
  group('PlaybackHomeLifecycleCoordinator', () {
    const PlaybackHomeLifecycleCoordinator coordinator =
        PlaybackHomeLifecycleCoordinator();

    test('onEnterHomeView sets home owner and restores focus', () {
      final List<String> owners = <String>[];
      var restoreCount = 0;

      coordinator.onEnterHomeView(
        setActiveOwner: owners.add,
        restoreCurrentFeedFocus: () => restoreCount++,
      );

      expect(owners, <String>[PlaybackOwners.home]);
      expect(restoreCount, 1);
    });

    test('restoreCurrentFeedFocus queues desired focus for mapped video', () {
      String? desiredVideoId;
      String? desiredOwner;
      String? clearedOwner;
      String? clearedExcept;

      coordinator.restoreCurrentFeedFocus(
        currentFeedIndex: 2,
        videoIdAtIndex: (int index) => index == 2 ? 'video-2' : null,
        clearDesiredFocusForOwner: (String owner, {String? exceptVideoId}) {
          clearedOwner = owner;
          clearedExcept = exceptVideoId;
        },
        setDesiredFocus: (String videoId, String owner) {
          desiredVideoId = videoId;
          desiredOwner = owner;
        },
      );

      expect(clearedOwner, PlaybackOwners.home);
      expect(clearedExcept, 'video-2');
      expect(desiredVideoId, 'video-2');
      expect(desiredOwner, PlaybackOwners.home);
    });

    test('onLeaveHomeView saves position, clears focus, and pauses', () {
      var saved = false;
      var paused = false;
      String? clearedOwner;

      coordinator.onLeaveHomeView(
        saveCurrentPosition: () => saved = true,
        clearDesiredFocusForOwner: (String owner) => clearedOwner = owner,
        pauseAll: () => paused = true,
      );

      expect(saved, isTrue);
      expect(clearedOwner, PlaybackOwners.home);
      expect(paused, isTrue);
    });

    test('onAppLifecycleChanged pauses when app backgrounds', () {
      var saved = false;
      var paused = false;

      coordinator.onAppLifecycleChanged(
        state: AppLifecycleState.paused,
        saveCurrentPosition: () => saved = true,
        pauseAll: () => paused = true,
        currentFeedIndex: 1,
      );

      expect(saved, isTrue);
      expect(paused, isTrue);
    });
  });
}
