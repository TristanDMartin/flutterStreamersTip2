import 'dart:async' show unawaited;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:streamers_tip/utils/secure_log.dart';
import 'package:video_player/video_player.dart';

import '../constants/playback_owners.dart';
import '../models/feed_tab.dart';
import '../models/home_video.dart';
import '../providers/feed_state_provider.dart';
import '../providers/home_provider.dart' as hp;
import '../services/global_playback_manager.dart';

enum HomeViewLifecycleState { idle, activeOwner, background }

class HomeViewControllerState {
  const HomeViewControllerState({
    required this.lifecycleState,
    required this.currentIndex,
    required this.forYouIndex,
    required this.followingIndex,
    required this.shouldResumeOnReturn,
    required this.isNavigatingToDiscover,
    required this.isColdOpenResetDone,
    required this.lastReactivateAt,
  });

  final HomeViewLifecycleState lifecycleState;
  final int currentIndex;
  final int forYouIndex;
  final int followingIndex;
  final bool shouldResumeOnReturn;
  final bool isNavigatingToDiscover;
  final bool isColdOpenResetDone;
  final DateTime? lastReactivateAt;

  HomeViewControllerState copyWith({
    HomeViewLifecycleState? lifecycleState,
    int? currentIndex,
    int? forYouIndex,
    int? followingIndex,
    bool? shouldResumeOnReturn,
    bool? isNavigatingToDiscover,
    bool? isColdOpenResetDone,
    DateTime? lastReactivateAt,
  }) {
    return HomeViewControllerState(
      lifecycleState: lifecycleState ?? this.lifecycleState,
      currentIndex: currentIndex ?? this.currentIndex,
      forYouIndex: forYouIndex ?? this.forYouIndex,
      followingIndex: followingIndex ?? this.followingIndex,
      shouldResumeOnReturn: shouldResumeOnReturn ?? this.shouldResumeOnReturn,
      isNavigatingToDiscover:
          isNavigatingToDiscover ?? this.isNavigatingToDiscover,
      isColdOpenResetDone: isColdOpenResetDone ?? this.isColdOpenResetDone,
      lastReactivateAt: lastReactivateAt ?? this.lastReactivateAt,
    );
  }
}

class HomeViewController extends Notifier<HomeViewControllerState> {
  static const Duration _reactivationCooldown = Duration(milliseconds: 500);
  String? _discoverExitVideoId;
  int? _discoverExitControllerId;
  int? _discoverExitPositionMs;
  int? _discoverExitPoolSize;

  @override
  HomeViewControllerState build() {
    return const HomeViewControllerState(
      lifecycleState: HomeViewLifecycleState.idle,
      currentIndex: 0,
      forYouIndex: 0,
      followingIndex: 0,
      shouldResumeOnReturn: false,
      isNavigatingToDiscover: false,
      isColdOpenResetDone: false,
      lastReactivateAt: null,
    );
  }

  int currentIndexForFeed(FeedTab feed) {
    return switch (feed) {
      FeedTab.forYou => state.forYouIndex,
      FeedTab.following => state.followingIndex,
      FeedTab.threads => 0,
    };
  }

  void resetFeedPositionForColdOpen() {
    if (state.currentIndex == 0 &&
        state.forYouIndex == 0 &&
        state.followingIndex == 0 &&
        state.isColdOpenResetDone) {
      return;
    }
    state = state.copyWith(
      currentIndex: 0,
      forYouIndex: 0,
      followingIndex: 0,
      shouldResumeOnReturn: false,
      isColdOpenResetDone: true,
    );
  }

  void restoreFeedIndex(FeedTab feed) {
    final int targetIndex = currentIndexForFeed(feed);
    if (targetIndex == state.currentIndex) return;
    state = state.copyWith(currentIndex: targetIndex);
  }

  void setCurrentIndexForFeed(FeedTab feed, int index) {
    final int safeIndex = index < 0 ? 0 : index;
    switch (feed) {
      case FeedTab.forYou:
        state = state.copyWith(currentIndex: safeIndex, forYouIndex: safeIndex);
      case FeedTab.following:
        state = state.copyWith(
          currentIndex: safeIndex,
          followingIndex: safeIndex,
        );
      case FeedTab.threads:
        state = state.copyWith(currentIndex: 0);
    }
  }

  void setIsNavigatingToDiscover(bool isNavigatingToDiscover) {
    if (isNavigatingToDiscover == state.isNavigatingToDiscover) return;
    state = state.copyWith(isNavigatingToDiscover: isNavigatingToDiscover);
  }

