import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../models/home_video.dart';
import '../../../utils/feed_snapshot_engagement_filter.dart';
import '../../../utils/video_document_rules.dart';
import '../../../utils/video_feed_diagnostics.dart';
import '../../../utils/interaction_diagnostics.dart';
import '../../../utils/like_interaction_boundary.dart';
import '../data/home_for_you_feed_repository.dart';
import '../domain/home_feed_mutator.dart';

/// Result of processing a debounced For You Firestore snapshot.
class HomeForYouFeedSnapshotResult {
  const HomeForYouFeedSnapshotResult({
    required this.videos,
    required this.usingFallbackListener,
    this.removedVideoIds = const <String>{},
  });

  final List<HomeVideo> videos;
  final bool usingFallbackListener;

  /// Docs in this snapshot that must leave Home (deleted / not feed-visible).
  final Set<String> removedVideoIds;

  bool get shouldSwitchToFallback =>
      videos.isEmpty && !usingFallbackListener;
}

/// Canonical + fallback Firestore listeners for the home For You feed.
class HomeForYouRealtimeFeedListener {
  HomeForYouRealtimeFeedListener({
    HomeForYouFeedRepository? repository,
    required this.buildVideosFromSnapshot,
    required this.onSnapshotReady,
    this.debounceDuration = const Duration(milliseconds: 350),
    void Function(String message)? log,
  })  : _repository = repository ?? HomeForYouFeedRepository(),
        _log = log ?? _noopLog;

  final HomeForYouFeedRepository _repository;
  final Future<HomeRealtimeFeedBuildResult> Function(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) buildVideosFromSnapshot;
  final Future<void> Function(HomeForYouFeedSnapshotResult result)
      onSnapshotReady;
  final Duration debounceDuration;
  final void Function(String message) _log;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subscription;
  Timer? _debounce;
  int _generation = 0;
  bool _usingFallbackFeedListener = false;
  Map<String, Map<String, dynamic>> _lastFeedDocDataById =
      <String, Map<String, dynamic>>{};

  bool get isListening => _subscription != null;
  bool get usingFallbackFeedListener => _usingFallbackFeedListener;

  void start() {
    if (_subscription != null) {
      return;
    }
    _subscribeToCanonicalForYouFeed();
  }

  void dispose() {
    VideoFeedDiagnostics.logHomeForYouListenerDisposed(
      reason: 'listener_dispose',
    );
    _debounce?.cancel();
    _debounce = null;
    _generation++;
    _subscription?.cancel();
    _subscription = null;
  }

  void _subscribeToCanonicalForYouFeed() {
    _subscription?.cancel();
    _usingFallbackFeedListener = false;

    final Query<Map<String, dynamic>> query =
        _repository.canonicalPublicFeedQuery();

    VideoFeedDiagnostics.logHomeForYouListenerRegistered(
      queryLabel: 'canonical_for_you',
    );
    _subscription = query.snapshots().listen(
      _handleForYouFeedSnapshot,
      onError: (Object error, StackTrace stackTrace) {
        _log('⚠️ HomeProvider: canonical feed snapshot failed: $error');
        if (!_usingFallbackFeedListener) {
          _subscribeToFallbackForYouFeed();
        }
      },
    );
  }

  void _subscribeToFallbackForYouFeed() {
    _usingFallbackFeedListener = true;
    _subscription?.cancel();

    final Query<Map<String, dynamic>> query =
        _repository.fallbackBroadFeedQuery();

    VideoFeedDiagnostics.logHomeForYouListenerRegistered(
      queryLabel: 'fallback_for_you',
    );
    _subscription = query.snapshots().listen(
      _handleForYouFeedSnapshot,
      onError: (Object error, StackTrace stackTrace) {
        _log('⚠️ HomeProvider: fallback feed snapshot failed: $error');
      },
    );
  }

  void switchToFallbackFeed() {
    if (!_usingFallbackFeedListener) {
      _subscribeToFallbackForYouFeed();
    }
  }

  void _handleForYouFeedSnapshot(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    _debounce?.cancel();
    _debounce = Timer(debounceDuration, () async {
      final int generation = ++_generation;
      try {
        if (FeedSnapshotEngagementFilter.shouldSkipRebuild(
          snapshot: snapshot,
          previousDocDataById: _lastFeedDocDataById,
        )) {
          _lastFeedDocDataById =
              FeedSnapshotEngagementFilter.snapshotDocDataById(snapshot);
          if (LikeInteractionBoundary.shouldDeferHeavyWork) {
            LikeInteractionBoundary.reportFeedRefresh(
              source: 'engagement_only_snapshot',
            );
          }
          return;
        }
        if (LikeInteractionBoundary.shouldDeferHeavyWork) {
          LikeInteractionBoundary.reportFeedRefresh(
            source: 'live_feed_snapshot',
          );
        }
        final int docCount = snapshot.docs.length;
        final Set<String> removedVideoIds =
            collectInvisiblePublicFeedDocIds(snapshot.docs);
        final HomeRealtimeFeedBuildResult built =
            await buildVideosFromSnapshot(snapshot.docs);
        if (generation != _generation) {
          return;
        }
        InteractionDiagnostics.logRealtimeFeedBuild(
          docCount: docCount,
          builtCount: built.videos.length,
        );
        if (docCount > 3 && built.videos.length < docCount ~/ 2) {
          _log(
            '⚠️ HomeProvider: Realtime snapshot built ${built.videos.length}/'
            '$docCount playable videos — merge will preserve existing feed',
          );
        }
        final HomeForYouFeedSnapshotResult result =
            HomeForYouFeedSnapshotResult(
          videos: built.videos,
          usingFallbackListener: _usingFallbackFeedListener,
          removedVideoIds: <String>{
            ...removedVideoIds,
            ...built.removedVideoIds,
          },
        );
        if (result.shouldSwitchToFallback) {
          _log(
            '⚠️ HomeProvider: canonical feed produced 0 playable videos; '
            'switching to broad legacy fallback',
          );
          _subscribeToFallbackForYouFeed();
          return;
        }
        await onSnapshotReady(result);
        _lastFeedDocDataById =
            FeedSnapshotEngagementFilter.snapshotDocDataById(snapshot);
      } catch (e) {
        _log('⚠️ HomeProvider: Live feed snapshot refresh failed: $e');
      }
    });
  }

  static void _noopLog(String message) {}
}
