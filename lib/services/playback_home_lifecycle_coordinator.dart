import 'package:flutter/widgets.dart';

import '../constants/playback_owners.dart';

/// Home surface enter/leave and app lifecycle hooks for playback.
class PlaybackHomeLifecycleCoordinator {
  const PlaybackHomeLifecycleCoordinator();

  void onEnterHomeView({
    required void Function(String owner) setActiveOwner,
    required void Function() restoreCurrentFeedFocus,
    void Function(String message)? log,
  }) {
    log?.call('🏠 PlaybackManager: Entering HomeView');
    setActiveOwner(PlaybackOwners.home);
    restoreCurrentFeedFocus();
  }

  void restoreCurrentFeedFocus({
    required int? currentFeedIndex,
    required String? Function(int index) videoIdAtIndex,
    required void Function(String owner, {String? exceptVideoId})
        clearDesiredFocusForOwner,
    required void Function(String videoId, String owner) setDesiredFocus,
    void Function(String message)? log,
  }) {
    if (currentFeedIndex == null) {
      return;
    }
    log?.call('📺 PlaybackManager: Current index is $currentFeedIndex');
    final String? videoId = videoIdAtIndex(currentFeedIndex);
    if (videoId == null) {
      return;
    }
    clearDesiredFocusForOwner(
      PlaybackOwners.home,
      exceptVideoId: videoId,
    );
    log?.call(
      '🎵 PlaybackManager: Restoring focus for video $videoId '
      'at index $currentFeedIndex',
    );
    setDesiredFocus(videoId, PlaybackOwners.home);
  }

  void onLeaveHomeView({
    required void Function() saveCurrentPosition,
    required void Function(String owner) clearDesiredFocusForOwner,
    required void Function() pauseAll,
    void Function(String message)? log,
  }) {
    log?.call('🚪 PlaybackManager: Leaving HomeView');
    saveCurrentPosition();
    clearDesiredFocusForOwner(PlaybackOwners.home);
    pauseAll();
  }

  void onAppLifecycleChanged({
    required AppLifecycleState state,
    required void Function() saveCurrentPosition,
    required void Function() pauseAll,
    required int? currentFeedIndex,
    void Function(String message)? log,
  }) {
    log?.call('📱 PlaybackManager: App lifecycle changed to $state');
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      saveCurrentPosition();
      pauseAll();
      return;
    }
    if (state == AppLifecycleState.resumed && currentFeedIndex != null) {
      log?.call(
        '🔄 PlaybackManager: App resumed, will recover at index '
        '$currentFeedIndex',
      );
    }
  }
}
