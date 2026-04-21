import 'dart:developer';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/feed_tab.dart';
import '../services/global_playback_manager.dart';
import 'home_provider.dart';

/// Single source of truth for the active feed tab
/// This provider manages the current feed selection and ensures consistent state
/// Scoped to HomeView only - does not affect other views
class ActiveFeedNotifier extends Notifier<FeedTab> {
  @override
  FeedTab build() => FeedTab.forYou;

  void setActiveFeed(FeedTab feedTab) {
    state = feedTab;
  }
}

final NotifierProvider<ActiveFeedNotifier, FeedTab> activeFeedProvider =
    NotifierProvider<ActiveFeedNotifier, FeedTab>(ActiveFeedNotifier.new);

/// Helper function to switch feeds with proper cleanup
/// This only affects HomeView - other views maintain their own independent state
Future<void> switchFeed(WidgetRef ref, FeedTab newFeed) async {
  final FeedTab currentFeed = ref.read(activeFeedProvider);
  if (currentFeed == newFeed) {
    log('⏭️ switchFeed: Already on ${newFeed.displayName}');
    return;
  }
  log('🔄 switchFeed: ${currentFeed.displayName} → ${newFeed.displayName}');
  final GlobalPlaybackManager playbackManager = ref.read(
    globalPlaybackManagerProvider,
  );
  playbackManager.pauseAll();
  ref.read(activeFeedProvider.notifier).setActiveFeed(newFeed);
  final HomeViewModel homeViewModel = ref.read(homeProvider.notifier);
  await homeViewModel.switchFeed(newFeed);
}

/// Provider to trigger HomeView feed reactivation
/// Used by MainTabView to notify HomeView to reactivate when returning from navigation
class HomeViewReactivateNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void triggerReactivation() {
    state = true;
  }

  void clearReactivation() {
    state = false;
  }
}

final NotifierProvider<HomeViewReactivateNotifier, bool>
homeViewReactivateProvider = NotifierProvider<HomeViewReactivateNotifier, bool>(
  HomeViewReactivateNotifier.new,
);
