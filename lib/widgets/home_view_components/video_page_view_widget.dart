import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:developer';
import '../../models/home_video.dart';
import '../video_player_view_optimized.dart';
import '../../providers/home_provider.dart';
import '../../constants/playback_owners.dart';
import '../../services/feed_telemetry_service.dart';
import '../../services/global_playback_manager.dart';

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
  final bool showCommandCenterTrigger;
  final VoidCallback? onCommandCenterTap;

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
    this.showCommandCenterTrigger = false,
    this.onCommandCenterTap,
  });

  @override
  ConsumerState<VideoPageViewWidget> createState() =>
      _VideoPageViewWidgetState();
}

class _VideoPageViewWidgetState extends ConsumerState<VideoPageViewWidget> {
  PageController? _pageController;
  bool _isHorizontalSwipe = false;
  int _consecutiveUnplayableCount = 0;
  int? _lastPrewarmedIndex;
  double? _lastObservedPage;

  // Telemetry tracking.
  final FeedTelemetryService _telemetry = FeedTelemetryService();
  DateTime? _pageEnteredAt;
  int _lastImpressionIndex = -1;

  @override
  void initState() {
    super.initState();
    // Only create PageController if videos exist
    if (widget.videos.isNotEmpty) {
      _pageController = PageController(
          initialPage: widget.currentIndex.clamp(0, widget.videos.length - 1));
      _pageController!.addListener(_handlePageScroll);
    }

      // Expose scroll-to-top functionality to parent
      if (widget.onControllerReady != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          widget.onControllerReady!(_scrollToTop);
        });
      }
      // Log first impression once videos are available.
      if (widget.videos.isNotEmpty) {
        _pageEnteredAt = DateTime.now();
        _lastImpressionIndex = widget.currentIndex;
        _telemetry.logVideoImpression(
          videoId: widget.videos[widget.currentIndex].id,
          feedPosition: widget.currentIndex,
        );
      }
  }

  /// Scroll to top of the video feed
  void _scrollToTop() {
    if (_pageController != null &&
        _pageController!.hasClients &&
        mounted &&
        widget.videos.isNotEmpty) {
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

  void _handlePageScroll() {
    final controller = _pageController;
    if (!mounted ||
        controller == null ||
        !controller.hasClients ||
        widget.videos.isEmpty) {
      return;
    }

    final page = controller.page;
    if (page == null) return;

    int direction = 0;
    final previousPage = _lastObservedPage;
    if (previousPage != null) {
      if (page > previousPage + 0.02) {
        direction = 1;
      } else if (page < previousPage - 0.02) {
        direction = -1;
      }
    }
    _lastObservedPage = page;

    final int candidateIndex = page.round().clamp(0, widget.videos.length - 1);
    final double distance = (page - candidateIndex).abs();
    if (distance > 0.45) return;
    if (_lastPrewarmedIndex == candidateIndex) return;

    _lastPrewarmedIndex = candidateIndex;
    try {
      GlobalPlaybackManager.instance.preloadAround(
        candidateIndex,
        widget.videos,
        direction: direction,
      );
    } catch (e) {
      log('⚠️ VideoPageView: Error prewarming candidate index $candidateIndex: $e');
    }
  }

  @override
  void didUpdateWidget(VideoPageViewWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Handle empty to non-empty transition
    if (oldWidget.videos.isEmpty && widget.videos.isNotEmpty) {
      // Videos were just loaded - create PageController
      _pageController?.removeListener(_handlePageScroll);
      _pageController?.dispose();
      final safeIndex = widget.currentIndex.clamp(0, widget.videos.length - 1);
      _pageController = PageController(initialPage: safeIndex);
      _pageController!.addListener(_handlePageScroll);
      _lastObservedPage = safeIndex.toDouble();
      log('🔄 VideoPageView: Videos loaded, created PageController');

      // ✅ FIX #1: Make sure parent + manager know which index is actually visible
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        try {
          widget.onPageChanged(safeIndex);
        } catch (e) {
          log('⚠️ VideoPageView: Error notifying parent after videos load: $e');
        }
      });

      return; // Don't try to use controller until next frame
    } else if (oldWidget.videos.isNotEmpty && widget.videos.isEmpty) {
      // Videos were cleared - dispose PageController
      _pageController?.removeListener(_handlePageScroll);
      _pageController?.dispose();
      _pageController = null;
      _lastObservedPage = null;
      log('🔄 VideoPageView: Videos cleared, disposed PageController');
      return;
    }

    // CRITICAL: Defer all controller operations to next frame to ensure ScrollPosition is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _pageController == null || widget.videos.isEmpty) return;

      try {
        // Handle currentIndex changes from parent
        if (oldWidget.currentIndex != widget.currentIndex &&
            _pageController!.hasClients) {
          log('🔄 VideoPageView: currentIndex changed from ${oldWidget.currentIndex} to ${widget.currentIndex}');

          // Verify scroll position is ready before using controller
          if (_isScrollPositionReady()) {
            final safeIndex =
                widget.currentIndex.clamp(0, widget.videos.length - 1);
            _pageController!.jumpToPage(safeIndex);
          }
        }

        // Handle feed switch explicitly. Preserve the current page for same-feed
        // list growth so pagination or refresh doesn't yank the user to index 0.
        if ((oldWidget.videos.length != widget.videos.length ||
                oldWidget.tabId != widget.tabId) &&
            _pageController!.hasClients) {
          final bool tabChanged = oldWidget.tabId != widget.tabId;
          final int safeIndex =
              widget.currentIndex.clamp(0, widget.videos.length - 1);

          log('🔄 VideoPageView: Videos or tabId changed, keeping index $safeIndex (tabChanged: $tabChanged)');

          // Verify scroll position is ready before using controller
          if (_isScrollPositionReady()) {
            _pageController!.jumpToPage(safeIndex);

            // ✅ FIX #1: Keep parent + manager in sync
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              try {
                widget.onPageChanged(safeIndex);
              } catch (e) {
                log('⚠️ VideoPageView: Error notifying parent of index reset: $e');
              }
            });
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
    _pageController?.removeListener(_handlePageScroll);
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
            _pageController = PageController(
                initialPage:
                    widget.currentIndex.clamp(0, widget.videos.length - 1));
            _pageController!.addListener(_handlePageScroll);
            _lastObservedPage = widget.currentIndex.toDouble();
          });
        }
      });
      // Return empty state while controller is being created
      return _buildEmptyState();
    }

    Future<void> refreshCallback() async {
      if (widget.onRefresh != null) await widget.onRefresh!();
    }
    return GestureDetector(
      behavior: HitTestBehavior.translucent, // Allow gestures to pass through
      onHorizontalDragStart: (_) {
        _isHorizontalSwipe = true;
      },
      onHorizontalDragEnd: (details) {
        _handleSwipe(details);
      },
      child: Stack(
        children: [
          RefreshIndicator(
            onRefresh: refreshCallback,
            color: const Color(0xFF9248D2),
            backgroundColor: Colors.white24,
            child: PageView.builder(
              controller: _pageController!,
              scrollDirection: Axis.vertical, // Enable vertical swiping
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ), // Allow overscroll at top for pull-to-refresh
              allowImplicitScrolling: true,
              onPageChanged: (index) {
                try {
                  log('🎬 VideoPageView: Page changed to index $index');
                  _lastPrewarmedIndex = index;
                  if (index >= 0 && index < widget.videos.length) {
                    // --- Telemetry: skip detection for the previous video ---
                    final now = DateTime.now();
                    if (_pageEnteredAt != null && _lastImpressionIndex >= 0 &&
                        _lastImpressionIndex < widget.videos.length) {
                      final watched = now
                          .difference(_pageEnteredAt!)
                          .inMilliseconds / 1000.0;
                      final prevVideo =
                          widget.videos[_lastImpressionIndex];
                      // video_watch_duration for every page-leave
                      final totalSecs = prevVideo.duration ?? 0;
                      final completion = totalSecs > 0
                          ? (watched / totalSecs).clamp(0.0, 1.0)
                          : 0.0;
                      _telemetry.logVideoWatchDuration(
                        videoId: prevVideo.id,
                        watchedSeconds: watched,
                        totalSeconds: totalSecs.toDouble(),
                        completionRate: completion,
                      );
                      // video_skip when < 2s watched
                      if (watched < 2.0) {
                        _telemetry.logVideoSkip(
                          videoId: prevVideo.id,
                          watchedSeconds: watched,
                        );
                      }
                    }
                    // --- Telemetry: impression for the new video ---
                    _pageEnteredAt = now;
                    _lastImpressionIndex = index;
                    _telemetry.logVideoImpression(
                      videoId: widget.videos[index].id,
                      feedPosition: index,
                    );
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
                if (index < 0 || index >= widget.videos.length) {
                  log('⚠️ VideoPageView: Invalid index $index in itemBuilder (videos.length: ${widget.videos.length})');
                  return const SizedBox.shrink();
                }
                final video = widget.videos[index];
                if (video.id.isEmpty || video.videoURL.isEmpty) {
                  log('⚠️ VideoPageView: Invalid video at index $index');
                  return const SizedBox.shrink();
                }
                final isCurrentVideo = index == widget.currentIndex;
                return VideoPlayerViewOptimized(
                  key: ValueKey(video.id),
                  video: video,
                  isCurrentVideo: isCurrentVideo,
                  isFirstVideo: index == 0,
                  tabId: widget.tabId,
                  ownerKey: PlaybackOwners.home,
                  homeViewModel: ref.read(homeProvider.notifier),
                  showSheet: false,
                  sheetType: 'none',
                  showCommandCenterTrigger: widget.showCommandCenterTrigger,
                  onCommandCenterTap: widget.onCommandCenterTap,
                  onVideoUnplayable: () {
                    _consecutiveUnplayableCount++;
                    if (_consecutiveUnplayableCount >= 3 && mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Having trouble loading videos',
                            style: TextStyle(color: Colors.white),
                          ),
                          backgroundColor: Color(0xFF6137EB),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                      _consecutiveUnplayableCount = 0;
                    }
                    if (widget.videos.length > index + 1) {
                      _pageController?.animateToPage(
                        index + 1,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                      widget.onPageChanged(index + 1);
                    }
                  },
                  onVideoPlaySuccess: () {
                    _consecutiveUnplayableCount = 0;
                    _telemetry.logVideoPlayStart(
                      videoId: video.id,
                      source: 'autoplay',
                    );
                  },
                );
              },
            ),
          ),
        ],
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
    final absDx = velocity.dx.abs();

    // ✅ FIX #3: Let PageView own vertical scrolling, keep GestureDetector for horizontal only
    // Horizontal swipe → StreamerCard
    if (_isHorizontalSwipe && absDx > 300) {
      if (velocity.dx < -300) {
        log('👈 VideoPageView: Left swipe detected');
        if (widget.currentIndex < widget.videos.length) {
          final currentVideo = widget.videos[widget.currentIndex];
          widget.onLeftSwipe(currentVideo);
        }
      } else if (velocity.dx > 300) {
        log('👉 VideoPageView: Right swipe detected');
        if (widget.currentIndex < widget.videos.length) {
          final currentVideo = widget.videos[widget.currentIndex];
          widget.onRightSwipe(currentVideo);
        }
      }
    }
    // ❌ REMOVED: Manual vertical navigation - PageView handles it automatically
  }
}
