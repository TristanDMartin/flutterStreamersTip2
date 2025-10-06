import 'package:video_player/video_player.dart';
import 'video_controller_registry.dart';
import 'production_logging_service.dart';

/// Service for preloading video controllers to eliminate purple screen flash
/// Implements TikTok-style instant video switching
class VideoPreloaderService {
  static final VideoPreloaderService _instance =
      VideoPreloaderService._internal();
  factory VideoPreloaderService() => _instance;
  VideoPreloaderService._internal();

  final VideoControllerRegistry _controllerRegistry = VideoControllerRegistry();
  final ProductionLoggingService _logger = ProductionLoggingService();

  // Preload window: current + 1 neighbor on each side
  static const int _preloadWindow = 1;

  // Track preloaded controllers by video ID
  final Map<String, VideoPlayerController> _preloadedControllers = {};
  final Map<String, bool> _preloadedStates = {};

  // Current video list and index
  List<dynamic> _videos = [];
  int _currentIndex = 0;

  /// Initialize preloader with video list and current index
  Future<void> initialize(List<dynamic> videos, int currentIndex) async {
    _videos = videos;
    _currentIndex = currentIndex;

    _logger.debug(
        'VideoPreloader: Initializing with ${videos.length} videos, current: $currentIndex',
        tag: 'VideoPreloader');

    // Preload current and neighbor videos
    await _preloadCurrentWindow();
  }

  /// Update current index and preload new window
  Future<void> updateCurrentIndex(int newIndex) async {
    if (newIndex == _currentIndex) return;

    _logger.debug(
        'VideoPreloader: Updating current index from $_currentIndex to $newIndex',
        tag: 'VideoPreloader');

    _currentIndex = newIndex;
    await _preloadCurrentWindow();
  }

  /// Get preloaded controller for video at index
  VideoPlayerController? getPreloadedController(int index) {
    if (index < 0 || index >= _videos.length) return null;

    final video = _videos[index];
    final videoId = video.id;

    return _preloadedControllers[videoId];
  }

  /// Get preloaded controller for video by ID
  VideoPlayerController? getPreloadedControllerById(String videoId) {
    return _preloadedControllers[videoId];
  }

  /// Check if video at index is preloaded and ready
  bool isPreloaded(int index) {
    if (index < 0 || index >= _videos.length) return false;

    final video = _videos[index];
    final videoId = video.id;

    return _preloadedStates[videoId] == true;
  }

  /// Preload controllers for current window (current ± preloadWindow)
  Future<void> _preloadCurrentWindow() async {
    if (_videos.isEmpty) return; // Guard against empty video list

    final startIndex =
        (_currentIndex - _preloadWindow).clamp(0, _videos.length - 1);
    final endIndex =
        (_currentIndex + _preloadWindow).clamp(0, _videos.length - 1);

    _logger.debug('VideoPreloader: Preloading window $startIndex to $endIndex',
        tag: 'VideoPreloader');

    // Preload videos in the window
    for (int i = startIndex; i <= endIndex; i++) {
      await _preloadVideo(i);
    }

    // Dispose controllers outside the window
    await _disposeOutsideWindow(startIndex, endIndex);
  }

  /// Preload a single video
  Future<void> _preloadVideo(int index) async {
    if (index < 0 || index >= _videos.length) return;

    final video = _videos[index];
    final videoId = video.id;

    // Skip if already preloaded
    if (_preloadedStates[videoId] == true) return;

    try {
      _logger.debug('VideoPreloader: Preloading video $videoId at index $index',
          tag: 'VideoPreloader');

      // Get controller from manager (this will create if needed)
      final controller = _controllerRegistry.getController(videoId);

      if (controller != null) {
        _preloadedControllers[videoId] = controller;
        _preloadedStates[videoId] = true;

        _logger.debug('VideoPreloader: Successfully preloaded video $videoId',
            tag: 'VideoPreloader');
      } else {
        _logger.warn(
            'VideoPreloader: Failed to get controller for video $videoId',
            tag: 'VideoPreloader');
      }
    } catch (e) {
      _logger.error('VideoPreloader: Error preloading video $videoId',
          tag: 'VideoPreloader', error: e);
    }
  }

  /// Dispose controllers outside the preload window
  Future<void> _disposeOutsideWindow(int startIndex, int endIndex) async {
    final videosToDispose = <String>[];

    for (final videoId in _preloadedControllers.keys) {
      // Find the index of this video
      int videoIndex = -1;
      for (int i = 0; i < _videos.length; i++) {
        if (_videos[i].id == videoId) {
          videoIndex = i;
          break;
        }
      }

      // If video is outside the window, mark for disposal
      if (videoIndex == -1 ||
          videoIndex < startIndex ||
          videoIndex > endIndex) {
        videosToDispose.add(videoId);
      }
    }

    // Dispose controllers outside window
    for (final videoId in videosToDispose) {
      try {
        _controllerRegistry.dispose(videoId);
        _preloadedControllers.remove(videoId);
        _preloadedStates.remove(videoId);

        _logger.debug(
            'VideoPreloader: Disposed controller for video $videoId (outside window)',
            tag: 'VideoPreloader');
      } catch (e) {
        _logger.error(
            'VideoPreloader: Error disposing controller for video $videoId',
            tag: 'VideoPreloader',
            error: e);
      }
    }
  }

  /// Get preload status for debugging
  Map<String, dynamic> getPreloadStatus() {
    return {
      'currentIndex': _currentIndex,
      'preloadedCount': _preloadedControllers.length,
      'preloadedVideos': _preloadedControllers.keys.toList(),
    };
  }

  /// Dispose all preloaded controllers
  Future<void> dispose() async {
    _logger.debug('VideoPreloader: Disposing all preloaded controllers',
        tag: 'VideoPreloader');

    for (final videoId in _preloadedControllers.keys) {
      try {
        _controllerRegistry.dispose(videoId);
      } catch (e) {
        _logger.error(
            'VideoPreloader: Error disposing controller for video $videoId',
            tag: 'VideoPreloader',
            error: e);
      }
    }

    _preloadedControllers.clear();
    _preloadedStates.clear();
  }
}