  void markAsActiveOwner() {
    state = state.copyWith(
      lifecycleState: HomeViewLifecycleState.activeOwner,
      lastReactivateAt: DateTime.now(),
    );
  }

  void markAsBackground({required bool shouldResumeOnReturn}) {
    state = state.copyWith(
      lifecycleState: HomeViewLifecycleState.background,
      shouldResumeOnReturn: shouldResumeOnReturn,
    );
  }

  void prepareForOverlay({required String reason}) {
    secureLog('⏸️ HomeViewController: Preparing overlay ($reason)');
    _pauseAndBlock(
      reason: reason,
      leaveHomeView: false,
      shouldResumeOnReturn: true,
    );
  }

  void prepareForRouteNavigation({required String reason}) {
    secureLog('🔇 HomeViewController: Navigating away ($reason)');
    if (reason.contains('discover')) {
      _prepareForDiscoverCover(reason: reason);
      return;
    }
    _pauseAndBlock(
      reason: reason,
      leaveHomeView: true,
      shouldResumeOnReturn: true,
    );
  }

  /// Discover is a pushed route that temporarily covers Home. Keep the current
  /// Home controller warm (same retention model as IndexedStack tab leave).
  void _prepareForDiscoverCover({required String reason}) {
    final GlobalPlaybackManager manager = GlobalPlaybackManager.instance;
    markAsBackground(shouldResumeOnReturn: true);
    final int homeIndex = state.currentIndex;
    final String? homeVideoId = _resolveCurrentHomeVideoId();
    final VideoPlayerController? controller = homeVideoId == null
        ? null
        : manager.getController(homeVideoId);
    final bool initialized = controller?.value.isInitialized == true;
    final int? positionMs =
        initialized ? controller!.value.position.inMilliseconds : null;
    _discoverExitVideoId = homeVideoId;
    _discoverExitControllerId = controller?.hashCode;
    _discoverExitPositionMs = positionMs;
    _discoverExitPoolSize = manager.pooledControllerCount;
    manager.beginHomeTabBackgroundRetention(currentIndex: homeIndex);
    manager.onLeaveHomeView();
    manager.setVisibleOwner(PlaybackOwners.discover);
    manager.block(reason: reason);
    final bool retained = manager.isRetainingHomePoolForTabBackground &&
        homeVideoId != null &&
        manager.hasController(homeVideoId);
    secureLog(
      'HOME_EXIT_TO_DISCOVER homeVideoId=$homeVideoId homeIndex=$homeIndex '
      'positionMs=$positionMs controllerId=${controller?.hashCode} '
      'initialized=$initialized poolSize=${manager.pooledControllerCount} '
      'retained=$retained',
    );
  }

  /// Main-tab leave (IndexedStack): pause only — keep pool, index, and pins.
  void prepareForTabSwitchAway({
    required String reason,
    String? nextActiveOwner,
  }) {
    secureLog('⏸️ HomeViewController: Tab switch away ($reason)');
    final GlobalPlaybackManager manager = GlobalPlaybackManager.instance;
    markAsBackground(shouldResumeOnReturn: true);
    manager.beginHomeTabBackgroundRetention(
      currentIndex: state.currentIndex,
    );
    manager.pauseAllForTabSwitch();
    if (nextActiveOwner != null) {
      manager.setVisibleOwner(nextActiveOwner);
    }
    manager.block(reason: reason);
  }

