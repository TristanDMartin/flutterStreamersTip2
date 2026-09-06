import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/home_video.dart';
import '../../models/optimistic_video.dart';
import '../../qa/qa_keys.dart';
import '../../services/optimistic_video_service.dart';
import '../../utils/home_video_playback.dart';
import '../../features/home/domain/home_feed_pending_upload_merge.dart';
import '../video_player_view_optimized.dart';
import '../../providers/home_provider.dart';
import '../../constants/playback_owners.dart';
import '../../services/feed_telemetry_service.dart';
import '../../services/global_playback_manager.dart';
import '../android_media3_home_player.dart';
import '../../features/home/domain/home_feed_processing.dart';
import 'home_feed_processing_cell.dart';
import 'package:streamers_tip/utils/home_feed_interaction_diagnostics.dart';
import 'package:streamers_tip/utils/interaction_diagnostics.dart';
import 'package:streamers_tip/utils/like_interaction_boundary.dart';
import 'package:streamers_tip/utils/secure_log.dart';

int clampHomeVideoIndex(int preferredIndex, int videoCount) {
  if (videoCount <= 0) return 0;
  return preferredIndex.clamp(0, videoCount - 1);
}

class HomeFeedPageControls {
  const HomeFeedPageControls({
    required this.scrollToTop,
    required this.jumpToIndex,
  });

  final VoidCallback scrollToTop;
  final void Function(int index) jumpToIndex;
}

/// Video page view widget for HomeView (handles video scrolling)
class VideoPageViewWidget extends ConsumerStatefulWidget {
  final List<HomeVideo> videos;
  final int currentIndex;
  final String tabId;
  final Function(int) onPageChanged;
  final Function(HomeVideo) onVideoTap;
  final Function(HomeVideo) onLeftSwipe;
  final Function(HomeVideo) onRightSwipe;
  final void Function(HomeFeedPageControls)? onControllerReady;
  final Function()? onRefresh; // Callback for pull-to-refresh
  final Future<void> Function(int index)? onNearEndReached;
  final bool isLoadingMore;
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
    this.onNearEndReached,
    this.isLoadingMore = false,
    this.showCommandCenterTrigger = false,
    this.onCommandCenterTap,
  });

  @override
  ConsumerState<VideoPageViewWidget> createState() =>
      _VideoPageViewWidgetState();
}

class _VideoPageViewWidgetState extends ConsumerState<VideoPageViewWidget> {
  PageController? _pageController;
  bool _isPageUserScrolling = false;
  bool _isHorizontalSwipe = false;
  int _consecutiveUnplayableCount = 0;
  int? _lastPrewarmedIndex;
  int _controllerGeneration = 0;
  String? _lastVisibleVideoId;
  String? _lastNearEndRequestSignature;
  DateTime? _lastNearEndRequestAt;

  // Telemetry tracking.
  final FeedTelemetryService _telemetry = FeedTelemetryService();
  DateTime? _pageEnteredAt;
  HomeVideo? _lastImpressionVideo;

  /// Stale [HomeViewController] index after a shorter feed would leave no page
  /// with [isCurrentVideo] true (audio can still play). Clamp to a valid index.
  int get _clampedCurrentIndex {
    final int len = widget.videos.length;
    if (len == 0) {
      return 0;
    }
    return clampHomeVideoIndex(widget.currentIndex, len);
  }

  int? _findVideoPageIndex(Key key) {
    final String? value = key is ValueKey<String> ? key.value : null;
    if (value == null) {
      return null;
    }
    final String prefix = 'qa_home_feed_video_page_${widget.tabId}_';
    if (!value.startsWith(prefix)) {
      return null;
    }
    final String suffix = value.substring(prefix.length);
    final int separatorIndex = suffix.indexOf('_');
    if (separatorIndex > 0) {
      final int? keyedIndex = int.tryParse(
        suffix.substring(0, separatorIndex),
      );
      final String keyedVideoId = suffix.substring(separatorIndex + 1);
      if (keyedIndex != null &&
          keyedIndex >= 0 &&
          keyedIndex < widget.videos.length &&
          widget.videos[keyedIndex].id == keyedVideoId) {
        return keyedIndex;
      }
      final int shiftedIndex = widget.videos.indexWhere(
        (HomeVideo video) => video.id == keyedVideoId,
      );
      if (shiftedIndex >= 0) {
        return shiftedIndex;
      }
    }
    final String videoId = suffix;
    final int index = widget.videos.indexWhere(
      (HomeVideo video) => video.id == videoId,
    );
    return index < 0 ? null : index;
  }

