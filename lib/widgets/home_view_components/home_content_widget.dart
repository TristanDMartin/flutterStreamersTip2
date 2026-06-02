import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../components/onboarding/product_tour_target_keys.dart';
import '../../models/home_video.dart';
import '../../providers/home_provider.dart' as hp;
import '../../providers/feed_state_provider.dart';
import '../../models/feed_tab.dart';
import '../../services/global_playback_manager.dart';
import '../../constants/app_colors.dart';
import 'feed_selector_widget.dart';
import 'video_page_view_widget.dart';
import 'loading_state_widget.dart';
import '../../widgets/threads/threads_list_view.dart';
import '../../features/gamification/widgets/creator_progression_panel.dart';
import '../../qa/qa_keys.dart';
import 'package:streamers_tip/utils/secure_log.dart';

/// Main content widget for HomeView (combines all components)
class HomeContentWidget extends ConsumerStatefulWidget {
  final FeedTab activeTab;
  final int currentIndex;
  final ValueChanged<FeedTab> onTabChange;
  final Function(int) onPageChanged;
  final Function(HomeVideo) onVideoTap;
  final Function(HomeVideo) onLeftSwipe;
  final Function(HomeVideo) onRightSwipe;
  final VoidCallback onDiscoverTap;
  final VoidCallback onNetworkTap;
  final void Function(HomeFeedPageControls)? onScrollControllerReady;
  final bool showCommandCenterTrigger;
  final VoidCallback? onCommandCenterTap;
  final ValueChanged<bool>? onFeedSelectorOpenChanged;

  const HomeContentWidget({
    super.key,
    required this.activeTab,
    required this.currentIndex,
    required this.onTabChange,
    required this.onPageChanged,
    required this.onVideoTap,
    required this.onLeftSwipe,
    required this.onRightSwipe,
    required this.onDiscoverTap,
    required this.onNetworkTap,
    this.onScrollControllerReady,
    this.showCommandCenterTrigger = false,
    this.onCommandCenterTap,
    this.onFeedSelectorOpenChanged,
  });

  @override
  ConsumerState<HomeContentWidget> createState() => _HomeContentWidgetState();
}

class _HomeContentWidgetState extends ConsumerState<HomeContentWidget> {
  String? _lastBuildLogSignature;
  DateTime? _lastBuildLogAt;

  /// Handle pull-to-refresh at top of feed (index 0)
  Future<void> _handlePullToRefresh(FeedTab activeTab) async {
    secureLog(
      '🔄 HomeContent: Pull-to-refresh triggered for ${activeTab.displayName} feed at index 0',
    );
    try {
      final homeProviderNotifier = ref.read(hp.homeProvider.notifier);
      if (!activeTab.supportsRefresh) {
        return;
      }

      // Refresh feed - this will get newest videos from Firestore (newest first)
      await homeProviderNotifier.refreshFeedByTab(activeTab);

      // 🎬 TIKTOK-STYLE: Preserve index 0 after refresh
      if (mounted) {
        // Notify GlobalPlaybackManager to update index 0 with new video
        final homeState = ref.read(hp.homeProvider);
        final videos = homeState.feedData(activeTab).videos;
        if (videos.isNotEmpty) {
          final newTopVideo = videos[0];
          GlobalPlaybackManager.instance.onVisibleIndexChanged(0, newTopVideo);
          secureLog(
            '✅ HomeContent: Feed refreshed - newest video at index 0: ${newTopVideo.id}',
          );
        }
      }
    } catch (e) {
      secureLog('❌ HomeContent: Error refreshing feed: $e');
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    final homeState = ref.watch(hp.homeProvider);
    final activeFeed = widget.activeTab;
    final feedData = homeState.feedData(activeFeed);
    final videos = feedData.videos;
    final isLoading = feedData.isLoading;
    final hasError = feedData.hasError;

    if (kDebugMode &&
        _shouldLogFeedBuild(activeFeed, videos, isLoading, hasError)) {
      debugPrint(
        '📊 HomeContent[$activeFeed]: videos=${videos.length}, isLoading=$isLoading, hasError=$hasError',
      );
      if (videos.isEmpty && !isLoading) {
        debugPrint('⚠️ HomeContent[$activeFeed]: no items available');
      }
    }

    return Stack(
      key: activeFeed == FeedTab.forYou ? QaKeys.homeFeedSurface : null,
      children: <Widget>[
        KeyedSubtree(
          key: ProductTourTargetKeys.maybe(ProductTourTargetKeys.homeFeed),
          child: Positioned.fill(
            child: _buildVideoContent(videos, isLoading, hasError),
          ),
        ),

        if (activeFeed == FeedTab.forYou && hasError && videos.isNotEmpty)
          Positioned(
            top: MediaQuery.of(context).padding.top + 68,
            left: 16,
            right: 16,
            child: _buildInlineFeedStatus(
              message: homeState.error ?? 'Connection is unstable.',
              onRetry: () {
                final homeProviderNotifier = ref.read(hp.homeProvider.notifier);
                homeProviderNotifier.retryLoadVideos();
              },
            ),
          ),

        // Header overlay on top of video
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: FeedSelectorWidget(
            activeTab: widget.activeTab,
            onDropdownOpenChanged: widget.onFeedSelectorOpenChanged,
            onTabSelected: (FeedTab selectedTab) {
              secureLog(
                '🔘 HomeContent: ${selectedTab.displayName} tapped, current tab: ${widget.activeTab.displayName}',
              );
              widget.onTabChange(selectedTab);
            },
            onDiscoverTap: widget.onDiscoverTap,
          ),
        ),
      ],
    );
  }

