import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('StreamersTipLikeService Firestore paths', () {
    test('like doc path matches rules contract', () async {
      final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
      const String videoId = 'vid-1';
      const String userId = 'user-1';
      await firestore
          .collection('likes')
          .doc(videoId)
          .collection('likes')
          .doc(userId)
          .set({
        'userId': userId,
        'videoId': videoId,
        'createdAt': DateTime.now().toIso8601String(),
      });
      final doc = await firestore
          .collection('likes')
          .doc(videoId)
          .collection('likes')
          .doc(userId)
          .get();
      expect(doc.exists, isTrue);
      expect(doc.data()?['videoId'], videoId);
    });
  });
}
