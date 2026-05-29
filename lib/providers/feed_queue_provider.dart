import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/home_video.dart';
import '../services/feed_bootstrap_service.dart';
import '../services/video_prefetch_service.dart';
import 'package:streamers_tip/utils/secure_log.dart';

/// Provider for the feed queue state
final feedQueueProvider = StateNotifierProvider<FeedQueue, FeedState>((ref) {
  return FeedQueue(ref);
});

/// Feed queue state notifier
class FeedQueue extends StateNotifier<FeedState> {
  FeedQueue(this.ref) : super(FeedState.initial());
  
  final Ref ref;
  
  final FeedBootstrapService _bootstrapService = FeedBootstrapService();
  final VideoPrefetchService _prefetchService = VideoPrefetchService();

  /// Bootstrap the feed for instant play
  Future<void> bootstrap() async {
    if (state.isBootstrapping) return;
    
    state = state.copyWith(isBootstrapping: true);
    
    try {
      secureLog('🚀 Starting feed bootstrap...');
      final startTime = DateTime.now();
      
      // Bootstrap the feed
      final result = await _bootstrapService.bootstrap();
      
      // Update state with bootstrap result
      state = state.copyWith(
        items: result.items,
        cursor: result.cursor,
        etag: result.etag,
        isWarmStart: result.isWarmStart,
        bootstrapTimeMs: result.bootstrapTimeMs,
        isBootstrapping: false,
        hasError: false,
      );
      
      // Start prefetching window around first video
      if (result.items.isNotEmpty) {
        await _prefetchWindow(0);
      }
      
      final totalTime = DateTime.now().difference(startTime).inMilliseconds;
      secureLog('✅ Feed bootstrap completed in ${totalTime}ms (warm start: ${result.isWarmStart})');
      
    } catch (e) {
      secureLog('❌ Feed bootstrap failed: $e');
      state = state.copyWith(
        isBootstrapping: false,
        hasError: true,
        errorMessage: e.toString(),
      );
    }
  }

  /// Handle index change (scrolling)
  void onIndexChanged(int newIndex) {
    if (newIndex == state.currentIndex) return;
    
    final oldIndex = state.currentIndex;
    state = state.copyWith(currentIndex: newIndex);
    
    secureLog('📱 Index changed: $oldIndex -> $newIndex');
    
    // Prefetch window around new index
    _prefetchWindow(newIndex);
    
    // Playback ownership lives in the active player path; queue prefetch only
    // warms network media.
  }

  /// Prefetch window around current index
  Future<void> _prefetchWindow(int centerIndex) async {
    try {
      if (state.items.isEmpty) return;
      
      // Convert items to prefetch items
      final prefetchItems = state.items.map((video) => PrefetchItem(
        videoId: video.id,
        posterUrl: video.thumbnailURL ?? '',
        videoUrl: video.videoURL,
        prefetchPriority: _calculatePrefetchPriority(video, centerIndex),
      )).toList();
      
      // Prefetch window
      await _prefetchService.prefetchWindow(
        currentIndex: centerIndex,
        items: prefetchItems,
      );
      
    } catch (e) {
      secureLog('❌ Error prefetching window: $e');
    }
  }

  /// Calculate prefetch priority for a video
  double _calculatePrefetchPriority(HomeVideo video, int centerIndex) {
    final videoIndex = state.items.indexWhere((v) => v.id == video.id);
    if (videoIndex == -1) return 0.0;
    
    final distance = (videoIndex - centerIndex).abs();
    
    // Higher priority for closer videos
    if (distance == 0) return 1.0;      // Current video
    if (distance == 1) return 0.8;      // Adjacent videos
    if (distance == 2) return 0.6;      // Next videos
    if (distance == 3) return 0.4;      // Further videos
    
    return 0.2; // Low priority for distant videos
  }

  /// Load more videos
  Future<void> loadMore() async {
    if (state.isLoadingMore || state.cursor == null) return;
    
    state = state.copyWith(isLoadingMore: true);
    
    try {
      // Load more logic - fetch next batch of videos using cursor
      // This would typically call a service to get more videos
      
      secureLog('📥 Loading more videos...');
      await Future.delayed(const Duration(milliseconds: 500)); // Simulate network
      
      state = state.copyWith(isLoadingMore: false);
      
    } catch (e) {
      secureLog('❌ Error loading more videos: $e');
      state = state.copyWith(isLoadingMore: false);
    }
  }

  /// Refresh the feed
  Future<void> refresh() async {
    if (state.isRefreshing) return;
    
    state = state.copyWith(isRefreshing: true);
    
    try {
      secureLog('🔄 Refreshing feed...');
      
      // Clear current state
      state = state.copyWith(
        items: [],
        cursor: null,
        etag: null,
        currentIndex: 0,
      );
      
      // Bootstrap again
      await bootstrap();
      
      state = state.copyWith(isRefreshing: false);
      
    } catch (e) {
      secureLog('❌ Error refreshing feed: $e');
      state = state.copyWith(isRefreshing: false);
    }
  }

  /// Get current video
  HomeVideo? get currentVideo {
    if (state.currentIndex >= 0 && state.currentIndex < state.items.length) {
      return state.items[state.currentIndex];
    }
    return null;
  }

  /// Get next video
  HomeVideo? get nextVideo {
    final nextIndex = state.currentIndex + 1;
    if (nextIndex < state.items.length) {
      return state.items[nextIndex];
    }
    return null;
  }

  /// Get previous video
  HomeVideo? get previousVideo {
    final prevIndex = state.currentIndex - 1;
    if (prevIndex >= 0) {
      return state.items[prevIndex];
    }
    return null;
  }

  /// Dispose resources
  @override
  void dispose() {
    super.dispose();
  }
}

/// Feed state
class FeedState {
  final List<HomeVideo> items;
  final int currentIndex;
  final String? cursor;
  final String? etag;
  final bool isWarmStart;
  final int bootstrapTimeMs;
  final bool isBootstrapping;
  final bool isLoadingMore;
  final bool isRefreshing;
  final bool hasError;
  final String? errorMessage;

  const FeedState({
    this.items = const [],
    this.currentIndex = 0,
    this.cursor,
    this.etag,
    this.isWarmStart = false,
    this.bootstrapTimeMs = 0,
    this.isBootstrapping = false,
    this.isLoadingMore = false,
    this.isRefreshing = false,
    this.hasError = false,
    this.errorMessage,
  });

  factory FeedState.initial() => const FeedState();

  FeedState copyWith({
    List<HomeVideo>? items,
    int? currentIndex,
    String? cursor,
    String? etag,
    bool? isWarmStart,
    int? bootstrapTimeMs,
    bool? isBootstrapping,
    bool? isLoadingMore,
    bool? isRefreshing,
    bool? hasError,
    String? errorMessage,
  }) {
    return FeedState(
      items: items ?? this.items,
      currentIndex: currentIndex ?? this.currentIndex,
      cursor: cursor ?? this.cursor,
      etag: etag ?? this.etag,
      isWarmStart: isWarmStart ?? this.isWarmStart,
      bootstrapTimeMs: bootstrapTimeMs ?? this.bootstrapTimeMs,
      isBootstrapping: isBootstrapping ?? this.isBootstrapping,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      hasError: hasError ?? this.hasError,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  /// Check if there are more items to load
  bool get hasMoreItems => cursor != null;

  /// Check if feed is ready
  bool get isReady => !isBootstrapping && !hasError && items.isNotEmpty;

  /// Check if current video is valid
  bool get hasCurrentVideo => currentIndex >= 0 && currentIndex < items.length;
}
