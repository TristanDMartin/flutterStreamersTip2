import 'dart:developer';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/home_provider.dart';
import 'global_playback_coordinator.dart';

/// Unified Video Control Service - Single source of truth for all video control operations
///
/// Consolidates video pause/resume logic from:
/// - HomeView._pauseAllHomeViewVideos()
/// - MainTabView._resumeHomeViewVideos()
/// - VideoPlayerViewOptimized.GlobalVideoController
/// - GlobalPlaybackCoordinator
class UnifiedVideoControlService {
  static final UnifiedVideoControlService _instance =
      UnifiedVideoControlService._internal();
  factory UnifiedVideoControlService() => _instance;
  UnifiedVideoControlService._internal();

  final GlobalPlaybackCoordinator _coordinator = GlobalPlaybackCoordinator();

  /// Pause all videos with comprehensive error handling
  Future<void> pauseAllVideos({
    String? reason,
    bool useCoordinator = true,
    WidgetRef? ref,
  }) async {
    try {
      log('🎵 UnifiedVideoControl: Pausing all videos - reason: ${reason ?? "unknown"}');

      if (useCoordinator) {
        // Use the global coordinator for proper focus management
        await _coordinator.pauseAll(reason: reason);
      } else {
        // Fallback to direct provider control
        if (ref != null) {
          final homeNotifier = ref.read(homeProvider.notifier);
          homeNotifier.pauseAllVideos();
        }
      }

      log('✅ UnifiedVideoControl: All videos paused successfully');
    } catch (e) {
      log('❌ UnifiedVideoControl: Error pausing videos: $e');
      rethrow;
    }
  }

  /// Resume playback (unblock all video playback)
  void resumePlayback() {
    try {
      log('🎵 UnifiedVideoControl: Resuming playback');
      _coordinator.resumePlayback();
      log('✅ UnifiedVideoControl: Playback resumed successfully');
    } catch (e) {
      log('❌ UnifiedVideoControl: Error resuming playback: $e');
    }
  }

  /// Resume current video with focus management
  Future<void> resumeCurrentVideo({
    String? videoId,
    String? tabId,
    bool useCoordinator = true,
    WidgetRef? ref,
  }) async {
    try {
      log('🎵 UnifiedVideoControl: Resuming current video - videoId: $videoId, tabId: $tabId');

      if (useCoordinator && videoId != null && tabId != null) {
        // Use coordinator for proper focus management
        await _coordinator.requestFocus(videoId, tabId);
      } else {
        // Fallback to direct provider control
        if (ref != null) {
          final homeNotifier = ref.read(homeProvider.notifier);
          homeNotifier.resumeCurrentVideo();
        }
      }

      log('✅ UnifiedVideoControl: Current video resumed successfully');
    } catch (e) {
      log('❌ UnifiedVideoControl: Error resuming video: $e');
      rethrow;
    }
  }

  /// Pause videos from inactive tab only
  Future<void> pauseInactiveTabVideos({
    required String activeTabId,
    String? reason,
  }) async {
    try {
      log('🎵 UnifiedVideoControl: Pausing inactive tab videos - activeTab: $activeTabId');

      // Use coordinator to pause all except the active tab
      await _coordinator.pauseAllExcept(activeTabId);

      log('✅ UnifiedVideoControl: Inactive tab videos paused successfully');
    } catch (e) {
      log('❌ UnifiedVideoControl: Error pausing inactive tab videos: $e');
      rethrow;
    }
  }

  /// Pause all other videos except current (for scrolling within same tab)
  Future<void> pauseAllOtherVideos({
    required String currentVideoId,
    required String tabId,
  }) async {
    try {
      log('🎵 UnifiedVideoControl: Pausing all other videos - current: $currentVideoId, tab: $tabId');

      // Use coordinator to pause all except current video
      await _coordinator.pauseAllExcept(tabId);

      log('✅ UnifiedVideoControl: All other videos paused successfully');
    } catch (e) {
      log('❌ UnifiedVideoControl: Error pausing other videos: $e');
      rethrow;
    }
  }

  /// Handle app lifecycle state changes
  Future<void> handleAppLifecycleChange({
    required String state,
    String? currentVideoId,
    String? currentTabId,
    WidgetRef? ref,
  }) async {
    try {
      log('🎵 UnifiedVideoControl: Handling app lifecycle - state: $state');

      switch (state.toLowerCase()) {
        case 'paused':
        case 'inactive':
          await pauseAllVideos(reason: 'appLifecycle_$state', ref: ref);
          break;
        case 'resumed':
          if (currentVideoId != null && currentTabId != null) {
            await resumeCurrentVideo(
              videoId: currentVideoId,
              tabId: currentTabId,
              ref: ref,
            );
          }
          break;
        case 'detached':
          await pauseAllVideos(reason: 'appLifecycle_detached', ref: ref);
          break;
      }

      log('✅ UnifiedVideoControl: App lifecycle handled successfully');
    } catch (e) {
      log('❌ UnifiedVideoControl: Error handling app lifecycle: $e');
      rethrow;
    }
  }

  /// Handle modal presentation (pause all videos)
  Future<void> handleModalPresentation({
    required bool isPresented,
    String? modalType,
  }) async {
    try {
      if (isPresented) {
        log('🎵 UnifiedVideoControl: Modal presented - type: $modalType');
        await _coordinator.pauseAll(reason: 'modalPresented_$modalType');
      } else {
        log('🎵 UnifiedVideoControl: Modal dismissed - type: $modalType');
        _coordinator.resumePlayback();
      }
    } catch (e) {
      log('❌ UnifiedVideoControl: Error handling modal presentation: $e');
      rethrow;
    }
  }

  /// Handle navigation changes (pause all videos)
  Future<void> handleNavigationChange({
    required bool isLeavingHomeView,
    String? destination,
  }) async {
    try {
      if (isLeavingHomeView) {
        log('🎵 UnifiedVideoControl: Leaving HomeView - destination: $destination');
        await _coordinator.pauseAll(reason: 'navigation_$destination');
      } else {
        log('🎵 UnifiedVideoControl: Returning to HomeView');
        _coordinator.resumePlayback();
      }
    } catch (e) {
      log('❌ UnifiedVideoControl: Error handling navigation change: $e');
      rethrow;
    }
  }

  /// Get current coordinator state for debugging
  Map<String, dynamic> getDebugInfo() {
    return _coordinator.getDebugInfo();
  }

  /// Log current state for debugging
  void logCurrentState() {
    _coordinator.logCurrentState();
  }
}

/// Riverpod provider for the unified video control service
final unifiedVideoControlProvider = Provider<UnifiedVideoControlService>((ref) {
  return UnifiedVideoControlService();
});
