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

/// Provider that gives us the current feed's display name
final activeFeedDisplayNameProvider = Provider<String>((ref) {
  final FeedTab activeFeed = ref.watch(activeFeedProvider);
  return activeFeed.displayName;
});

/// Provider that gives us the current feed's tab ID for video coordination
final activeFeedTabIdProvider = Provider<String>((ref) {
  final FeedTab activeFeed = ref.watch(activeFeedProvider);
  return activeFeed.tabId;
});

/// Helper function to switch feeds with proper cleanup
/// This only affects HomeView - other views maintain their own independent state
Future<void> switchFeed(WidgetRef ref, FeedTab newFeed) async {
  final FeedTab currentFeed = ref.read(activeFeedProvider);
  if (currentFeed == newFeed) {
    log('⏭️ switchFeed: Already on ${newFeed.displayName}');
    return;
  }
  log('🔄 switchFeed: ${currentFeed.displayName} → ${newFeed.displayName}');
  final GlobalPlaybackManager playbackManager =
      ref.read(globalPlaybackManagerProvider);
  playbackManager.pauseAll();
  ref.read(activeFeedProvider.notifier).setActiveFeed(newFeed);
  final HomeViewModel homeViewModel = ref.read(homeProvider.notifier);
  await homeViewModel.switchFeed(newFeed);
}

/// Provider for videos that depends on active feed
final ProviderFamily<List<Object?>, FeedTab> videosProvider =
    Provider.family<List<Object?>, FeedTab>((ref, feedTab) {
  // This will be implemented by the home provider
  // The key is that it depends on the feedTab parameter
  return const <Object?>[];
});

/// Provider for paging state per feed
final pagingStateProvider =
    Provider.family<Map<String, Object?>, FeedTab>((ref, feedTab) {
  // Separate paging state for each feed
  return const <String, Object?>{};
});

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
    homeViewReactivateProvider =
    NotifierProvider<HomeViewReactivateNotifier, bool>(
        HomeViewReactivateNotifier.new);
