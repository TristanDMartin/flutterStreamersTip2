import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeFirebaseUser extends Fake implements User {
  FakeFirebaseUser(this.uid);
  @override
  final String uid;
}

class FakeFirebaseAuth extends Fake implements FirebaseAuth {
  FakeFirebaseAuth(this._user);
  final User _user;
  @override
  User? get currentUser => _user;
}

Future<void> seedUser(FakeFirebaseFirestore firestore, String id) async {
  await firestore.collection('users').doc(id).set({
    'id': id,
    'username': id,
    'displayName': id,
    'onlineStatus': 'offline',
    'platforms': <String>[],
    'socialLinks': <String>[],
    'hashtags': <String>[],
    'calendarEvents': <String>[],
  });
}
