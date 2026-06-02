import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CommentsService Firestore paths', () {
    test('canonical comments subcollection round-trip', () async {
      final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
      const String videoId = 'vid-1';
      await firestore.collection('videos').doc(videoId).set({
        'comments': 0,
        'userId': 'owner',
      });
      await firestore
          .collection('videos')
          .doc(videoId)
          .collection('comments')
          .doc('c1')
          .set({
        'text': 'hello',
        'userId': 'user-1',
        'deleted': false,
      });
      final snapshot = await firestore
          .collection('videos')
          .doc(videoId)
          .collection('comments')
          .get();
      expect(snapshot.docs.length, 1);
      expect(snapshot.docs.first.data()['text'], 'hello');
    });
  });
}
