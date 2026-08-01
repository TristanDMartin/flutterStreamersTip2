import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_stats.dart';
import '../services/public_profile_firestore.dart';

/// Live profile header counters (Posts / Followers / Following).
///
/// Own uid → `users/{uid}` (private SoT).
/// Peers → `publicUsers/{uid}` (users is owner-only).
final StreamProviderFamily<UserStats, String> watchUserStatsProvider =
    StreamProvider.family<UserStats, String>((ref, userId) {
  return PublicProfileFirestore.instance.watchProfile(userId).map(
    (DocumentSnapshot<Map<String, dynamic>> snapshot) {
      final Map<String, Object?> data =
          snapshot.data() ?? const <String, Object?>{};
      return UserStats.fromUserDocData(data);
    },
  ).distinct((UserStats previous, UserStats next) {
    return previous.postsCount == next.postsCount &&
        previous.followersCount == next.followersCount &&
        previous.followingCount == next.followingCount &&
        previous.connectionsCount == next.connectionsCount;
  });
});
