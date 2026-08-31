import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streamers_tip/services/user_blocking_service.dart';

import '../../test_support/fake_firebase_auth.dart';

void main() {
  group('isBlockedByEitherStore', () {
    test('is true when either store has the pair', () {
      expect(
        isBlockedByEitherStore(inUserBlocks: true, inBlockedUsers: false),
        isTrue,
      );
      expect(
        isBlockedByEitherStore(inUserBlocks: false, inBlockedUsers: true),
        isTrue,
      );
    });

    test('is false only when both stores miss the pair', () {
      expect(
        isBlockedByEitherStore(inUserBlocks: false, inBlockedUsers: false),
        isFalse,
      );
    });
  });

  group('UserBlockingService dual-read', () {
    late FakeFirebaseFirestore firestore;
    late UserBlockingService service;

    setUp(() async {
      firestore = FakeFirebaseFirestore();
      UserBlockingService.debugSetOverrides(
        firestore: firestore,
        auth: FakeFirebaseAuth(FakeFirebaseUser('viewer')),
      );
      service = UserBlockingService();
      await seedUser(firestore, 'viewer');
      await seedUser(firestore, 'blocked');
    });

    tearDown(() {
      UserBlockingService.debugSetOverrides(firestore: null, auth: null);
    });

    test('isUserBlocked is true from user_blocks only', () async {
      await firestore.collection('user_blocks').add(<String, dynamic>{
        'blockerId': 'viewer',
        'blockedUserId': 'blocked',
      });
      expect(await service.isUserBlocked('blocked'), isTrue);
    });

    test('isUserBlocked is true from blockedUsers only', () async {
      await firestore
          .collection('users')
          .doc('viewer')
          .collection('blockedUsers')
          .doc('blocked')
          .set(<String, dynamic>{'blockedUserId': 'blocked'});
      expect(await service.isUserBlocked('blocked'), isTrue);
    });

    test('hasBlockBetween is true from either store either direction', () async {
      await firestore
          .collection('users')
          .doc('blocked')
          .collection('blockedUsers')
          .doc('viewer')
          .set(<String, dynamic>{'blockedUserId': 'viewer'});
      expect(
        await service.hasBlockBetween(
          userId: 'viewer',
          otherUserId: 'blocked',
        ),
        isTrue,
      );
    });

    test('getBlockedUserRecords unions both stores', () async {
      await firestore.collection('user_blocks').add(<String, dynamic>{
        'blockerId': 'viewer',
        'blockedUserId': 'from-root',
      });
      await firestore
          .collection('users')
          .doc('viewer')
          .collection('blockedUsers')
          .doc('from-sub')
          .set(<String, dynamic>{'blockedUserId': 'from-sub'});
      final List<String> actual = (await service.getBlockedUserRecords())
          .map((BlockedUserRecord record) => record.userId)
          .toList()
        ..sort();
      expect(actual, <String>['from-root', 'from-sub']);
    });
  });
}
