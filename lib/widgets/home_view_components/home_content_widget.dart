import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:developer';
import '../../models/home_video.dart';
import '../../providers/home_provider.dart' as hp;
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

    final hasError =
        false; // HomeState doesn't have error field, handle differently

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
      return ErrorStateWidget(
        message: 'Failed to load videos. Please try again.',
        onRetry: () {
          log('🔄 HomeContent: Retrying video load');
          // Trigger retry logic here
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
    );
  }
}
