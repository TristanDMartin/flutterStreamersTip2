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
  });

  @override
  ConsumerState<HomeContentWidget> createState() => _HomeContentWidgetState();
}

class _HomeContentWidgetState extends ConsumerState<HomeContentWidget> {
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
            onForYouTap: () => widget.onTabChange('For You'),
            onFollowingTap: () => widget.onTabChange('Following'),
            onDiscoverTap: widget.onDiscoverTap,
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
      onPageChanged: widget.onPageChanged,
      onVideoTap: widget.onVideoTap,
      onLeftSwipe: widget.onLeftSwipe,
      onRightSwipe: widget.onRightSwipe,
    );
  }
}
