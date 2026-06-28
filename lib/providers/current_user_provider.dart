import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart' as fa;
import 'package:cloud_firestore/cloud_firestore.dart';

import '../utils/user_doc_relevant_stream.dart';

/// Auth uid only — does not invalidate when `users/{uid}` metadata churns.
final signedInUserIdProvider = Provider<String?>((Ref ref) {
  final AsyncValue<String?> authUid = ref.watch(authUserIdStreamProvider);
  return authUid.valueOrNull;
});

final authUserIdStreamProvider = StreamProvider<String?>((Ref ref) {
  return fa.FirebaseAuth.instance
      .authStateChanges()
      .map((fa.User? user) => user?.uid);
});

final currentUserStreamProvider = StreamProvider<Map<String, dynamic>?>((ref) {
  final fa.User? firebaseUser = fa.FirebaseAuth.instance.currentUser;
  if (firebaseUser == null) {
    return const Stream<Map<String, dynamic>?>.empty();
  }
  final String uid = firebaseUser.uid;
  final CollectionReference<Map<String, dynamic>> users =
      FirebaseFirestore.instance.collection('users');
  return userDocSnapshotsRelevantOnly(
    users.doc(uid).snapshots(),
    uid: uid,
  );
});