  void _createPageController(int initialPage) {
    _disposePageController();
    _pageController = PageController(
      initialPage: initialPage,
      keepPage: false,
    );
    _pageController!.addListener(_handlePageScroll);
    _controllerGeneration++;
  }

  int _initialPageIndex() {
    if (widget.videos.isEmpty) {
      return 0;
    }
    return clampHomeVideoIndex(widget.currentIndex, widget.videos.length);
  }

  void _disposePageController() {
    final controller = _pageController;
    if (controller != null) {
      controller.removeListener(_handlePageScroll);
      controller.dispose();
      _pageController = null;
      _controllerGeneration++;
    }
    _lastPrewarmedIndex = null;
  }

  void _rememberVisibleIndex(int index) {
    if (index < 0 || index >= widget.videos.length) {
      _lastVisibleVideoId = null;
      return;
    }
    _lastVisibleVideoId = widget.videos[index].id;
  }

  void _preloadPlaybackWindow(
    int index, {
    required String reason,
    int? direction,
  }) {
    if (index < 0 || index >= widget.videos.length) {
      return;
    }
    final int effectiveDirection = direction ??
        (index > widget.currentIndex
            ? 1
            : index < widget.currentIndex
                ? -1
                : 1);
    try {
      GlobalPlaybackManager.instance.preloadAround(
        index,
        widget.videos,
        direction: effectiveDirection,
        controllerOwner: PlaybackOwners.home,
      );
      final int nextIndex = index + 1;
      if (nextIndex < widget.videos.length) {
        final String nextVideoId = widget.videos[nextIndex].id;
        unawaited(Future<void>.delayed(const Duration(milliseconds: 350), () {
          if (!mounted) {
            return;
          }
          final bool hasNext =
              GlobalPlaybackManager.instance.hasController(nextVideoId);
          if (!hasNext) {
            secureLog(
              'PRELOAD_WINDOW_BROKEN reason=$reason currentIndex=$index '
              'missingNextIndex=$nextIndex videoId=$nextVideoId',
            );
          }
        }));
      }
    } catch (e) {
      secureLog(
        '⚠️ VideoPageView: Error preloading playback window '
        'index=$index reason=$reason: $e',
      );
    }
  }

  void _maybeContinueFeedAtEnd(int index, {required String reason}) {
    if (widget.onNearEndReached == null || widget.videos.isEmpty) {
      return;
    }
    final int triggerIndex =
        (widget.videos.length - 3).clamp(0, widget.videos.length - 1);
    if (index < triggerIndex) {
      return;
    }
    final String signature = '${widget.tabId}:${widget.videos.length}:$index';
    final DateTime now = DateTime.now();
    final DateTime? lastAt = _lastNearEndRequestAt;
    if (_lastNearEndRequestSignature == signature &&
        lastAt != null &&
        now.difference(lastAt) < const Duration(milliseconds: 900)) {
      return;
    }
    _lastNearEndRequestSignature = signature;
    _lastNearEndRequestAt = now;
    secureLog(
      'END_FEED_NEAR_THRESHOLD tab=${widget.tabId} index=$index '
      'count=${widget.videos.length} reason=$reason',
    );
    unawaited(widget.onNearEndReached!(index));
  }

