import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streamers_tip/services/follows_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

Future<void> _seedUser(
  FakeFirebaseFirestore firestore,
  String id,
) async {
  await firestore.collection('users').doc(id).set({
    'id': id,
    'username': id,
    'displayName': id,
    'onlineStatus': 'offline',
    'platforms': [],
    'socialLinks': [],
    'hashtags': [],
    'calendarEvents': [],
  });
}

void main() {
  late FakeFirebaseFirestore firestore;
  late FirebaseAuth auth;
  late FollowsService service;

  setUp(() async {
    firestore = FakeFirebaseFirestore();
    auth = _FakeAuth('userA');
    FollowsService.debugSetOverrides(
      firestore: firestore,
      auth: auth,
    );
    service = FollowsService();

    await _seedUser(firestore, 'userA');
    await _seedUser(firestore, 'userB'); // mutual (primary)
    await _seedUser(firestore, 'userC'); // follower
    await _seedUser(firestore, 'userD'); // following
    await _seedUser(firestore, 'userE'); // mutual legacy
  });

  tearDown(() {
    FollowsService.debugSetOverrides(firestore: null, auth: null);
  });

  test('connections tab includes mutual follows (primary + legacy)', () async {
    // Primary mutual: userA <-> userB
    await firestore.collection('follows').add({
      'followerUserId': 'userA',
      'targetUserId': 'userB',
      'isActive': true,
    });
    await firestore.collection('follows').add({
      'followerUserId': 'userB',
      'targetUserId': 'userA',
      'isActive': true,
    });

    // Legacy mutual: userA <-> userE via followerId/followingId
    await firestore.collection('follows').add({
      'followerId': 'userA',
      'followingId': 'userE',
      'isActive': true,
    });
    await firestore.collection('follows').add({
      'followerId': 'userE',
      'followingId': 'userA',
      'isActive': true,
    });

    // Inactive doc should be ignored
    await firestore.collection('follows').add({
      'followerUserId': 'userA',
      'targetUserId': 'userB',
      'isActive': false,
    });

    final users = await service.getUsersForTab('connections');
    expect(users.map((u) => u.id).toSet(), {'userB', 'userE'});
  });

  test('followers tab includes only users that follow current user', () async {
    // userC follows userA
    await firestore.collection('follows').add({
      'followerUserId': 'userC',
      'targetUserId': 'userA',
      'isActive': true,
    });
    // inactive
    await firestore.collection('follows').add({
      'followerUserId': 'userC',
      'targetUserId': 'userA',
      'isActive': false,
    });

    final users = await service.getUsersForTab('followers');
    expect(users.length, 1);
    expect(users.first.id, 'userC');
  });

  test('following tab includes only users current user follows', () async {
    // userA follows userD (legacy field)
    await firestore.collection('follows').add({
      'followerId': 'userA',
      'followingId': 'userD',
      'isActive': true,
    });
    // inactive
    await firestore.collection('follows').add({
      'followerId': 'userA',
      'followingId': 'userD',
      'isActive': false,
    });

    final users = await service.getUsersForTab('following');
    expect(users.length, 1);
    expect(users.first.id, 'userD');
  });
}

class _FakeUser extends Fake implements User {
  _FakeUser(this._uid);
  final String _uid;
  @override
  String get uid => _uid;
}

class _FakeAuth extends Fake implements FirebaseAuth {
  _FakeAuth(String uid) : _user = _FakeUser(uid);
  final User _user;
  @override
  User? get currentUser => _user;
}