  void resumeFromTabReturn({bool fromDiscover = false}) {
    final GlobalPlaybackManager manager = GlobalPlaybackManager.instance;
    final String? ownerBefore = manager.visibleOwner;
    final int homeIndex = state.currentIndex;
    final String? homeVideoId = _resolveCurrentHomeVideoId();
    final Duration? savedPosition = manager.lastKnownPositionAt(homeIndex);
    final VideoPlayerController? retainedBefore =
        homeVideoId == null ? null : manager.getController(homeVideoId);
    final bool sameController = fromDiscover &&
        retainedBefore != null &&
        _discoverExitControllerId != null &&
        retainedBefore.hashCode == _discoverExitControllerId &&
        (_discoverExitVideoId == null ||
            _discoverExitVideoId == homeVideoId);
    if (fromDiscover) {
      secureLog(
        'HOME_RETURN_FROM_DISCOVER homeVideoId=$homeVideoId '
        'homeIndex=$homeIndex '
        'savedPositionMs=${savedPosition?.inMilliseconds ?? _discoverExitPositionMs} '
        'controllerId=${retainedBefore?.hashCode} '
        'exitControllerId=$_discoverExitControllerId '
        'controllerFound=${retainedBefore != null} '
        'sameController=$sameController '
        'initialized=${retainedBefore?.value.isInitialized == true} '
        'ownerBefore=$ownerBefore ownerAfter=${PlaybackOwners.home} '
        'poolSize=${manager.pooledControllerCount} '
        'exitPoolSize=$_discoverExitPoolSize',
      );
    }
    manager.clearDesiredFocusForOwner(PlaybackOwners.discover);
    manager.clearDesiredFocusForOwner(PlaybackOwners.discoverPlayer);
    if (manager.isPlaybackBlocked) {
      manager.forceUnblock();
    }
    manager.setVisibleOwner(PlaybackOwners.home);
    manager.setActiveOwner(PlaybackOwners.home);
    manager.endHomeTabBackgroundRetention();
    pinHomeWarmWindowForCurrentIndex();
    markAsActiveOwner();
    manager.restoreCurrentFeedFocus();
    final bool resumedFromRetained = _resumeCurrentVideoInstantly(
      fromDiscover: fromDiscover,
      savedPosition: savedPosition,
      sameController: sameController,
      exitControllerId: _discoverExitControllerId,
    );
    if (fromDiscover) {
      _discoverExitVideoId = null;
      _discoverExitControllerId = null;
      _discoverExitPositionMs = null;
      _discoverExitPoolSize = null;
    }
    if (resumedFromRetained) {
      secureLog('▶️ HomeViewController: Tab return — instant resume');
    } else {
      secureLog(
        '▶️ HomeViewController: Tab return — queued resume '
        '(retained controller unavailable)',
      );
    }
    state = state.copyWith(shouldResumeOnReturn: false);
  }

  void pinHomeWarmWindowForCurrentIndex() {
    GlobalPlaybackManager.instance.pinHomeWarmWindowAtIndex(state.currentIndex);
  }

  void resumeAfterOverlayDismissal() {
    _restoreHomePlaybackAfterSuppression(reason: 'overlay_dismissed');
  }

  void resumeAfterOnboardingCompleted() {
    _restoreHomePlaybackAfterSuppression(reason: 'onboarding_completed');
  }

  void _restoreHomePlaybackAfterSuppression({required String reason}) {
    secureLog('▶️ HomeViewController: Restoring home playback ($reason)');
    final GlobalPlaybackManager manager = GlobalPlaybackManager.instance;
    if (manager.isPlaybackBlocked) {
      manager.forceUnblock();
    }
    manager.setVisibleOwner(PlaybackOwners.home);
    manager.setActiveOwner(PlaybackOwners.home);
    markAsActiveOwner();
    manager.restoreCurrentFeedFocus();
    _resumeCurrentVideoInstantly();
  }

  void resumeCurrentVideoInstantly() {
    _resumeCurrentVideoInstantly();
  }

  void handleReturnedToHome({required bool isRouteCurrent}) {
    if (!isRouteCurrent) return;
    if (state.isNavigatingToDiscover) return;
    resumeFromTabReturn(fromDiscover: true);
  }

