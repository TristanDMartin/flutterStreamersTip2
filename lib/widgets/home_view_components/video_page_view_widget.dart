import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:developer';
import '../../models/home_video.dart';
import '../video_player_view_optimized.dart';
// import '../../services/unified_video_control_service.dart'; // Removed unused import
import '../../providers/home_provider.dart';

/// Video page view widget for HomeView (handles video scrolling)
class VideoPageViewWidget extends ConsumerStatefulWidget {
  final List<HomeVideo> videos;
  final int currentIndex;
  final String tabId;
  final Function(int) onPageChanged;
  final Function(HomeVideo) onVideoTap;
  final Function(HomeVideo) onLeftSwipe;
  final Function(HomeVideo) onRightSwipe;

  const VideoPageViewWidget({
    super.key,
    required this.videos,
    required this.currentIndex,
    required this.tabId,
    required this.onPageChanged,
    required this.onVideoTap,
    required this.onLeftSwipe,
    required this.onRightSwipe,
  });

  @override
  ConsumerState<VideoPageViewWidget> createState() =>
      _VideoPageViewWidgetState();
}

class _VideoPageViewWidgetState extends ConsumerState<VideoPageViewWidget> {
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: widget.currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.videos.isEmpty) {
      return _buildEmptyState();
    }

    return GestureDetector(
      onPanEnd: _handleSwipe,
      child: PageView.builder(
        controller: _pageController,
        scrollDirection: Axis.vertical, // Enable vertical swiping
        physics: const ClampingScrollPhysics(), // Better physics for mobile
        onPageChanged: (index) {
          log('🎬 VideoPageView: Page changed to index $index');
          widget.onPageChanged(index);
        },
        itemCount: widget.videos.length,
        itemBuilder: (context, index) {
          final video = widget.videos[index];
          final isCurrentVideo = index == widget.currentIndex;

          return VideoPlayerViewOptimized(
            video: video,
            isCurrentVideo: isCurrentVideo,
            isFirstVideo: index == 0,
            tabId: widget.tabId,
            homeViewModel: ref.read(homeProvider.notifier),
            showSheet: false,
            sheetType: 'none',
            onShowProfile: () {},
            onShowComments: () {},
            onShowShare: () {},
            onShowStreamerCard: () {},
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      color: Colors.black,
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.video_library_outlined,
              color: Colors.white54,
              size: 64,
            ),
            SizedBox(height: 16),
            Text(
              'No videos available',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Check back later for new content',
              style: TextStyle(
                color: Colors.white38,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleSwipe(DragEndDetails details) {
    final velocity = details.velocity.pixelsPerSecond;

    // Up swipe (negative Y velocity) - go to next video
    if (velocity.dy < -300) {
      log('⬆️ VideoPageView: Up swipe detected - next video');
      if (widget.currentIndex < widget.videos.length - 1) {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    }
    // Down swipe (positive Y velocity) - go to previous video
    else if (velocity.dy > 300) {
      log('⬇️ VideoPageView: Down swipe detected - previous video');
      if (widget.currentIndex > 0) {
        _pageController.previousPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    }
  }
}
