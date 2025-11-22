import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/feed_tab.dart';
import '../services/global_playback_manager.dart';
import 'home_provider.dart';

/// Single source of truth for the active feed tab
/// This provider manages the current feed selection and ensures consistent state
/// Scoped to HomeView only - does not affect other views
final activeFeedProvider = StateProvider<FeedTab>((ref) => FeedTab.forYou);

/// Provider that gives us the current feed's display name
final activeFeedDisplayNameProvider = Provider<String>((ref) {
  final activeFeed = ref.watch(activeFeedProvider);
  return activeFeed.displayName;
});

/// Provider that gives us the current feed's tab ID for video coordination
final activeFeedTabIdProvider = Provider<String>((ref) {
  final activeFeed = ref.watch(activeFeedProvider);
  return activeFeed.tabId;
});

/// Helper function to switch feeds with proper cleanup
/// This only affects HomeView - other views maintain their own independent state
void switchFeed(WidgetRef ref, FeedTab newFeed) {
  final currentFeed = ref.read(activeFeedProvider);

  print('🔄 switchFeed: currentFeed=$currentFeed, newFeed=$newFeed');

  // Don't switch if already on the target feed
  if (currentFeed == newFeed) {
    print('⚠️ switchFeed: Already on ${newFeed.displayName}, skipping switch');
    return;
  }

  print(
      '✅ switchFeed: Proceeding with switch from ${currentFeed.displayName} to ${newFeed.displayName}');

  // 🔥 FIX: Don't dispose all controllers - just pause current video
  final playbackManager = ref.read(globalPlaybackManagerProvider);
  playbackManager.pauseAll(); // Just pause, don't dispose

  // Update the active feed (HomeView only)
  ref.read(activeFeedProvider.notifier).state = newFeed;
  print('✅ switchFeed: Updated activeFeedProvider to ${newFeed.displayName}');

  // 🔥 FIX: Call the actual HomeViewModel switchFeed method to load videos
  final homeVM = ref.read(homeProvider.notifier);
  homeVM.switchFeed(newFeed);
  print(
      '✅ switchFeed: Called HomeViewModel.switchFeed(${newFeed.displayName})');

  // 🔥 FIX: Don't auto-resume - let the new feed handle video playback
  // The new feed will automatically start playing its first video
  print('🎵 switchFeed: Ready for new feed to handle video playback');
}

/// Provider for videos that depends on active feed
final videosProvider = Provider.family<List<dynamic>, FeedTab>((ref, feedTab) {
  // This will be implemented by the home provider
  // The key is that it depends on the feedTab parameter
  return [];
});

/// Provider for paging state per feed
final pagingStateProvider =
    Provider.family<Map<String, dynamic>, FeedTab>((ref, feedTab) {
  // Separate paging state for each feed
  return {};
});

/// Provider to trigger HomeView feed reactivation
/// Used by MainTabView to notify HomeView to reactivate when returning from navigation
final homeViewReactivateProvider = StateProvider<bool>((ref) => false);
