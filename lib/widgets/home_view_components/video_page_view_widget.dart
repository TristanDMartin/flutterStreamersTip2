import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:developer';
import '../../models/home_video.dart';
import '../video_player_view_optimized.dart';
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
  final Function(VoidCallback)?
      onControllerReady; // Callback to expose scroll-to-top

  const VideoPageViewWidget({
    super.key,
    required this.videos,
    required this.currentIndex,
    required this.tabId,
    required this.onPageChanged,
    required this.onVideoTap,
    required this.onLeftSwipe,
    required this.onRightSwipe,
    this.onControllerReady,
  });

  @override
  ConsumerState<VideoPageViewWidget> createState() =>
      _VideoPageViewWidgetState();
}

class _VideoPageViewWidgetState extends ConsumerState<VideoPageViewWidget> {
  late PageController _pageController;
  bool _isHorizontalSwipe = false;
  bool _isVerticalSwipe = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: widget.currentIndex);

    // Expose scroll-to-top functionality to parent
    if (widget.onControllerReady != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onControllerReady!(_scrollToTop);
      });
    }
  }

  /// Scroll to top of the video feed
  void _scrollToTop() {
    if (_pageController.hasClients && mounted) {
      _pageController.animateToPage(
        0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
      log('📜 VideoPageView: Scrolled to top');
    }
  }

  @override
  void didUpdateWidget(VideoPageViewWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Handle currentIndex changes from parent
    if (oldWidget.currentIndex != widget.currentIndex &&
        _pageController.hasClients) {
      log('🔄 VideoPageView: currentIndex changed from ${oldWidget.currentIndex} to ${widget.currentIndex}');

      // Jump to new index without animation to keep in sync
      _pageController.jumpToPage(widget.currentIndex);
    }

    // Handle video list changes (e.g., feed switch)
    if (oldWidget.videos.length != widget.videos.length ||
        oldWidget.tabId != widget.tabId) {
      log('🔄 VideoPageView: Videos or tabId changed, resetting to index 0');

      // Reset to first video when feed changes
      if (_pageController.hasClients && widget.videos.isNotEmpty) {
        _pageController.jumpToPage(0);
      }
    }
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
      behavior: HitTestBehavior.translucent, // Allow gestures to pass through
      onPanStart: _handlePanStart,
      onPanUpdate: _handlePanUpdate,
      onPanEnd: _handleSwipe,
      child: PageView.builder(
        controller: _pageController,
        scrollDirection: Axis.vertical, // Enable vertical swiping
        physics: const ClampingScrollPhysics(), // Better physics for mobile
        allowImplicitScrolling: false, // Prevent interference with gestures
        onPageChanged: (index) {
          log('🎬 VideoPageView: Page changed to index $index');
          widget.onPageChanged(index);
        },
        itemCount: widget.videos.length,
        itemBuilder: (context, index) {
          final video = widget.videos[index];
          final isCurrentVideo = index == widget.currentIndex;

          return VideoPlayerViewOptimized(
            key: ValueKey(video.id), // Stable key to prevent audio bleeding
            video: video,
            isCurrentVideo: isCurrentVideo,
            isFirstVideo: index == 0,
            tabId: widget.tabId,
            homeViewModel: ref.read(homeProvider.notifier),
            showSheet: false,
            sheetType: 'none',
            // Callbacks are now optional - will use internal methods
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

  void _handlePanStart(DragStartDetails details) {
    // Reset swipe tracking
    _isHorizontalSwipe = false;
    _isVerticalSwipe = false;
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    final delta = details.delta;
    final absDx = delta.dx.abs();
    final absDy = delta.dy.abs();

    // Track gesture direction early to prevent conflicts
    if (absDx > absDy && absDx > 10) {
      _isHorizontalSwipe = true;
    } else if (absDy > absDx && absDy > 10) {
      _isVerticalSwipe = true;
    }
  }

  void _handleSwipe(DragEndDetails details) {
    final velocity = details.velocity.pixelsPerSecond;
    final absDx = velocity.dx.abs();
    final absDy = velocity.dy.abs();

    // Use tracked gesture direction to avoid conflicts
    // If we already detected horizontal swipe, prioritize it
    if (_isHorizontalSwipe && absDx > 300) {
      // Left swipe (negative X velocity) - show StreamerCardView
      if (velocity.dx < -300) {
        log('👈 VideoPageView: Left swipe detected');
        if (widget.currentIndex < widget.videos.length) {
          final currentVideo = widget.videos[widget.currentIndex];
          widget.onLeftSwipe(currentVideo);
        }
      }
      // Right swipe (positive X velocity) - show StreamerCardView
      else if (velocity.dx > 300) {
        log('👉 VideoPageView: Right swipe detected');
        if (widget.currentIndex < widget.videos.length) {
          final currentVideo = widget.videos[widget.currentIndex];
          widget.onRightSwipe(currentVideo);
        }
      }
    }
    // Vertical swipe - handle video navigation
    // Only if we didn't detect horizontal swipe
    else if ((_isVerticalSwipe || (!_isHorizontalSwipe && absDy > absDx)) &&
        absDy > 300) {
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
}
