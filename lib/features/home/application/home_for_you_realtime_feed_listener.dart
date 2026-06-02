import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../models/home_video.dart';
import '../data/home_for_you_feed_repository.dart';

/// Result of processing a debounced For You Firestore snapshot.
class HomeForYouFeedSnapshotResult {
  const HomeForYouFeedSnapshotResult({
    required this.videos,
    required this.usingFallbackListener,
  });

  final List<HomeVideo> videos;
  final bool usingFallbackListener;

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
  final Future<List<HomeVideo>> Function(
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

  bool get isListening => _subscription != null;
  bool get usingFallbackFeedListener => _usingFallbackFeedListener;

  void start() {
    if (_subscription != null) {
      return;
    }
    _subscribeToCanonicalForYouFeed();
  }

  void dispose() {
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
        final List<HomeVideo> liveVideos =
            await buildVideosFromSnapshot(snapshot.docs);
        if (generation != _generation) {
          return;
        }
        final HomeForYouFeedSnapshotResult result =
            HomeForYouFeedSnapshotResult(
          videos: liveVideos,
          usingFallbackListener: _usingFallbackFeedListener,
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
      } catch (e) {
        _log('⚠️ HomeProvider: Live feed snapshot refresh failed: $e');
      }
    });
  }

  static void _noopLog(String message) {}
}
