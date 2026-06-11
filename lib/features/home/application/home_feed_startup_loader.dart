import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../../../models/home_video.dart';
import '../../../services/video_service.dart' as video_service;
import 'home_feed_warm_cache.dart';

/// Fresh startup feed load result.
class HomeFeedStartupSuccess {
  const HomeFeedStartupSuccess({
    required this.videos,
    this.error,
    this.clearError = false,
    this.cacheUserId,
  });

  final List<HomeVideo> videos;
  final String? error;
  final bool clearError;
  final String? cacheUserId;
}

enum HomeFeedStartupRecoveryKind {
  restoredFromWarmCache,
  keepExistingVisible,
  showEmptyError,
}

/// Recovery path when fresh startup load fails.
class HomeFeedStartupRecovery {
  const HomeFeedStartupRecovery({
    required this.kind,
    this.videos = const <HomeVideo>[],
    this.errorMessage,
  });

  final HomeFeedStartupRecoveryKind kind;
  final List<HomeVideo> videos;
  final String? errorMessage;
}

/// Memory/disk warm start and fresh VideoService startup loads.
class HomeFeedStartupLoader {
  HomeFeedStartupLoader({
    required video_service.VideoService videoService,
    required HomeFeedWarmCache warmCache,
    this.startupTimeout = const Duration(seconds: 6),
    void Function(String message)? log,
  })  : _videoService = videoService,
        _warmCache = warmCache,
        _log = log ?? _noopLog;

  final video_service.VideoService _videoService;
  final HomeFeedWarmCache _warmCache;
  final Duration startupTimeout;
  final void Function(String message) _log;

  List<HomeVideo>? peekMemoryWarmFeed() {
    final cached = _warmCache.peekForYouFromMemory();
    if (cached == null || cached.videos.isEmpty) {
      return null;
    }
    return cached.videos;
  }

  Future<List<HomeVideo>?> restoreDiskWarmFeed(String? userId) async {
    final cached = await _warmCache.loadForYouFeed(userId);
    if (cached == null || cached.videos.isEmpty) {
      return null;
    }
    _log(
      '⚡ HomeProvider: Warm start from cached For You feed '
      '(${cached.videos.length} videos)',
    );
    return cached.videos;
  }

  String? resolveWarmStartUserId() {
    try {
      if (Firebase.apps.isEmpty) {
        return null;
      }
      return FirebaseAuth.instance.currentUser?.uid;
    } catch (_) {
      return null;
    }
  }

  Future<HomeFeedStartupSuccess> loadFreshStartupFeed({
    String? cacheUserId,
  }) async {
    _log('🚀 HomeProvider: Loading fresh startup feed before first playback...');
    await _videoService
        .loadAllVideos(source: 'home_startup')
        .timeout(
      startupTimeout,
      onTimeout: () {
        _log('⏰ HomeProvider: Video load timed out; ending startup wait');
        throw TimeoutException('Fresh startup feed load timed out');
      },
    );
    final List<HomeVideo> realVideos = _videoService.getAllVideos();
    _log('📱 Loaded ${realVideos.length} real videos from VideoService');
    if (realVideos.isEmpty) {
      _log('⚠️ No real videos found, keeping feed honest with an empty state');
      return const HomeFeedStartupSuccess(
        videos: <HomeVideo>[],
        error: 'No videos are available right now.',
      );
    }
    return HomeFeedStartupSuccess(
      videos: realVideos,
      clearError: true,
      cacheUserId: cacheUserId,
    );
  }

  Future<HomeFeedStartupRecovery> recoverStartupFailure({
    required String? userId,
    required List<HomeVideo> existingVideos,
  }) async {
    const String unstableMessage =
        'Connection is unstable. Showing your last loaded feed.';
    final List<HomeVideo>? warmVideos = await restoreDiskWarmFeed(userId);
    if (warmVideos != null) {
      return HomeFeedStartupRecovery(
        kind: HomeFeedStartupRecoveryKind.restoredFromWarmCache,
        videos: warmVideos,
        errorMessage: unstableMessage,
      );
    }
    if (existingVideos.isNotEmpty) {
      return const HomeFeedStartupRecovery(
        kind: HomeFeedStartupRecoveryKind.keepExistingVisible,
        errorMessage: unstableMessage,
      );
    }
    return const HomeFeedStartupRecovery(
      kind: HomeFeedStartupRecoveryKind.showEmptyError,
      errorMessage: 'Unable to load videos right now. Please try again.',
    );
  }

  Future<void> persistWarmFeed({
    required String userId,
    required List<HomeVideo> videos,
    Map<String, dynamic>? nextCursor,
  }) {
    return _warmCache.saveForYouFeed(
      userId: userId,
      videos: videos,
      nextCursor: nextCursor,
    );
  }

  static void _noopLog(String message) {}
}
