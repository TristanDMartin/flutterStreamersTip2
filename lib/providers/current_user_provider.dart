import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart' as fa;
import 'package:cloud_firestore/cloud_firestore.dart';

final currentUserStreamProvider = StreamProvider<Map<String, dynamic>?>((ref) {
  final fa.User? firebaseUser = fa.FirebaseAuth.instance.currentUser;
  if (firebaseUser == null) {
    return const Stream<Map<String, dynamic>?>.empty();
  }
  final String uid = firebaseUser.uid;
  final CollectionReference<Map<String, dynamic>> users =
      FirebaseFirestore.instance.collection('users');
  return users.doc(uid).snapshots().map((doc) {
    final data = doc.data();
    if (data == null) return null;
    return <String, dynamic>{'id': uid, ...data};
  });
});
