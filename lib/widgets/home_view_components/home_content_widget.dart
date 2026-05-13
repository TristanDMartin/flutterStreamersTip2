import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:developer';
import '../../components/onboarding/product_tour_target_keys.dart';
import '../../models/home_video.dart';
import '../../providers/home_provider.dart' as hp;
import '../../models/feed_tab.dart';
import '../../services/global_playback_manager.dart';
import '../../constants/app_colors.dart';
import 'feed_selector_widget.dart';
import 'video_page_view_widget.dart';
import 'loading_state_widget.dart';
import '../../widgets/threads/threads_list_view.dart';
import '../../features/gamification/widgets/creator_progression_panel.dart';

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
  final Function(VoidCallback)?
      onScrollControllerReady; // Pass scroll callback up
  final bool showCommandCenterTrigger;
  final VoidCallback? onCommandCenterTap;

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
  });

  @override
  ConsumerState<HomeContentWidget> createState() => _HomeContentWidgetState();
}

class _HomeContentWidgetState extends ConsumerState<HomeContentWidget> {
  bool _showScrollToTop = false;
  VoidCallback? _scrollCallback;

  /// Handle pull-to-refresh at top of feed (index 0)
  Future<void> _handlePullToRefresh(FeedTab activeTab) async {
    log(
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
          log(
            '✅ HomeContent: Feed refreshed - newest video at index 0: ${newTopVideo.id}',
          );
        }
      }
    } catch (e) {
      log('❌ HomeContent: Error refreshing feed: $e');
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

    if (kDebugMode) {
      debugPrint(
        '📊 HomeContent[$activeFeed]: videos=${videos.length}, isLoading=$isLoading, hasError=$hasError',
      );
      if (videos.isEmpty && !isLoading) {
        debugPrint('⚠️ HomeContent[$activeFeed]: no items available');
      }
    }

    return Stack(
      children: <Widget>[
        KeyedSubtree(
          key: ProductTourTargetKeys.homeFeed,
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
            onTabSelected: (FeedTab selectedTab) {
              log(
                '🔘 HomeContent: ${selectedTab.displayName} tapped, current tab: ${widget.activeTab.displayName}',
              );
              widget.onTabChange(selectedTab);
            },
            onDiscoverTap: widget.onDiscoverTap,
          ),
        ),

        // Scroll to top button (TikTok-style)
        if (_showScrollToTop)
          Positioned(
            bottom: 100,
            right: 16,
            child: GestureDetector(
              onTap: () {
                log('⬆️ HomeContent: Scroll to top tapped');
                // Call the scroll callback from VideoPageViewWidget
                if (_scrollCallback != null) {
                  _scrollCallback!();
                  setState(() {
                    _showScrollToTop = false;
                  });
                }
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: AppColors.supportAccentGradient,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.34),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.arrow_upward,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildVideoContent(
    List<HomeVideo> videos,
    bool isLoading,
    bool hasError,
  ) {
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

    if (hasError) {
      if (activeFeed == FeedTab.forYou && videos.isNotEmpty) {
        return VideoPageViewWidget(
          videos: videos,
          currentIndex: widget.currentIndex,
          tabId: activeFeed.tabId,
          showCommandCenterTrigger: widget.showCommandCenterTrigger,
          onCommandCenterTap: widget.onCommandCenterTap,
          onPageChanged: (index) {
            widget.onPageChanged(index);
            if (mounted) {
              setState(() {
                _showScrollToTop = index > 2;
              });
            }
          },
          onVideoTap: widget.onVideoTap,
          onLeftSwipe: widget.onLeftSwipe,
          onRightSwipe: widget.onRightSwipe,
          onControllerReady: (callback) {
            _scrollCallback = callback;
            if (widget.onScrollControllerReady != null) {
              widget.onScrollControllerReady!(callback);
            }
          },
          onRefresh: () => _handlePullToRefresh(activeFeed),
        );
      }
      return ErrorStateWidget(
        message: homeState.error ?? 'Failed to load videos. Please try again.',
        onRetry: () {
          log('🔄 HomeContent: Retrying ${activeFeed.displayName} feed');
          final homeProviderNotifier = ref.read(hp.homeProvider.notifier);
          if (activeFeed == FeedTab.forYou) {
            homeProviderNotifier.retryLoadVideos();
            return;
          }
          _handlePullToRefresh(activeFeed);
        },
      );
    }

    if (isLoading && videos.isEmpty) {
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
      onPageChanged: (index) {
        widget.onPageChanged(index);
        // Show scroll-to-top button when scrolled past first video
        if (mounted) {
          setState(() {
            _showScrollToTop = index > 2; // Show after 3rd video
          });
        }
      },
      onVideoTap: widget.onVideoTap,
      onLeftSwipe: widget.onLeftSwipe,
      onRightSwipe: widget.onRightSwipe,
      onControllerReady: (callback) {
        // Store callback locally for scroll-to-top button
        _scrollCallback = callback;
        // Also pass up to HomeView
        if (widget.onScrollControllerReady != null) {
          widget.onScrollControllerReady!(callback);
        }
      },
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
            child: Text(
              message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
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
