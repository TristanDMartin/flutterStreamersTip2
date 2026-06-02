import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streamers_tip/services/video_actions_service.dart';

import '../../test_support/fake_firebase_auth.dart';

void main() {
  group('VideoActionsService', () {
    late FakeFirebaseFirestore firestore;
    late VideoActionsService service;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      VideoActionsService.debugSetOverrides(
        firestore: firestore,
        auth: FakeFirebaseAuth(FakeFirebaseUser('user-1')),
      );
      service = VideoActionsService();
    });

    tearDown(() {
      VideoActionsService.debugSetOverrides(firestore: null, auth: null);
    });

    test('markNotInterested writes user_interactions doc', () async {
      await service.markNotInterested(
        videoId: 'video-1',
        creatorId: 'creator-1',
      );
      final snapshot = await firestore.collection('user_interactions').get();
      expect(snapshot.docs.length, 1);
      final data = snapshot.docs.first.data();
      expect(data['userId'], 'user-1');
      expect(data['videoId'], 'video-1');
      expect(data['creatorId'], 'creator-1');
      expect(data['interactionType'], 'not_interested');
    });
  });
}
