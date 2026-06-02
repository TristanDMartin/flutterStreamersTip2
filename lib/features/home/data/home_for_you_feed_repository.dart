import 'package:cloud_firestore/cloud_firestore.dart';

/// Firestore queries for the home For You realtime feed.
class HomeForYouFeedRepository {
  HomeForYouFeedRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static const int canonicalFeedLimit = 50;
  static const int fallbackFeedLimit = 100;

  /// Public videos ordered by publish time (preferred listener).
  Query<Map<String, dynamic>> canonicalPublicFeedQuery({
    int limit = canonicalFeedLimit,
  }) {
    return _firestore
        .collection('videos')
        .where('visibility', isEqualTo: 'public')
        .orderBy('createdAt', descending: true)
        .limit(limit);
  }

  /// Broad legacy listener when canonical query fails or returns no playable items.
  Query<Map<String, dynamic>> fallbackBroadFeedQuery({
    int limit = fallbackFeedLimit,
  }) {
    return _firestore
        .collection('videos')
        .orderBy('createdAt', descending: true)
        .limit(limit);
  }
}