  bool _shouldLogFeedBuild(
    FeedTab activeFeed,
    List<HomeVideo> videos,
    bool isLoading,
    bool hasError,
  ) {
    final signature = '$activeFeed:${videos.length}:$isLoading:$hasError';
    final now = DateTime.now();
    final lastAt = _lastBuildLogAt;
    final shouldLog = signature != _lastBuildLogSignature ||
        lastAt == null ||
        now.difference(lastAt) > const Duration(seconds: 5);

    if (shouldLog) {
      _lastBuildLogSignature = signature;
      _lastBuildLogAt = now;
    }
    return shouldLog;
  }

  Widget _buildVideoContent(
    List<HomeVideo> videos,
    bool isLoading,
    bool hasError,
  ) {
    final PostPublishFeedPrepState postPublishPrep =
        ref.watch(postPublishFeedPrepProvider);
    final homeState = ref.read(hp.homeProvider);
    final activeFeed = widget.activeTab;
    // FeedTab.following is intentionally displayed as "Progression" in the
    // Home selector. It is a creator progress surface, not a video feed.
    if (activeFeed == FeedTab.following) {
      return const CreatorProgressionPanel();
    }

    // Threads tab: Show threads list view
    if (activeFeed == FeedTab.threads) {
      return const ThreadsListView();
    }

    if (postPublishPrep.isActive && activeFeed == FeedTab.forYou) {
      return const LoadingStateWidget(
        message: feedPrepAfterPublishMessage,
        showProgress: true,
      );
    }

    if (hasError) {
      if (activeFeed == FeedTab.forYou && videos.isNotEmpty) {
        return VideoPageViewWidget(
          videos: videos,
          currentIndex: widget.currentIndex,
          tabId: activeFeed.tabId,
          showCommandCenterTrigger: widget.showCommandCenterTrigger,
          onCommandCenterTap: widget.onCommandCenterTap,
          onPageChanged: widget.onPageChanged,
          onVideoTap: widget.onVideoTap,
          onLeftSwipe: widget.onLeftSwipe,
          onRightSwipe: widget.onRightSwipe,
          onControllerReady: widget.onScrollControllerReady,
          onRefresh: () => _handlePullToRefresh(activeFeed),
        );
      }
      return ErrorStateWidget(
        message: homeState.error ?? 'Failed to load videos. Please try again.',
        onRetry: () {
          secureLog('🔄 HomeContent: Retrying ${activeFeed.displayName} feed');
          final homeProviderNotifier = ref.read(hp.homeProvider.notifier);
          if (activeFeed == FeedTab.forYou) {
            homeProviderNotifier.retryLoadVideos();
            return;
          }
          _handlePullToRefresh(activeFeed);
        },
      );
    }

    if (videos.isEmpty && (isLoading || !homeState.hasLoaded)) {
      return const LoadingStateWidget(message: 'Loading videos...');
    }

    if (videos.isEmpty) {
      return LoadingStateWidget(
        message: 'No videos available',
        showProgress: false,
      );
    }

    return VideoPageViewWidget(
      videos: videos,
      currentIndex: widget.currentIndex,
      tabId: activeFeed.tabId,
      showCommandCenterTrigger: widget.showCommandCenterTrigger,
      onCommandCenterTap: widget.onCommandCenterTap,
      onPageChanged: widget.onPageChanged,
      onVideoTap: widget.onVideoTap,
      onLeftSwipe: widget.onLeftSwipe,
      onRightSwipe: widget.onRightSwipe,
      onControllerReady: widget.onScrollControllerReady,
      onRefresh: () => _handlePullToRefresh(activeFeed),
    );
  }

  Widget _buildInlineFeedStatus({
    required String message,
    required VoidCallback onRetry,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.36),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.12),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            Icons.wifi_off_rounded,
            color: Colors.white.withValues(alpha: 0.92),
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: SelectableText.rich(
              TextSpan(
                text: message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              maxLines: 2,
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: onRetry,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.supportAccent.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: AppColors.supportAccent.withValues(alpha: 0.55),
                ),
              ),
              child: const Text(
                'Retry',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
