import 'package:flutter_test/flutter_test.dart';
import 'package:streamers_tip/services/global_playback_manager.dart';

void main() {
  group('GlobalPlaybackManager', () {
    late GlobalPlaybackManager manager;

    setUp(() {
      // Reset singleton instance for each test
      manager = GlobalPlaybackManager.instance;
      // Clean up any existing state
      manager.disposeAll();
    });

    tearDown(() {
      manager.disposeAll();
    });

    test('Singleton instance returns same instance', () {
      final instance1 = GlobalPlaybackManager.instance;
      final instance2 = GlobalPlaybackManager.instance;
      expect(instance1, equals(instance2));
    });

    test('Initial state - no active video', () {
      expect(manager.activeVideoId, isNull);
      expect(manager.activeOwner, isNull);
      expect(manager.isPaused, isFalse);
      expect(manager.isPlaybackBlocked, isFalse);
    });

    test('Block and unblock playback', () {
      // Block playback
      manager.block(reason: 'test');
      expect(manager.isPlaybackBlocked, isTrue);
      expect(manager.blockLevel, equals(1));
      expect(manager.blockReason, equals('test'));

      // Nested blocking
      manager.block(reason: 'nested');
      expect(manager.blockLevel, equals(2));

      // Unblock once
      manager.unblock();
      expect(manager.blockLevel, equals(1));
      expect(manager.isPlaybackBlocked, isTrue);

      // Unblock again
      manager.unblock();
      expect(manager.blockLevel, equals(0));
      expect(manager.isPlaybackBlocked, isFalse);
      expect(manager.blockReason, isNull);
    });

    test('Unblock when already unblocked does nothing', () {
      expect(manager.blockLevel, equals(0));
      manager.unblock();
      expect(manager.blockLevel, equals(0));
    });

    test('Request focus sets active video and owner', () async {
      const videoId = 'test-video-1';
      const owner = 'home/forYou';

      await manager.requestFocus(videoId, owner);

      expect(manager.activeVideoId, equals(videoId));
      expect(manager.activeOwner, equals(owner));
      expect(manager.isActive(videoId), isTrue);
    });

    test('isActive returns false for non-active video', () {
      expect(manager.isActive('non-existent'), isFalse);
    });

    test('Active video stream emits changes', () async {
      const videoId1 = 'video-1';
      const videoId2 = 'video-2';

      final streamValues = <String?>[];
      final subscription = manager.activeVideoStream.listen((videoId) {
        streamValues.add(videoId);
      });

      await manager.requestFocus(videoId1, 'owner1');
      await manager.requestFocus(videoId2, 'owner2');

      await Future.delayed(const Duration(milliseconds: 100));

      expect(streamValues.length, greaterThan(0));
      expect(streamValues.last, equals(videoId2));

      await subscription.cancel();
    });

    test('Active owner stream emits changes', () async {
      const owner1 = 'home/forYou';
      const owner2 = 'home/progression';

      final streamValues = <String?>[];
      final subscription = manager.activeOwnerStream.listen((owner) {
        streamValues.add(owner);
      });

      await manager.requestFocus('video-1', owner1);
      await manager.requestFocus('video-2', owner2);

      await Future.delayed(const Duration(milliseconds: 100));

      expect(streamValues.length, greaterThan(0));
      expect(streamValues.last, equals(owner2));

      await subscription.cancel();
    });

    test('Playback blocked stream emits changes', () async {
      final streamValues = <bool>[];
      final subscription = manager.playbackBlockedStream.listen((blocked) {
        streamValues.add(blocked);
      });

      manager.block(reason: 'test');
      await Future.delayed(const Duration(milliseconds: 100));

      expect(streamValues.length, greaterThan(0));
      expect(streamValues.last, isTrue);

      manager.unblock();
      await Future.delayed(const Duration(milliseconds: 100));

      expect(streamValues.last, isFalse);

      await subscription.cancel();
    });

    test('Dispose all clears all controllers', () {
      // This test verifies disposeAll doesn't throw
      expect(() => manager.disposeAll(), returnsNormally);
    });

    test('Pause all when no controllers registered', () {
      // Should not throw when no controllers exist
      expect(() => manager.pauseAll(), returnsNormally);
    });
  });
}
