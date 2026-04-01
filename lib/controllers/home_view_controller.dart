import 'dart:developer';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/playback_owners.dart';
import '../models/feed_tab.dart';
import '../models/home_video.dart';
import '../providers/feed_state_provider.dart';
import '../providers/home_provider.dart' as hp;
import '../services/global_playback_manager.dart';

enum HomeViewLifecycleState {
  idle,
  activeOwner,
  background,
}

class HomeViewControllerState {
  const HomeViewControllerState({
    required this.lifecycleState,
    required this.currentIndex,
    required this.forYouIndex,
    required this.followingIndex,
    required this.shouldResumeOnReturn,
    required this.isNavigatingToDiscover,
    required this.lastReactivateAt,
  });

  final HomeViewLifecycleState lifecycleState;
  final int currentIndex;
  final int forYouIndex;
  final int followingIndex;
  final bool shouldResumeOnReturn;
  final bool isNavigatingToDiscover;
  final DateTime? lastReactivateAt;

  HomeViewControllerState copyWith({
    HomeViewLifecycleState? lifecycleState,
    int? currentIndex,
    int? forYouIndex,
    int? followingIndex,
    bool? shouldResumeOnReturn,
    bool? isNavigatingToDiscover,
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

  void restoreFeedIndex(FeedTab feed) {
    final int targetIndex = currentIndexForFeed(feed);
    if (targetIndex == state.currentIndex) return;
    state = state.copyWith(currentIndex: targetIndex);
  }

  void setCurrentIndexForFeed(FeedTab feed, int index) {
    final int safeIndex = index < 0 ? 0 : index;
    switch (feed) {
      case FeedTab.forYou:
        state = state.copyWith(
          currentIndex: safeIndex,
          forYouIndex: safeIndex,
        );
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

  void markNavigatingAway({required String reason}) {
    final GlobalPlaybackManager manager = GlobalPlaybackManager.instance;
    log('🔇 HomeViewController: Navigating away - blocking and pausing');
    markAsBackground(shouldResumeOnReturn: true);
    manager.block(reason: reason);
    manager.pauseAll();
    manager.onLeaveHomeView();
  }

  void resumeAfterOverlayDismissal() {
    final GlobalPlaybackManager manager = GlobalPlaybackManager.instance;
    manager.unblock();
    manager.setActiveOwner(PlaybackOwners.home);
    markAsActiveOwner();
    _resumeCurrentVideoInstantly();
  }

  void resumeCurrentVideoInstantly() {
    _resumeCurrentVideoInstantly();
  }

  void handleReturnedToHome({
    required bool isRouteCurrent,
  }) {
    if (!isRouteCurrent) return;
    if (state.isNavigatingToDiscover) return;
    _reactivateFeed(
      reason: 'return_to_home',
      requireCooldown: true,
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
      log('🔄 HomeViewController: App resumed but route not current → skip');
      state = state.copyWith(shouldResumeOnReturn: true);
      return;
    }
    log('🔄 HomeViewController: App resumed & visible → reactivating feed');
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

    log('🔄 HomeViewController: Reactivating feed ($reason)');
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

  void _resumeCurrentVideoInstantly() {
    try {
      final hp.HomeState homeState = ref.read(hp.homeProvider);
      final FeedTab activeFeed = ref.read(activeFeedProvider);
      final List<HomeVideo> currentVideos = switch (activeFeed) {
        FeedTab.forYou => homeState.forYouVideos,
        FeedTab.following => homeState.followingVideos,
        FeedTab.threads => const <HomeVideo>[],
      };
      if (currentVideos.isEmpty) {
        log('⚠️ HomeViewController: No videos available to resume');
        return;
      }
      final int safeIndex =
          state.currentIndex.clamp(0, currentVideos.length - 1);
      final HomeVideo currentVideo = currentVideos[safeIndex];
      final String videoId = currentVideo.id;
      const String ownerId = PlaybackOwners.home;
      if (videoId.isEmpty) return;
      GlobalPlaybackManager.instance.requestFocus(videoId, ownerId);
    } catch (e, stackTrace) {
      log('❌ HomeViewController: Error resuming current video: $e');
      log('Stack trace: $stackTrace');
    }
  }
}

final NotifierProvider<HomeViewController, HomeViewControllerState>
    homeViewControllerProvider =
    NotifierProvider<HomeViewController, HomeViewControllerState>(
        HomeViewController.new);
