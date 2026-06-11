import 'package:cloud_firestore/cloud_firestore.dart';

/// Detects Firestore feed snapshots that only touch engagement counters.
abstract final class FeedSnapshotEngagementFilter {
  static const Set<String> _engagementOnlyKeys = <String>{
    'likes',
    'likeCount',
    'likesCount',
    'updatedAt',
    'lastLikedAt',
    'views',
    'viewCount',
    'comments',
    'commentCount',
    'shares',
    'shareCount',
  };

  static bool shouldSkipRebuild({
    required QuerySnapshot<Map<String, dynamic>> snapshot,
    required Map<String, Map<String, dynamic>> previousDocDataById,
  }) {
    if (snapshot.docChanges.isEmpty) {
      return false;
    }
    for (final DocumentChange<Map<String, dynamic>> change
        in snapshot.docChanges) {
      if (change.type != DocumentChangeType.modified) {
        return false;
      }
      final Map<String, dynamic>? previous =
          previousDocDataById[change.doc.id];
      final Map<String, dynamic>? next = change.doc.data();
      if (previous == null || next == null) {
        return false;
      }
      if (!_onlyEngagementFieldsChanged(previous, next)) {
        return false;
      }
    }
    return true;
  }

  static Map<String, Map<String, dynamic>> snapshotDocDataById(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    final Map<String, Map<String, dynamic>> byId =
        <String, Map<String, dynamic>>{};
    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
        in snapshot.docs) {
      byId[doc.id] = Map<String, dynamic>.from(doc.data());
    }
    return byId;
  }

  static bool _onlyEngagementFieldsChanged(
    Map<String, dynamic> before,
    Map<String, dynamic> after,
  ) {
    final Set<String> keys = <String>{...before.keys, ...after.keys};
    for (final String key in keys) {
      if (_engagementOnlyKeys.contains(key)) {
        continue;
      }
      if (before[key] != after[key]) {
        return false;
      }
    }
    return true;
  }
}