  void handleAppLifecycleChanged({
    required AppLifecycleState appLifecycleState,
    required bool isRouteCurrent,
  }) {
    GlobalPlaybackManager.instance.onAppLifecycleChanged(appLifecycleState);
    if (appLifecycleState == AppLifecycleState.paused ||
        appLifecycleState == AppLifecycleState.inactive) {
      if (isRouteCurrent) {
        markAsBackground(shouldResumeOnReturn: true);
      }
      return;
    }
    if (appLifecycleState != AppLifecycleState.resumed) {
      return;
    }
    if (!isRouteCurrent) {
      secureLog(
          '🔄 HomeViewController: App resumed but route not current → skip');
      state = state.copyWith(shouldResumeOnReturn: true);
      return;
    }
    secureLog(
        '🔄 HomeViewController: App resumed & visible → reactivating feed');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _reactivateFeed(
        reason: 'app_resumed_visible',
        requireCooldown: false,
        resumeOnlyWhenNeeded: true,
      );
    });
  }

  bool _canReactivateNow() {
    if (state.lifecycleState != HomeViewLifecycleState.background) return false;
    if (state.lastReactivateAt == null) return true;
    return DateTime.now().difference(state.lastReactivateAt!) >
        _reactivationCooldown;
  }

  void _reactivateFeed({
    required String reason,
    required bool requireCooldown,
    required bool resumeOnlyWhenNeeded,
  }) {
    final GlobalPlaybackManager manager = GlobalPlaybackManager.instance;
    final bool isHomeActiveOwner = manager.activeOwner == PlaybackOwners.home;
    if (requireCooldown && !isHomeActiveOwner && !_canReactivateNow()) return;

    secureLog('🔄 HomeViewController: Reactivating feed ($reason)');
    manager.unblock();
    if (!isHomeActiveOwner) {
      manager.setActiveOwner(PlaybackOwners.home);
    }
    manager.restoreCurrentFeedFocus();
    markAsActiveOwner();

    if (resumeOnlyWhenNeeded && !state.shouldResumeOnReturn) return;
    _resumeCurrentVideoInstantly();
    state = state.copyWith(shouldResumeOnReturn: false);
  }

  void _pauseAndBlock({
    required String reason,
    required bool leaveHomeView,
    required bool shouldResumeOnReturn,
  }) {
    final GlobalPlaybackManager manager = GlobalPlaybackManager.instance;
    markAsBackground(shouldResumeOnReturn: shouldResumeOnReturn);
    manager.block(reason: reason);
    manager.pauseAll();
    if (leaveHomeView) {
      manager.onLeaveHomeView();
    }
  }

  String? _resolveCurrentHomeVideoId() {
    try {
      final hp.HomeState homeState = ref.read(hp.homeProvider);
      final FeedTab activeFeed = ref.read(activeFeedProvider);
      final List<HomeVideo> currentVideos =
          homeState.feedData(activeFeed).videos;
      if (currentVideos.isEmpty) {
        return null;
      }
      final int safeIndex = state.currentIndex.clamp(
        0,
        currentVideos.length - 1,
      );
      final String videoId = currentVideos[safeIndex].id;
      return videoId.isEmpty ? null : videoId;
    } catch (_) {
      return null;
    }
  }

  /// Returns true when a warm pooled controller was available to focus.
  bool _resumeCurrentVideoInstantly({
    bool fromDiscover = false,
    Duration? savedPosition,
    bool sameController = false,
    int? exitControllerId,
  }) {
    try {
      final GlobalPlaybackManager manager = GlobalPlaybackManager.instance;
      final String? videoId = _resolveCurrentHomeVideoId();
      if (videoId == null) {
        secureLog('⚠️ HomeViewController: No videos available to resume');
        return false;
      }
      const String ownerId = PlaybackOwners.home;
      final VideoPlayerController? retained = manager.getController(videoId);
      final bool controllerFound = retained != null;
      final bool initialized = retained?.value.isInitialized == true;
      final String method = controllerFound && initialized
          ? 'retained_controller'
          : 'recreated_controller';
      // Warm retained controllers already have a decoded first frame.
      final int firstFrameMs = controllerFound && initialized ? 0 : -1;
      if (retained != null &&
          retained.value.isInitialized &&
          savedPosition != null &&
          savedPosition > Duration.zero) {
        final Duration current = retained.value.position;
        final Duration delta = (current - savedPosition).abs();
        if (delta > const Duration(milliseconds: 750)) {
          unawaited(retained.seekTo(savedPosition));
        }
      }
      final Stopwatch playWatch = Stopwatch()..start();
      unawaited(
        manager.requestFocus(videoId, ownerId).then((_) {
          playWatch.stop();
          final VideoPlayerController? after = manager.getController(videoId);
          final bool sameAfter = exitControllerId != null &&
              after != null &&
              after.hashCode == exitControllerId;
          secureLog(
            'HOME_RESUME_RESULT method=$method '
            'playCalled=true '
            'isPlaying=${after?.value.isPlaying == true} '
            'positionMs=${after?.value.position.inMilliseconds} '
            'firstFrameMs=$firstFrameMs '
            'focusMs=${playWatch.elapsedMilliseconds} '
            'textureVisible=${after?.value.isInitialized == true} '
            'sameController=${sameController || sameAfter} '
            'fromDiscover=$fromDiscover',
          );
        }),
      );
      return controllerFound && initialized;
    } catch (e, stackTrace) {
      secureLog('❌ HomeViewController: Error resuming current video: $e');
      secureLog('Stack trace: $stackTrace');
      return false;
    }
  }
}

final NotifierProvider<HomeViewController, HomeViewControllerState>
    homeViewControllerProvider =
    NotifierProvider<HomeViewController, HomeViewControllerState>(
  HomeViewController.new,
);
