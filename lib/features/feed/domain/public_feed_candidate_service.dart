import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../features/home/data/home_for_you_feed_repository.dart';

/// Shared Firestore reads for Home For You and Discover "All" feeds.
class PublicFeedCandidateService {
  PublicFeedCandidateService({HomeForYouFeedRepository? repository})
      : _repository = repository ?? HomeForYouFeedRepository();

  final HomeForYouFeedRepository _repository;

  static const int defaultDiscoverLimit = 50;

  /// Same query path as Home realtime feed (public + recency).
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
      fetchPublicVideoCandidates({
    int limit = defaultDiscoverLimit,
  }) async {
    try {
      final QuerySnapshot<Map<String, dynamic>> canonical =
          await _repository
              .canonicalPublicFeedQuery(limit: limit)
              .get();
      if (canonical.docs.isNotEmpty) {
        return canonical.docs;
      }
    } catch (_) {
      // Fall through to broad query (matches Home fallback).
    }
    final QuerySnapshot<Map<String, dynamic>> fallback =
        await _repository.fallbackBroadFeedQuery(limit: limit).get();
    return fallback.docs;
  }
}
