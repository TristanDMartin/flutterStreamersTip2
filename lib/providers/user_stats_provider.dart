import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_stats.dart';

final StreamProviderFamily<UserStats, String> watchUserStatsProvider =
    StreamProvider.family<UserStats, String>((ref, userId) {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  return firestore.collection('users').doc(userId).snapshots().map((snapshot) {
    final Map<String, Object?> data =
        snapshot.data() ?? const <String, Object?>{};
    return UserStats.fromUserDocData(data);
  });
});
