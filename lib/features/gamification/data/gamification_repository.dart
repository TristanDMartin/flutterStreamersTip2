import 'package:cloud_firestore/cloud_firestore.dart';

import '../gamification_mapper.dart';
import '../models/user_progress_bundle.dart';

/// Firestore read paths (backend owns writes):
/// - `users/{uid}` fields: `gamification`, `subscription`, `entitlements`, `usage`,
///   optional `dailyMissions` / `missions` arrays.
/// Part B field names: [firestore_user_shape.md](../firestore_user_shape.md).
/// Part D E2E checklist: same file, section “Part D”.
class GamificationRepository {
  GamificationRepository(this._firestore);

  final FirebaseFirestore _firestore;

  Stream<UserProgressBundle> watchProgressBundle(String uid) {
    return _firestore.collection('users').doc(uid).snapshots().map(
      (DocumentSnapshot<Map<String, dynamic>> snap) {
        if (!snap.exists || snap.data() == null) {
          return UserProgressBundle.fallback();
        }
        return GamificationMapper.userDocToBundle(snap.data()!);
      },
    );
  }
}
