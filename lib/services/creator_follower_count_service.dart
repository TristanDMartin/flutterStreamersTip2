import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/user_count_fields.dart';
import 'public_profile_firestore.dart';

/// Prefer denormalized counters on publicUsers / own users doc.
/// Edge aggregates are a fallback only when the profile doc is missing counts.
class CreatorFollowerCountService {
  CreatorFollowerCountService._();
  static final CreatorFollowerCountService instance =
      CreatorFollowerCountService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Reads [UserCountFields] from public profile; falls back to edge count.
  Future<int> getCreatorFollowerCount(String creatorId) async {
    final String trimmed = creatorId.trim();
    if (trimmed.isEmpty) {
      return 0;
    }
    try {
      final Map<String, dynamic>? data =
          await PublicProfileFirestore.instance.getProfileMap(trimmed);
      if (data != null) {
        return math.max(0, UserCountFields.readFollowersCount(data));
      }
    } catch (_) {
      // Fall through to edge aggregate.
    }
    return _countFollowerEdges(trimmed);
  }

  /// Prefer user-doc counts from [userDocData]; else fetch / edge-count.
  Future<int> resolveCreatorFollowerCount(
    String creatorId,
    Map<String, dynamic>? userDocData,
  ) async {
    if (userDocData != null) {
      return math.max(0, UserCountFields.readFollowersCount(userDocData));
    }
    try {
      return await getCreatorFollowerCount(creatorId);
    } catch (_) {
      return 0;
    }
  }

  Future<int> _countFollowerEdges(String creatorId) async {
    try {
      final AggregateQuerySnapshot snapshot = await _db
          .collection('users')
          .doc(creatorId)
          .collection('followers')
          .count()
          .get();
      return math.max(0, snapshot.count ?? 0);
    } catch (_) {
      return 0;
    }
  }
}
