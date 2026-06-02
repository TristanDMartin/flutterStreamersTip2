import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Shows "Achievement Unlocked: First Steps" at most once per user.
class FirstStepsAchievementService {
  FirstStepsAchievementService._({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  static final FirstStepsAchievementService instance =
      FirstStepsAchievementService._();

  static const String achievementId = 'first_steps';
  static const String toastTitle = 'Achievement Unlocked';
  static const String toastBody = 'First Steps';

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _docRef(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('achievements')
        .doc(achievementId);
  }

  Future<bool> hasSeenToast(String uid) async {
    if (uid.trim().isEmpty) {
      return true;
    }
    final DocumentSnapshot<Map<String, dynamic>> snap =
        await _docRef(uid).get();
    if (!snap.exists) {
      return false;
    }
    return snap.data()?['seen'] == true;
  }

  Future<void> markSeen(String uid) async {
    if (uid.trim().isEmpty) {
      return;
    }
    await _docRef(uid).set(<String, dynamic>{
      'unlocked': true,
      'seen': true,
      'seenAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> maybeShowToast({
    required BuildContext context,
    required String uid,
    required bool isEligible,
  }) async {
    if (!isEligible || uid.trim().isEmpty) {
      return;
    }
    if (await hasSeenToast(uid)) {
      return;
    }
    if (!context.mounted) {
      return;
    }
    await markSeen(uid);
    if (!context.mounted) {
      return;
    }
    final ColorScheme cs = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: cs.inverseSurface,
        content: Row(
          children: <Widget>[
            Icon(Icons.emoji_events_rounded, color: cs.primary, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    toastTitle,
                    style: TextStyle(
                      color: cs.onInverseSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    toastBody,
                    style: TextStyle(color: cs.onInverseSurface),
                  ),
                ],
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }
}
