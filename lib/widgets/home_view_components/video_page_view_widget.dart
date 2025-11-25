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
  final Function()? onRefresh; // Callback for pull-to-refresh

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
    this.onRefresh,
  });

  @override
  ConsumerState<VideoPageViewWidget> createState() =>
      _VideoPageViewWidgetState();
}

class _VideoPageViewWidgetState extends ConsumerState<VideoPageViewWidget> {
  PageController? _pageController;
  bool _isHorizontalSwipe = false;
  bool _isVerticalSwipe = false;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    // Only create PageController if videos exist
    if (widget.videos.isNotEmpty) {
      _pageController = PageController(initialPage: widget.currentIndex.clamp(0, widget.videos.length - 1));
    }

    // Expose scroll-to-top functionality to parent
    if (widget.onControllerReady != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onControllerReady!(_scrollToTop);
      });
    }
  }

  /// Scroll to top of the video feed
  void _scrollToTop() {
    if (_pageController != null && _pageController!.hasClients && mounted && widget.videos.isNotEmpty) {
      try {
        if (_isScrollPositionReady()) {
          _pageController!.animateToPage(
            0,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
          log('📜 VideoPageView: Scrolled to top');
        }
      } catch (e) {
        log('⚠️ VideoPageView: Error scrolling to top: $e');
      }
    }
  }

  @override
  void didUpdateWidget(VideoPageViewWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Handle empty to non-empty transition
    if (oldWidget.videos.isEmpty && widget.videos.isNotEmpty) {
      // Videos were just loaded - create PageController
      _pageController?.dispose();
      _pageController = PageController(initialPage: widget.currentIndex.clamp(0, widget.videos.length - 1));
      log('🔄 VideoPageView: Videos loaded, created PageController');
      return; // Don't try to use controller until next frame
    } else if (oldWidget.videos.isNotEmpty && widget.videos.isEmpty) {
      // Videos were cleared - dispose PageController
      _pageController?.dispose();
      _pageController = null;
      log('🔄 VideoPageView: Videos cleared, disposed PageController');
      return;
    }

    // CRITICAL: Defer all controller operations to next frame to ensure ScrollPosition is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _pageController == null || widget.videos.isEmpty) return;

      try {
        // Handle currentIndex changes from parent
        if (oldWidget.currentIndex != widget.currentIndex && _pageController!.hasClients) {
          log('🔄 VideoPageView: currentIndex changed from ${oldWidget.currentIndex} to ${widget.currentIndex}');

          // Verify scroll position is ready before using controller
          if (_isScrollPositionReady()) {
            final safeIndex = widget.currentIndex.clamp(0, widget.videos.length - 1);
            _pageController!.jumpToPage(safeIndex);
          }
        }

        // Handle video list changes (e.g., feed switch)
        if ((oldWidget.videos.length != widget.videos.length ||
            oldWidget.tabId != widget.tabId) &&
            _pageController!.hasClients) {
          log('🔄 VideoPageView: Videos or tabId changed, resetting to index 0');

          // Verify scroll position is ready before using controller
          if (_isScrollPositionReady()) {
            _pageController!.jumpToPage(0);
          }
        }
      } catch (e) {
        log('⚠️ VideoPageView: Error in didUpdateWidget: $e');
      }
    });
  }

  /// Check if ScrollPosition is ready (not null and initialized)
  bool _isScrollPositionReady() {
    if (_pageController == null || !_pageController!.hasClients) return false;
    try {
      // Try to access maxScrollExtent - if it throws, position isn't ready
      final position = _pageController!.position;
      // Access maxScrollExtent in a safe way - if it's null, position isn't ready
      final _ = position.maxScrollExtent;
      return true;
    } catch (e) {
      log('⚠️ VideoPageView: ScrollPosition not ready: $e');
      return false;
    }
  }

  @override
  void dispose() {
    _pageController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.videos.isEmpty) {
      return _buildEmptyState();
    }

    // Ensure PageController exists when videos are available
    if (_pageController == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.videos.isNotEmpty) {
          setState(() {
            _pageController = PageController(initialPage: widget.currentIndex.clamp(0, widget.videos.length - 1));
          });
        }
      });
      // Return empty state while controller is being created
      return _buildEmptyState();
    }

    // 🎬 PULL-TO-REFRESH: Only enable when at index 0 (top of feed)
    final canRefresh = widget.currentIndex == 0 && widget.onRefresh != null;

    return GestureDetector(
      behavior: HitTestBehavior.translucent, // Allow gestures to pass through
      onPanStart: (details) {
        _handlePanStart(details);
        // Track if we're at index 0 for pull-to-refresh
        if (canRefresh && widget.currentIndex == 0) {
          _pullStartY = details.globalPosition.dy;
        }
      },
      onPanUpdate: (details) {
        _handlePanUpdate(details);
        // Detect pull-to-refresh gesture when at index 0
        if (canRefresh && widget.currentIndex == 0 && _pullStartY != null) {
          final deltaY = details.globalPosition.dy - _pullStartY!;
          // If pulling down more than 100px, trigger refresh
          if (deltaY > 100 && !_isRefreshing) {
            _handlePullToRefresh();
            _pullStartY = null; // Reset to prevent multiple triggers
          }
        }
      },
      onPanEnd: (details) {
        _handleSwipe(details);
        _pullStartY = null; // Reset on gesture end
      },
      child: Stack(
        children: [
          PageView.builder(
            controller: _pageController!,
            scrollDirection: Axis.vertical, // Enable vertical swiping
            physics: const ClampingScrollPhysics(), // Better physics for mobile
            allowImplicitScrolling: false, // Prevent interference with gestures
            onPageChanged: (index) {
              try {
                log('🎬 VideoPageView: Page changed to index $index');
                // 🔒 SAFETY: Validate index before calling callback
                if (index >= 0 && index < widget.videos.length) {
                  widget.onPageChanged(index);
                } else {
                  log('⚠️ VideoPageView: Invalid index $index (videos.length: ${widget.videos.length})');
                }
              } catch (e) {
                log('❌ VideoPageView: Error in onPageChanged: $e');
              }
            },
            itemCount: widget.videos.length,
            itemBuilder: (context, index) {
              // 🔒 SAFETY: Validate index before accessing videos
              if (index < 0 || index >= widget.videos.length) {
                log('⚠️ VideoPageView: Invalid index $index in itemBuilder (videos.length: ${widget.videos.length})');
                return const SizedBox.shrink(); // Return empty widget instead of crashing
              }
              
              final video = widget.videos[index];
              
              // 🔒 SAFETY: Validate video object
              if (video.id.isEmpty || video.videoURL.isEmpty) {
                log('⚠️ VideoPageView: Invalid video at index $index');
                return const SizedBox.shrink();
              }
              
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
          // Show refresh indicator when refreshing
          if (_isRefreshing && canRefresh)
            Positioned(
              top: 50,
              left: 0,
              right: 0,
              child: Center(
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
                  child: const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      strokeWidth: 2,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  double? _pullStartY; // Track pull gesture start position

  /// Handle pull-to-refresh gesture
  Future<void> _handlePullToRefresh() async {
    if (_isRefreshing || widget.onRefresh == null) return;

    log('🔄 VideoPageView: Pull-to-refresh triggered at index 0');
    
    if (mounted) {
      setState(() {
        _isRefreshing = true;
      });
    }

    try {
      // Call parent's refresh handler
      await widget.onRefresh!();
      log('✅ VideoPageView: Pull-to-refresh completed - newest videos at top');
    } catch (e) {
      log('❌ VideoPageView: Error during pull-to-refresh: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
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
        if (_pageController != null && 
            _pageController!.hasClients &&
            widget.currentIndex < widget.videos.length - 1) {
          try {
            if (_isScrollPositionReady()) {
              _pageController!.nextPage(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            }
          } catch (e) {
            log('⚠️ VideoPageView: Error in nextPage: $e');
          }
        }
      }
      // Down swipe (positive Y velocity) - go to previous video
      else if (velocity.dy > 300) {
        log('⬇️ VideoPageView: Down swipe detected - previous video');
        if (_pageController != null && 
            _pageController!.hasClients &&
            widget.currentIndex > 0) {
          try {
            if (_isScrollPositionReady()) {
              _pageController!.previousPage(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            }
          } catch (e) {
            log('⚠️ VideoPageView: Error in previousPage: $e');
          }
        }
      }
    }
  }
}