  int _indexForVisibleVideoAfterShrink() {
    final String? visibleVideoId = _lastVisibleVideoId;
    if (visibleVideoId != null && visibleVideoId.isNotEmpty) {
      final int existingIndex = widget.videos.indexWhere(
        (HomeVideo video) => video.id == visibleVideoId,
      );
      if (existingIndex >= 0) {
        return existingIndex;
      }
    }
    return clampHomeVideoIndex(widget.currentIndex, widget.videos.length);
  }

  int _preferredIndexAfterFeedUpdate(VideoPageViewWidget oldWidget) {
    if (_shouldJumpToNewestFirstVideo(oldWidget)) {
      secureLog(
        '🔄 VideoPageView: New video at index 0 — jumping to newest video',
      );
      return 0;
    }
    final String? visibleVideoId = _lastVisibleVideoId;
    if (visibleVideoId != null && visibleVideoId.isNotEmpty) {
      final int existingIndex = widget.videos.indexWhere(
        (HomeVideo video) => video.id == visibleVideoId,
      );
      if (existingIndex >= 0) {
        return existingIndex;
      }
    }
    return clampHomeVideoIndex(widget.currentIndex, widget.videos.length);
  }

  bool _shouldJumpToNewestFirstVideo(VideoPageViewWidget oldWidget) {
    if (widget.videos.isEmpty) {
      return false;
    }
    final HomeVideo newFirst = widget.videos.first;
    if (!isHomeVideoPlayable(newFirst) && !isHomeVideoProcessing(newFirst)) {
      return false;
    }
    if (_lastVisibleVideoId == newFirst.id) {
      return false;
    }
    if (oldWidget.videos.isEmpty) {
      return true;
    }
    final bool wasInOldFeed = oldWidget.videos.any(
      (HomeVideo video) => video.id == newFirst.id,
    );
    if (!wasInOldFeed) {
      return true;
    }
    final HomeVideo oldVersion = oldWidget.videos.firstWhere(
      (HomeVideo video) => video.id == newFirst.id,
    );
    if (isHomeVideoProcessing(oldVersion)) {
      return true;
    }
    if (oldWidget.videos.first.id != newFirst.id) {
      return true;
    }
    return false;
  }

  bool _videoIdentityChanged(VideoPageViewWidget oldWidget) {
    if (oldWidget.videos.length != widget.videos.length) {
      return true;
    }
    for (int index = 0; index < widget.videos.length; index++) {
      if (oldWidget.videos[index].id != widget.videos[index].id) {
        return true;
      }
    }
    return false;
  }

