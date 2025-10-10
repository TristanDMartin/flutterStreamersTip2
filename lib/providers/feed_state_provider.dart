import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/feed_tab.dart';
import '../services/global_playback_manager.dart';

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

  // 1) Stop audio immediately to prevent bleeding
  final playbackManager = ref.read(globalPlaybackManagerProvider);
  playbackManager.pauseAllForTabSwitch();

  // 2) Dispose all controllers bound to old feed
  playbackManager.disposeAll();

  // 3) Update the active feed (HomeView only)
  ref.read(activeFeedProvider.notifier).state = newFeed;
  print('✅ switchFeed: Updated activeFeedProvider to ${newFeed.displayName}');

  // 4) Invalidate video providers to force refetch (HomeView only)
  ref.invalidate(videosProvider);

  // 5) Reset paging state for the new feed (HomeView only)
  ref.invalidate(pagingStateProvider);

  // 6) Resume playback after a brief delay to allow UI to rebuild
  Future.delayed(const Duration(milliseconds: 300), () {
    playbackManager.resumeAfterTabSwitch();
  });
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
