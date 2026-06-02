import 'package:flutter_test/flutter_test.dart';
import 'package:streamers_tip/services/playback_focus_coordinator.dart';

void main() {
  group('PlaybackFocusCoordinator', () {
    late PlaybackFocusCoordinator focus;

    setUp(() {
      focus = PlaybackFocusCoordinator();
    });

    tearDown(() {
      focus.dispose();
    });

    test('ownerMatchesVisibleOwner allows nested owners', () {
      focus.setVisibleOwner('home');
      expect(focus.ownerMatchesVisibleOwner('home'), isTrue);
      expect(focus.ownerMatchesVisibleOwner('home/forYou'), isTrue);
      expect(focus.ownerMatchesVisibleOwner('discover'), isFalse);
    });

    test('ownerMatchesVisibleOwner passes when visible owner unset', () {
      expect(focus.ownerMatchesVisibleOwner('any'), isTrue);
    });

    test('incrementBlock and decrementBlock nest correctly', () {
      focus.incrementBlock(reason: 'a');
      expect(focus.blockLevel, 1);
      expect(focus.isPlaybackBlocked, isTrue);
      expect(focus.blockReason, 'a');

      focus.incrementBlock();
      expect(focus.blockLevel, 2);

      expect(focus.decrementBlock(), isFalse);
      expect(focus.blockLevel, 1);
      expect(focus.isPlaybackBlocked, isTrue);

      expect(focus.decrementBlock(), isTrue);
      expect(focus.blockLevel, 0);
      expect(focus.isPlaybackBlocked, isFalse);
      expect(focus.blockReason, isNull);
    });

    test('forceUnblock clears nested blocks', () {
      focus.incrementBlock();
      focus.incrementBlock();
      expect(focus.forceUnblock(), isTrue);
      expect(focus.blockLevel, 0);
      expect(focus.forceUnblock(), isFalse);
    });

    test('clearBlockOnOwnerSwitch clears stale block', () {
      focus.incrementBlock(reason: 'stale');
      expect(focus.clearBlockOnOwnerSwitch(), isTrue);
      expect(focus.blockLevel, 0);
      expect(focus.clearBlockOnOwnerSwitch(), isFalse);
    });

    test('publishActiveSession updates video and owner streams', () async {
      final List<String?> videoEvents = <String?>[];
      final List<String?> ownerEvents = <String?>[];
      final videoSub = focus.activeVideoStream.listen(videoEvents.add);
      final ownerSub = focus.activeOwnerStream.listen(ownerEvents.add);

      focus.publishActiveSession(videoId: 'v1', owner: 'home');

      await Future<void>.delayed(Duration.zero);

      expect(focus.activeVideoId, 'v1');
      expect(focus.activeOwner, 'home');
      expect(videoEvents, contains('v1'));
      expect(ownerEvents, contains('home'));

      await videoSub.cancel();
      await ownerSub.cancel();
    });

    test('pending focus queue helpers', () {
      focus.queuePendingFocus('v1', 'home');
      expect(focus.pendingOwnerFor('v1'), 'home');
      expect(focus.takePendingOwner('v1'), 'home');
      expect(focus.pendingOwnerFor('v1'), isNull);

      focus.queuePendingFocus('v1', 'home');
      focus.queuePendingFocus('v2', 'home');
      focus.queuePendingFocus('v3', 'discover');
      expect(
        focus.clearPendingFocusForOwner('home', exceptVideoId: 'v1'),
        1,
      );
      expect(focus.pendingOwnerFor('v2'), isNull);
      expect(focus.pendingOwnerFor('v1'), 'home');
      expect(focus.pendingOwnerFor('v3'), 'discover');

      expect(focus.clearAllPendingFocus(), 2);
      expect(focus.pendingFocusRequests, isEmpty);
    });

    test('resetFocusState clears session and pending queue', () async {
      focus.queuePendingFocus('v1', 'home');
      focus.publishActiveSession(videoId: 'v1', owner: 'home');

      final List<String?> videoEvents = <String?>[];
      final sub = focus.activeVideoStream.listen(videoEvents.add);
      focus.resetFocusState();
      await Future<void>.delayed(Duration.zero);

      expect(focus.activeVideoId, isNull);
      expect(focus.activeOwner, isNull);
      expect(focus.pendingFocusRequests, isEmpty);
      expect(videoEvents, contains(null));

      await sub.cancel();
    });

    test('isDisposingActiveOwner matches nested owners', () {
      focus.publishActiveOwner('home');
      expect(focus.isDisposingActiveOwner('home'), isTrue);
      expect(focus.isDisposingActiveOwner('home/forYou'), isTrue);
      expect(focus.isDisposingActiveOwner('discover'), isFalse);
    });
  });
}
