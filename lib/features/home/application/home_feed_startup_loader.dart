import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../../../models/home_video.dart';
import '../../../services/optimistic_video_service.dart';
import '../../../services/video_service.dart' as video_service;
import '../domain/home_feed_pending_upload_merge.dart';
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
    this.authWaitTimeout = const Duration(seconds: 12),
    this.startupTimeout = const Duration(seconds: 20),
    Future<String?> Function()? waitForSignedInUserId,
    void Function(String message)? log,
  })  : _videoService = videoService,
        _warmCache = warmCache,
        _waitForSignedInUserId = waitForSignedInUserId,
        _log = log ?? _noopLog;

  final video_service.VideoService _videoService;
  final HomeFeedWarmCache _warmCache;
  final Duration authWaitTimeout;
  final Duration startupTimeout;
  final Future<String?> Function()? _waitForSignedInUserId;
  final void Function(String message) _log;

  List<HomeVideo>? peekMemoryWarmFeed() {
    final cached = _warmCache.peekForYouFromMemory();
    if (cached == null || cached.videos.isEmpty) {
      return null;
    }
    final List<HomeVideo> playable = HomeFeedWarmCache.remotePlayableOnly(
      cached.videos,
    );
    if (playable.isEmpty) {
      return null;
    }
    return playable;
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
    final String? signedInUserId = await _resolveSignedInUserId();
    if (signedInUserId == null || signedInUserId.isEmpty) {
      _log('⏳ HomeProvider: Auth not ready for startup feed load');
      throw TimeoutException('Auth not ready for startup feed load');
    }
    try {
      await _videoService
          .loadAllVideos(source: 'home_startup')
          .timeout(
        startupTimeout,
        onTimeout: () {
          _log('⏰ HomeProvider: Video load timed out; ending startup wait');
          throw TimeoutException('Fresh startup feed load timed out');
        },
      );
    } on TimeoutException {
      final List<HomeVideo> partialVideos = _videoService.getAllVideos();
      if (partialVideos.isNotEmpty) {
        _log(
          '⚡ HomeProvider: Using ${partialVideos.length} videos after '
          'startup timeout',
        );
        return HomeFeedStartupSuccess(
          videos: partialVideos,
          clearError: true,
          cacheUserId: cacheUserId ?? signedInUserId,
        );
      }
      rethrow;
    }
    final List<HomeVideo> realVideos = _videoService.getAllVideos();
    _log('📱 Loaded ${realVideos.length} real videos from VideoService');
    // Cold start: Instant Publish memory is gone — pull the signed-in owner's
    // uploading/processing/ready docs into VideoService so Profile/Streamer
    // (and owner Home merge) see the same videoId immediately.
    try {
      final bool ownerMerged = await _videoService.mergeProfileVideosForUser(
        signedInUserId,
        forceServer: true,
        viewName: 'HomeStartupOwnerMerge',
      );
      _log(
        '📱 Owner profile merge on startup changed=$ownerMerged '
        'state=${_videoService.getAllVideos().length}',
      );
    } catch (e) {
      _log('⚠️ Owner profile merge on startup failed: $e');
    }
    final List<HomeVideo> afterOwnerMerge = _videoService.getAllVideos();
    final User? authUser = FirebaseAuth.instance.currentUser;
    if (authUser != null) {
      await OptimisticVideoService().restorePersistedOptimisticVideos();
      upsertOwnerPendingOptimisticVideos(
        ownerId: authUser.uid,
        optimisticVideoService: OptimisticVideoService(),
        existingVideos: _videoService.getAllVideos(),
        currentUserDisplayName: authUser.displayName,
        currentUserPhotoUrl: authUser.photoURL,
        upsert: _videoService.addVideo,
      );
    }
    final List<HomeVideo> withOwnerPending = _videoService.getAllVideos();
    if (withOwnerPending.isEmpty && afterOwnerMerge.isEmpty) {
      _log('⚠️ No real videos found, keeping feed honest with an empty state');
      return const HomeFeedStartupSuccess(
        videos: <HomeVideo>[],
        error: 'No videos are available right now.',
      );
    }
    return HomeFeedStartupSuccess(
      videos: withOwnerPending.isNotEmpty ? withOwnerPending : afterOwnerMerge,
      clearError: true,
      cacheUserId: cacheUserId ?? signedInUserId,
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

  Future<String?> _resolveSignedInUserId() async {
    if (_waitForSignedInUserId != null) {
      return _waitForSignedInUserId!();
    }
    final User? user = await waitForFirebaseSignedInUser(
      timeout: authWaitTimeout,
    );
    return user?.uid;
  }

  static Future<User?> waitForFirebaseSignedInUser({
    Duration timeout = const Duration(seconds: 12),
  }) async {
    try {
      if (Firebase.apps.isEmpty) {
        return null;
      }
      final User? current = FirebaseAuth.instance.currentUser;
      if (current != null) {
        return current;
      }
      return await FirebaseAuth.instance
          .authStateChanges()
          .where((User? user) => user != null)
          .map((User? user) => user!)
          .first
          .timeout(timeout);
    } on TimeoutException {
      return FirebaseAuth.instance.currentUser;
    } catch (_) {
      return null;
    }
  }

  static void _noopLog(String message) {}
}