  void _notifyPageChangedAfterFrame(int index, int generation) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || generation != _controllerGeneration) {
        return;
      }
      final int safeIndex = clampHomeVideoIndex(index, widget.videos.length);
      if (widget.videos.isEmpty) {
        return;
      }
      _rememberVisibleIndex(safeIndex);
      try {
        widget.onPageChanged(safeIndex);
      } catch (e) {
        secureLog(
            '⚠️ VideoPageView: Error notifying parent of index $safeIndex: $e');
      }
    });
  }

  void _syncControllerToIndexAfterFrame({
    required int index,
    required int generation,
    required bool notifyParent,
  }) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          generation != _controllerGeneration ||
          _pageController == null ||
          widget.videos.isEmpty) {
        return;
      }
      final int safeIndex = clampHomeVideoIndex(index, widget.videos.length);
      try {
        if (_pageController!.hasClients && _isScrollPositionReady()) {
          _pageController!.jumpToPage(safeIndex);
        }
        _rememberVisibleIndex(safeIndex);
        if (notifyParent) {
          widget.onPageChanged(safeIndex);
        }
      } catch (e) {
        secureLog(
            '⚠️ VideoPageView: Error syncing controller to $safeIndex: $e');
      }
    });
  }

  @override
  void initState() {
    super.initState();
    // Only create PageController if videos exist
    if (widget.videos.isNotEmpty) {
      final int safeIndex = _initialPageIndex();
      _createPageController(safeIndex);
      _rememberVisibleIndex(safeIndex);
    }

    // Expose scroll-to-top functionality to parent
    if (widget.onControllerReady != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        widget.onControllerReady!(
          HomeFeedPageControls(
            scrollToTop: _scrollToTop,
            jumpToIndex: _jumpToIndex,
          ),
        );
      });
    }
    // Log first impression once videos are available.
    if (widget.videos.isNotEmpty) {
      final int safeIndex = _initialPageIndex();
      _pageEnteredAt = DateTime.now();
      _lastImpressionVideo = widget.videos[safeIndex];
      _telemetry.logVideoImpression(
        videoId: widget.videos[safeIndex].id,
        feedPosition: safeIndex,
      );
    }
  }

  /// Scroll to top of the video feed
  void _scrollToTop() {
    _jumpToIndex(0, animate: true);
  }

  void _jumpToIndex(int index, {bool animate = false}) {
    if (_pageController == null ||
        !_pageController!.hasClients ||
        !mounted ||
        widget.videos.isEmpty) {
      return;
    }
    final int safeIndex = clampHomeVideoIndex(index, widget.videos.length);
    try {
      if (!_isScrollPositionReady()) {
        return;
      }
      if (animate && safeIndex == 0) {
        final Stopwatch animateWatch = Stopwatch()..start();
        HomeFeedInteractionDiagnostics.logPageAnimate(
          phase: 'START',
          targetIndex: safeIndex,
          ms: 0,
        );
        unawaited(
          _pageController!
              .animateToPage(
            safeIndex,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          )
              .whenComplete(() {
            HomeFeedInteractionDiagnostics.logPageAnimate(
              phase: 'END',
              targetIndex: safeIndex,
              ms: animateWatch.elapsedMilliseconds,
            );
          }),
        );
      } else {
        _pageController!.jumpToPage(safeIndex);
      }
      _rememberVisibleIndex(safeIndex);
      secureLog('📜 VideoPageView: Jumped to index $safeIndex');
    } catch (e) {
      secureLog('⚠️ VideoPageView: Error jumping to index $safeIndex: $e');
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

    final int candidateIndex = page.round().clamp(0, widget.videos.length - 1);
    final double distance = (page - candidateIndex).abs();
    if (distance > 0.45) return;
    if (_lastPrewarmedIndex == candidateIndex) return;

    _lastPrewarmedIndex = candidateIndex;
    final int direction = candidateIndex > _clampedCurrentIndex ? 1 : -1;
    _preloadPlaybackWindow(
      candidateIndex,
      reason: 'scroll_candidate',
      direction: direction,
    );
    _maybeContinueFeedAtEnd(candidateIndex, reason: 'scroll_candidate');
  }

  @override
  void didUpdateWidget(VideoPageViewWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Handle empty to non-empty transition
    if (oldWidget.videos.isEmpty && widget.videos.isNotEmpty) {
      const int safeIndex = 0;
      _createPageController(safeIndex);
      _rememberVisibleIndex(safeIndex);
      secureLog(
        '🔄 VideoPageView: Videos loaded, created PageController at index 0',
      );

      _notifyPageChangedAfterFrame(safeIndex, _controllerGeneration);
      return;
    } else if (oldWidget.videos.isNotEmpty && widget.videos.isEmpty) {
      _disposePageController();
      _lastVisibleVideoId = null;
      _pageEnteredAt = null;
      _lastImpressionVideo = null;
      secureLog('🔄 VideoPageView: Videos cleared, disposed PageController');
      return;
    }

    if (widget.videos.isEmpty) {
      return;
    }

    if (_pageController == null) {
      final int safeIndex = _initialPageIndex();
      _createPageController(safeIndex);
      _rememberVisibleIndex(safeIndex);
      return;
    }

    final bool identityChanged = _videoIdentityChanged(oldWidget);
    final bool indexChanged = oldWidget.currentIndex != widget.currentIndex;
    final bool tabChanged = oldWidget.tabId != widget.tabId;
    final bool feedShrunk = widget.videos.length < oldWidget.videos.length;
    final bool shouldJumpToNewest =
        !feedShrunk && _shouldJumpToNewestFirstVideo(oldWidget);
    if (!identityChanged &&
        !indexChanged &&
        !tabChanged &&
        !shouldJumpToNewest) {
      HomeFeedInteractionDiagnostics.logPageControllerState(
        hasClients: _pageController?.hasClients ?? false,
        page:
            _pageController?.hasClients == true ? _pageController!.page : null,
      );
      HomeFeedInteractionDiagnostics.logHomeScrollState(
        physicsLabel: 'BouncingScrollPhysics+AlwaysScrollable',
        canScroll: widget.videos.length > 1,
      );
      return;
    }

    final bool forceSyncDuringScroll = shouldForceFeedIndexSyncDuringScroll(
      currentIndex: widget.currentIndex,
      nextVideoCount: widget.videos.length,
    );
    // Avoid jumpToPage mid-swipe unless the visible index is now invalid.
    if (_isPageUserScrolling &&
        !tabChanged &&
        !forceSyncDuringScroll &&
        !feedShrunk) {
      secureLog(
        '⏭️ VideoPageView: Deferring feed sync during user scroll '
        '(index=${widget.currentIndex}, count=${widget.videos.length})',
      );
      return;
    }

    final int targetIndex = identityChanged || tabChanged || shouldJumpToNewest
        ? (feedShrunk
            ? _indexForVisibleVideoAfterShrink()
            : _preferredIndexAfterFeedUpdate(oldWidget))
        : clampHomeVideoIndex(widget.currentIndex, widget.videos.length);
    HomeFeedInteractionDiagnostics.logPageViewItemCount(
      count: widget.videos.length,
      activeIndex: targetIndex,
    );
    secureLog(
      '🔄 VideoPageView: Syncing controller to index $targetIndex '
      '(tabChanged: $tabChanged, identityChanged: $identityChanged)',
    );
    _syncControllerToIndexAfterFrame(
      index: targetIndex,
      generation: _controllerGeneration,
      notifyParent: identityChanged || tabChanged || shouldJumpToNewest,
    );
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
      secureLog('⚠️ VideoPageView: ScrollPosition not ready: $e');
      return false;
    }
  }

  @override
  void dispose() {
    _disposePageController();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.videos.isEmpty) {
      return _buildEmptyState();
    }

    if (_pageController == null) {
      final int safeIndex = _initialPageIndex();
      _createPageController(safeIndex);
      _rememberVisibleIndex(safeIndex);
    }

    Future<void> refreshCallback() async {
      final bool isFeedScrolling = _pageController?.hasClients == true &&
          _pageController!.position.isScrollingNotifier.value;
      if (_isPageUserScrolling ||
          isFeedScrolling ||
          LikeInteractionBoundary.isActive ||
          LikeInteractionBoundary.shouldDeferHeavyWork ||
          _clampedCurrentIndex != 0) {
        InteractionDiagnostics.logRefreshSkipped(
          reason: _isPageUserScrolling || isFeedScrolling
              ? 'scroll'
              : (LikeInteractionBoundary.isActive
                  ? 'interaction'
                  : (_clampedCurrentIndex != 0 ? 'not_at_top' : 'defer')),
        );
        return;
      }
      InteractionDiagnostics.logRefreshExecuted(
        source: 'video_page_view',
        feedIndex: _clampedCurrentIndex,
      );
      if (widget.onRefresh != null) {
        await widget.onRefresh!();
      }
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
          if (AndroidMedia3HomePlayer.isEnabled &&
              widget.videos.isNotEmpty &&
              isHomeVideoPlayable(widget.videos[_clampedCurrentIndex]))
            Positioned.fill(
              child: AndroidMedia3HomePlayer(
                video: widget.videos[_clampedCurrentIndex],
                isActive: true,
                ownerKey: PlaybackOwners.home,
                onPlaySuccess: () {
                  _consecutiveUnplayableCount = 0;
                  _telemetry.logVideoPlayStart(
                    videoId: widget.videos[_clampedCurrentIndex].id,
                    source: 'autoplay',
                  );
                },
              ),
            ),
          RefreshIndicator(
            onRefresh: refreshCallback,
            color: const Color(0xFF9248D2),
            backgroundColor: Colors.white24,
            child: NotificationListener<ScrollNotification>(
              onNotification: (ScrollNotification notification) {
                if (notification is ScrollStartNotification) {
                  if (!_isPageUserScrolling) {
                    _isPageUserScrolling = true;
                    LikeInteractionBoundary.beginPageScroll();
                  }
                } else if (notification is ScrollEndNotification) {
                  if (_isPageUserScrolling) {
                    _isPageUserScrolling = false;
                    LikeInteractionBoundary.endPageScroll();
                  }
                } else if (notification is UserScrollNotification) {
                  if (notification.direction != ScrollDirection.idle) {
                    if (!_isPageUserScrolling) {
                      _isPageUserScrolling = true;
                      LikeInteractionBoundary.beginPageScroll();
                    }
                    InteractionDiagnostics.logPageViewDragAccepted();
                  } else if (_isPageUserScrolling) {
                    _isPageUserScrolling = false;
                    LikeInteractionBoundary.endPageScroll();
                  }
                }
                return false;
              },
              child: PageView.builder(
                key: QaKeys.homeFeedPageView,
                controller: _pageController!,
                scrollDirection: Axis.vertical, // Enable vertical swiping
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ), // Allow overscroll at top for pull-to-refresh
                allowImplicitScrolling: false,
                findChildIndexCallback: _findVideoPageIndex,
                onPageChanged: (index) {
                  try {
                    final Stopwatch pageWatch = Stopwatch()..start();
                    final int safeIndex =
                        clampHomeVideoIndex(index, widget.videos.length);
                    if (safeIndex != index) {
                      secureLog(
                        '⚠️ VideoPageView: Clamped page index $index → '
                        '$safeIndex (videos.length: ${widget.videos.length})',
                      );
                    }
                    secureLog(
                        '🎬 VideoPageView: Page changed to index $safeIndex');
                    _lastPrewarmedIndex = safeIndex;
                    if (widget.videos.isEmpty) {
                      return;
                    }
                    // --- Telemetry: skip detection for the previous video ---
                    final now = DateTime.now();
                    final HomeVideo? previousVideo = _lastImpressionVideo;
                    if (_pageEnteredAt != null && previousVideo != null) {
                      final watched =
                          now.difference(_pageEnteredAt!).inMilliseconds /
                              1000.0;
                      // video_watch_duration for every page-leave
                      final totalSecs = previousVideo.duration ?? 0;
                      final completion = totalSecs > 0
                          ? (watched / totalSecs).clamp(0.0, 1.0)
                          : 0.0;
                      _telemetry.logVideoWatchDuration(
                        videoId: previousVideo.id,
                        watchedSeconds: watched,
                        totalSeconds: totalSecs.toDouble(),
                        completionRate: completion,
                      );
                      // video_skip when < 2s watched
                      if (watched < 2.0) {
                        _telemetry.logVideoSkip(
                          videoId: previousVideo.id,
                          watchedSeconds: watched,
                        );
                      }
                    }
                    // --- Telemetry: impression for the new video ---
                    _pageEnteredAt = now;
                    _lastImpressionVideo = widget.videos[safeIndex];
                    _rememberVisibleIndex(safeIndex);
                    _preloadPlaybackWindow(
                      safeIndex,
                      reason: 'page_changed',
                      direction: safeIndex < widget.currentIndex ? -1 : 1,
                    );
                    _maybeContinueFeedAtEnd(safeIndex, reason: 'page_changed');
                    _telemetry.logVideoImpression(
                      videoId: widget.videos[safeIndex].id,
                      feedPosition: safeIndex,
                    );
                    widget.onPageChanged(safeIndex);
                    HomeFeedInteractionDiagnostics.logPageChanged(
                      source: 'page_view',
                      index: safeIndex,
                      ms: pageWatch.elapsedMilliseconds,
                    );
                  } catch (e) {
                    secureLog('❌ VideoPageView: Error in onPageChanged: $e');
                  }
                },
                itemCount: widget.videos.length,
                itemBuilder: (context, index) {
                  if (index < 0 || index >= widget.videos.length) {
                    secureLog(
                        '⚠️ VideoPageView: Invalid index $index in itemBuilder (videos.length: ${widget.videos.length})');
                    return const SizedBox.shrink();
                  }
                  final video = widget.videos[index];
                  if (video.id.isEmpty) {
                    secureLog(
                        '⚠️ VideoPageView: Invalid video at index $index');
                    return const SizedBox.shrink();
                  }
                  final bool isPlayable = isHomeVideoDisplayPlayable(video);
                  final OptimisticVideo? optimisticForCell =
                      OptimisticVideoService().getOptimisticVideo(video.id);
                  final bool hasOptimisticLocal =
                      optimisticForCell != null &&
                          optimisticLocalFileExists(optimisticForCell);
                  final bool isProcessingCell = isHomeVideoProcessing(video);
                  final isCurrentVideo = index == _clampedCurrentIndex;
                  if (!isPlayable && !hasOptimisticLocal) {
                    if (isProcessingCell) {
                      return KeyedSubtree(
                        key: QaKeys.homeFeedVideoPage(
                          tabId: widget.tabId,
                          videoId: video.id,
                          index: index,
                        ),
                        child: HomeFeedProcessingCell(
                          video: video,
                          optimistic: optimisticForCell,
                        ),
                      );
                    }
                    // Never paint a blank PageView page — advance past junk.
                    if (isCurrentVideo) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (!mounted) {
                          return;
                        }
                        final int next = index + 1;
                        if (next < widget.videos.length) {
                          _pageController?.jumpToPage(next);
                          widget.onPageChanged(next);
                        }
                      });
                    }
                    return KeyedSubtree(
                      key: QaKeys.homeFeedVideoPage(
                        tabId: widget.tabId,
                        videoId: video.id,
                        index: index,
                      ),
                      child: const ColoredBox(color: Colors.black),
                    );
                  }
                  final HomeVideo playbackVideo = isPlayable
                      ? video
                      : homeVideoFromOptimisticVideo(
                          optimistic: optimisticForCell!,
                        );
                  final bool shouldDeferControllerInit = !isCurrentVideo;
                  return KeyedSubtree(
                    key: QaKeys.homeFeedVideoPage(
                      tabId: widget.tabId,
                      videoId: playbackVideo.id,
                      index: index,
                    ),
                    child: VideoPlayerViewOptimized(
                      video: playbackVideo,
                      isCurrentVideo: isCurrentVideo,
                      isFirstVideo: index == 0,
                      deferOffscreenControllerInit: shouldDeferControllerInit,
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
                    ),
                  );
                },
              ),
            ),
          ),
          if (widget.isLoadingMore &&
              _clampedCurrentIndex >= widget.videos.length - 1)
            Positioned(
              left: 0,
              right: 0,
              bottom: MediaQuery.paddingOf(context).bottom + 24,
              child: const Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: Colors.white70,
                  ),
                ),
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
        secureLog('👈 VideoPageView: Left swipe detected');
        if (widget.videos.isNotEmpty) {
          final currentVideo = widget.videos[_clampedCurrentIndex];
          widget.onLeftSwipe(currentVideo);
        }
      } else if (velocity.dx > 300) {
        secureLog('👉 VideoPageView: Right swipe detected');
        if (widget.videos.isNotEmpty) {
          final currentVideo = widget.videos[_clampedCurrentIndex];
          widget.onRightSwipe(currentVideo);
        }
      }
    }
    // ❌ REMOVED: Manual vertical navigation - PageView handles it automatically
  }
}
