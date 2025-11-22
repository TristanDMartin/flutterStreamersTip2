import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:developer';
import '../../models/home_video.dart';
import '../../providers/home_provider.dart' as hp;
import '../../models/feed_tab.dart';
import '../../services/global_playback_manager.dart';
import 'feed_selector_widget.dart';
import 'video_page_view_widget.dart';
import 'loading_state_widget.dart';

/// Main content widget for HomeView (combines all components)
class HomeContentWidget extends ConsumerStatefulWidget {
  final String activeTab;
  final int currentIndex;
  final Function(String) onTabChange;
  final Function(int) onPageChanged;
  final Function(HomeVideo) onVideoTap;
  final Function(HomeVideo) onLeftSwipe;
  final Function(HomeVideo) onRightSwipe;
  final VoidCallback onDiscoverTap;
  final VoidCallback onNetworkTap;
  final Function(VoidCallback)?
      onScrollControllerReady; // Pass scroll callback up

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
  });

  @override
  ConsumerState<HomeContentWidget> createState() => _HomeContentWidgetState();
}

class _HomeContentWidgetState extends ConsumerState<HomeContentWidget> {
  bool _showScrollToTop = false;
  VoidCallback? _scrollCallback;

  /// Handle pull-to-refresh at top of feed (index 0)
  Future<void> _handlePullToRefresh(String activeTab) async {
    log('🔄 HomeContent: Pull-to-refresh triggered for $activeTab feed at index 0');
    try {
      final homeProviderNotifier = ref.read(hp.homeProvider.notifier);
      final feedTab = activeTab == 'For You' ? FeedTab.forYou : FeedTab.following;
      
      // Refresh feed - this will get newest videos from Firestore (newest first)
      await homeProviderNotifier.refreshFeedByTab(feedTab);
      
      // 🎬 TIKTOK-STYLE: Preserve index 0 after refresh
      if (mounted) {
        // Notify GlobalPlaybackManager to update index 0 with new video
        final homeState = ref.read(hp.homeProvider);
        final videos = feedTab == FeedTab.forYou
            ? homeState.forYouVideos
            : homeState.followingVideos;
        
        if (videos.isNotEmpty) {
          final newTopVideo = videos[0];
          GlobalPlaybackManager.instance.onVisibleIndexChanged(0, newTopVideo);
          log('✅ HomeContent: Feed refreshed - newest video at index 0: ${newTopVideo.id}');
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

    // Get videos based on active tab
    final videos = widget.activeTab == 'For You'
        ? homeState.forYouVideos
        : homeState.followingVideos;

    final isLoading = widget.activeTab == 'For You'
        ? homeState.isLoading
        : homeState.isLoading;

    final hasError = homeState.error != null && homeState.error!.isNotEmpty;

    // 🔍 DIAGNOSTIC: Log video count for debugging
    if (kDebugMode) {
      debugPrint('📊 HomeContent: Building - videos: ${videos.length}, isLoading: $isLoading, activeTab: ${widget.activeTab}');
      if (videos.isEmpty && !isLoading) {
        debugPrint('⚠️ HomeContent: ⚠️⚠️⚠️ NO VIDEOS AVAILABLE! ⚠️⚠️⚠️');
        debugPrint('   Check console for "SKIPPING" messages from VideoService');
        debugPrint('   Check Firestore for videos with status="published" and privacy="Everyone"');
      }
    }

    return Stack(
      children: [
        // Video content fills entire screen
        Positioned.fill(
          child: _buildVideoContent(videos, isLoading, hasError),
        ),

        // Header overlay on top of video
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: FeedSelectorWidget(
            activeTab: widget.activeTab,
            onForYouTap: () {
              log('🔘 HomeContent: For You tapped, current tab: ${widget.activeTab}');
              widget.onTabChange('For You');
            },
            onFollowingTap: () {
              log('🔘 HomeContent: Following tapped, current tab: ${widget.activeTab}');
              debugPrint(
                  '🔘 HomeContent: Following tapped, calling onTabChange');
              widget.onTabChange('Following');
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
                  color: const Color(0xFF9248D2),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
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
      List<HomeVideo> videos, bool isLoading, bool hasError) {
    if (hasError) {
      final homeState = ref.read(hp.homeProvider);
      return ErrorStateWidget(
        message: homeState.error ?? 'Failed to load videos. Please try again.',
        onRetry: () {
          log('🔄 HomeContent: Retrying video load');
          final homeProviderNotifier = ref.read(hp.homeProvider.notifier);
          homeProviderNotifier.retryLoadVideos();
        },
      );
    }

    if (isLoading && videos.isEmpty) {
      return const LoadingStateWidget(
        message: 'Loading videos...',
      );
    }

    if (videos.isEmpty) {
      return const LoadingStateWidget(
        message: 'No videos available',
        showProgress: false,
      );
    }

    return VideoPageViewWidget(
      videos: videos,
      currentIndex: widget.currentIndex,
      tabId: widget.activeTab == 'For You' ? 'home/forYou' : 'home/following',
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
      onRefresh: widget.currentIndex == 0 
          ? () => _handlePullToRefresh(widget.activeTab)
          : null,
    );
  }
}
