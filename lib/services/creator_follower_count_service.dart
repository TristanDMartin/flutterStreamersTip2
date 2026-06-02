import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/user_count_fields.dart';

/// Canonical follower totals from `users/{creatorId}/followers` edges.
class CreatorFollowerCountService {
  CreatorFollowerCountService._();
  static final CreatorFollowerCountService instance =
      CreatorFollowerCountService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Count of documents in [users/{creatorId}/followers].
  Future<int> getCreatorFollowerCount(String creatorId) async {
    final String trimmed = creatorId.trim();
    if (trimmed.isEmpty) {
      return 0;
    }
    final AggregateQuerySnapshot snapshot = await _db
        .collection('users')
        .doc(trimmed)
        .collection('followers')
        .count()
        .get();
    final int? raw = snapshot.count;
    return math.max(0, raw ?? 0);
  }

  /// Prefer subcollection aggregate; on failure use denormalized user doc.
  Future<int> resolveCreatorFollowerCount(
    String creatorId,
    Map<String, dynamic>? userDocData,
  ) async {
    try {
      return await getCreatorFollowerCount(creatorId);
    } catch (_) {
      if (userDocData != null) {
        return math.max(0, UserCountFields.readFollowersCount(userDocData));
      }
      return 0;
    }
  }
}
