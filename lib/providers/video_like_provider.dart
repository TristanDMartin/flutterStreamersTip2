import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/streamers_tip_like_service.dart';
import '../utils/home_feed_interaction_diagnostics.dart';
import '../utils/interaction_diagnostics.dart';
import '../utils/like_interaction_boundary.dart';

/// Per-video like UI state (isolated from home feed / PageView).
class VideoLikeState {
  const VideoLikeState({
    required this.isLiked,
    required this.likeCount,
  });

  final bool isLiked;
  final int likeCount;

  VideoLikeState copyWith({
    bool? isLiked,
    int? likeCount,
  }) {
    return VideoLikeState(
      isLiked: isLiked ?? this.isLiked,
      likeCount: likeCount ?? this.likeCount,
    );
  }
}

/// Optimistic like toggles + background Firestore sync for one video.
class VideoLikeNotifier extends StateNotifier<VideoLikeState> {
  VideoLikeNotifier({
    required String videoId,
    required StreamersTipLikeService likeService,
    bool? initialIsLiked,
    int? initialLikeCount,
  })  : _likeService = likeService,
        _videoId = videoId,
        super(
          _initialState(
            videoId: videoId,
            likeService: likeService,
            initialIsLiked: initialIsLiked,
            initialLikeCount: initialLikeCount,
          ),
        ) {
    unawaited(_hydrateFromLocalCache());
  }

  final String _videoId;
  final StreamersTipLikeService _likeService;

  static VideoLikeState _initialState({
    required String videoId,
    required StreamersTipLikeService likeService,
    bool? initialIsLiked,
    int? initialLikeCount,
  }) {
    final LikeState cached = likeService.getLikeState(videoId);
    final bool isLiked = initialIsLiked ?? cached.isLiked;
    final int likeCount = _coerceCount(
      serviceCount: cached.likeCount,
      fallback: initialLikeCount ?? 0,
    );
    return VideoLikeState(isLiked: isLiked, likeCount: likeCount);
  }

  static int _coerceCount({
    required int serviceCount,
    required int fallback,
  }) {
    if (serviceCount > 0) {
      return serviceCount;
    }
    if (fallback > 0) {
      return fallback;
    }
    return 0;
  }

  Future<void> _hydrateFromLocalCache() async {
    final LikeState? cached = await _likeService.loadCachedStateForVideo(
      _videoId,
    );
    if (cached == null) {
      return;
    }
    final int nextCount = _coerceCount(
      serviceCount: cached.likeCount,
      fallback: state.likeCount,
    );
    if (state.isLiked == cached.isLiked && state.likeCount == nextCount) {
      return;
    }
    state = VideoLikeState(
      isLiked: cached.isLiked,
      likeCount: nextCount,
    );
  }

  void seedFromDisplay({
    required bool isLiked,
    required int likeCount,
  }) {
    final int safeCount = likeCount < 0 ? 0 : likeCount;
    if (state.isLiked && !isLiked) {
      state = state.copyWith(
        likeCount: state.likeCount > 0 ? state.likeCount : safeCount,
      );
      return;
    }
    state = VideoLikeState(isLiked: isLiked, likeCount: safeCount);
  }

  void restoreState(VideoLikeState previous) {
    state = previous;
  }

  void applyLikeCountFromFirestore(int nextLikeCount) {
    final int safeCount = nextLikeCount < 0 ? 0 : nextLikeCount;
    if (state.likeCount == safeCount) {
      return;
    }
    state = state.copyWith(likeCount: safeCount);
  }

  /// Instant heart + count; Firestore runs in the background.
  void toggleOptimistic({
    String source = 'button_tap',
    VoidCallback? onBackgroundSyncComplete,
  }) {
    final bool lightweight = source == 'double_tap';
    LikeInteractionBoundary.beginLikeTap();
    HomeFeedInteractionDiagnostics.logLikeTap(_videoId);
    final bool wasLiked = state.isLiked;
    final int nextCount = wasLiked
        ? (state.likeCount > 0 ? state.likeCount - 1 : 0)
        : state.likeCount + 1;
    state = VideoLikeState(
      isLiked: !wasLiked,
      likeCount: nextCount,
    );
    _likeService.primeLikeStateForBackgroundSync(
      videoId: _videoId,
      isLiked: !wasLiked,
      likeCount: nextCount,
    );
    InteractionDiagnostics.logLikeOptimisticDone(videoId: _videoId);
    LikeInteractionBoundary.endLikeTap(lightweight: lightweight);
    InteractionDiagnostics.logLikeFirestoreQueued(videoId: _videoId);
    unawaited(Future<void>.delayed(const Duration(milliseconds: 300), () {
      return _syncLikeInBackground(
        source: source,
        targetLiked: !wasLiked,
        onComplete: onBackgroundSyncComplete,
      );
    }));
  }

  Future<void> _syncLikeInBackground({
    required String source,
    required bool targetLiked,
    VoidCallback? onComplete,
  }) async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (kDebugMode) {
        debugPrint('❌ VideoLikeNotifier: no user for $_videoId');
      }
      onComplete?.call();
      return;
    }
    try {
      if (source == 'double_tap') {
        InteractionDiagnostics.logDoubleTapBackgroundSyncStart(
          videoId: _videoId,
        );
      }
      if (targetLiked) {
        await _likeService.likeVideo(
          _videoId,
          user.uid,
          source: source,
          backgroundSync: true,
        );
      } else {
        await _likeService.unlikeVideo(
          _videoId,
          user.uid,
          backgroundSync: true,
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          '⚠️ VideoLikeNotifier: background sync failed for $_videoId: $e',
        );
      }
    } finally {
      if (source == 'double_tap') {
        InteractionDiagnostics.logDoubleTapBackgroundSyncDone(
          videoId: _videoId,
        );
      }
      onComplete?.call();
    }
  }
}

final StateNotifierProviderFamily<VideoLikeNotifier, VideoLikeState, String>
    videoLikeProvider =
    StateNotifierProvider.family<VideoLikeNotifier, VideoLikeState, String>(
  (Ref ref, String videoId) {
    final StreamersTipLikeService likeService =
        StreamersTipLikeService.instance;
    final LikeState cached = likeService.getLikeState(videoId);
    return VideoLikeNotifier(
      videoId: videoId,
      likeService: likeService,
      initialIsLiked: cached.isLiked,
      initialLikeCount: cached.likeCount,
    );
  },
);
