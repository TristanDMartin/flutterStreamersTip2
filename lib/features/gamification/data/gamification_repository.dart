import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../gamification_mapper.dart';
import '../models/user_progress_bundle.dart';

/// Firestore read paths (backend owns writes):
/// - Primary: `users/{uid}/gamification/state`
/// - Legacy: `users/{uid}` fields `gamification`, `progressionSummary`, missions
/// See [firestore_user_shape.md](../firestore_user_shape.md) and `docs/GAMIFICATION_ALIGNMENT.md`.
class GamificationRepository {
  GamificationRepository(this._firestore);

  final FirebaseFirestore _firestore;

  Stream<UserProgressBundle> watchProgressBundle(String uid) {
    final DocumentReference<Map<String, dynamic>> userRef =
        _firestore.collection('users').doc(uid);
    final DocumentReference<Map<String, dynamic>> stateRef =
        userRef.collection('gamification').doc('state');
    DocumentSnapshot<Map<String, dynamic>>? latestUser;
    DocumentSnapshot<Map<String, dynamic>>? latestState;
    StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? userSub;
    StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? stateSub;
    final StreamController<UserProgressBundle> controller =
        StreamController<UserProgressBundle>.broadcast();
    void emitBundle() {
      if (latestUser == null) {
        return;
      }
      if (!latestUser!.exists || latestUser!.data() == null) {
        controller.add(UserProgressBundle.fallback());
        return;
      }
      final Map<String, dynamic>? stateData =
          latestState != null && latestState!.exists
              ? latestState!.data()
              : null;
      controller.add(
        GamificationMapper.userDocToBundle(
          latestUser!.data()!,
          uid: uid,
          gamificationState: stateData,
        ),
      );
    }

    controller.onListen = () {
      userSub = userRef.snapshots().listen(
        (DocumentSnapshot<Map<String, dynamic>> snap) {
          latestUser = snap;
          emitBundle();
        },
        onError: controller.addError,
      );
      stateSub = stateRef.snapshots().listen(
        (DocumentSnapshot<Map<String, dynamic>> snap) {
          latestState = snap;
          emitBundle();
        },
        onError: controller.addError,
      );
    };
    controller.onCancel = () async {
      await userSub?.cancel();
      await stateSub?.cancel();
    };
    return controller.stream;
  }
}
