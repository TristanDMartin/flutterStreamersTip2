import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:streamers_tip/utils/secure_log.dart';

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
    _pauseAndBlock(
      reason: reason,
      leaveHomeView: true,
      shouldResumeOnReturn: true,
    );
  }

  void resumeAfterOverlayDismissal() {
    final GlobalPlaybackManager manager = GlobalPlaybackManager.instance;
    manager.unblock();
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
    _reactivateFeed(
      reason: 'return_to_home',
      requireCooldown: false,
      resumeOnlyWhenNeeded: false,
    );
  }

  void handleAppLifecycleChanged({
    required AppLifecycleState appLifecycleState,
    required bool isRouteCurrent,
  }) {
    GlobalPlaybackManager.instance.onAppLifecycleChanged(appLifecycleState);
    if (appLifecycleState != AppLifecycleState.resumed) return;
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
        resumeOnlyWhenNeeded: false,
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

  void _resumeCurrentVideoInstantly() {
    try {
      final hp.HomeState homeState = ref.read(hp.homeProvider);
      final FeedTab activeFeed = ref.read(activeFeedProvider);
      final List<HomeVideo> currentVideos =
          homeState.feedData(activeFeed).videos;
      if (currentVideos.isEmpty) {
        secureLog('⚠️ HomeViewController: No videos available to resume');
        return;
      }
      final int safeIndex = state.currentIndex.clamp(
        0,
        currentVideos.length - 1,
      );
      final HomeVideo currentVideo = currentVideos[safeIndex];
      final String videoId = currentVideo.id;
      const String ownerId = PlaybackOwners.home;
      if (videoId.isEmpty) return;
      GlobalPlaybackManager.instance.requestFocus(videoId, ownerId);
    } catch (e, stackTrace) {
      secureLog('❌ HomeViewController: Error resuming current video: $e');
      secureLog('Stack trace: $stackTrace');
    }
  }
}

final NotifierProvider<HomeViewController, HomeViewControllerState>
    homeViewControllerProvider =
    NotifierProvider<HomeViewController, HomeViewControllerState>(
  HomeViewController.new,
);
