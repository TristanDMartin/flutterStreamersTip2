import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streamers_tip/services/follow_button_service.dart';
import 'package:streamers_tip/services/follows_service.dart';

import '../../test_support/fake_firebase_auth.dart';

void main() {
  group('FollowButtonService', () {
    late FakeFirebaseFirestore firestore;
    late FollowButtonService service;

    setUp(() async {
      firestore = FakeFirebaseFirestore();
      FollowsService.debugSetOverrides(
        firestore: firestore,
        auth: FakeFirebaseAuth(FakeFirebaseUser('viewer')),
      );
      service = FollowButtonService.instance;
      await seedUser(firestore, 'viewer');
      await seedUser(firestore, 'creator');
      await seedUser(firestore, 'other');
    });

    tearDown(() {
      FollowsService.debugSetOverrides(firestore: null, auth: null);
    });

    test('returns self when viewer is creator', () async {
      final FollowButtonState state = await service.getButtonState(
        viewerId: 'viewer',
        creatorId: 'viewer',
      );
      expect(state, FollowButtonState.self);
      expect(state.buttonText, 'You');
      expect(state.isTappable, isFalse);
    });

    test('returns connected for mutual follow', () async {
      await firestore.collection('follows').add({
        'followerUserId': 'viewer',
        'targetUserId': 'creator',
        'isActive': true,
      });
      await firestore.collection('follows').add({
        'followerUserId': 'creator',
        'targetUserId': 'viewer',
        'isActive': true,
      });
      final FollowButtonState state = await service.getButtonState(
        viewerId: 'viewer',
        creatorId: 'creator',
      );
      expect(state, FollowButtonState.connected);
      expect(state.isTappable, isTrue);
    });

    test('returns following for one-way follow', () async {
      await firestore.collection('follows').add({
        'followerUserId': 'viewer',
        'targetUserId': 'creator',
        'isActive': true,
      });
      final FollowButtonState state = await service.getButtonState(
        viewerId: 'viewer',
        creatorId: 'creator',
      );
      expect(state, FollowButtonState.following);
    });

    test('returns follow when not following', () async {
      final FollowButtonState state = await service.getButtonState(
        viewerId: 'viewer',
        creatorId: 'other',
      );
      expect(state, FollowButtonState.follow);
      expect(state.showGradient, isTrue);
    });
  });
}
