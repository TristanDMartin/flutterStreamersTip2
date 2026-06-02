import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UnifiedBookmarkService Firestore paths', () {
    test('bookmark subcollection write succeeds on fake Firestore', () async {
      final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
      const String videoId = 'vid-1';
      const String userId = 'user-1';
      await firestore.collection('videos').doc(videoId).set({
        'userId': 'owner',
        'videoUrl': 'https://example.com/v.mp4',
      });
      await firestore
          .collection('videos')
          .doc(videoId)
          .collection('bookmarks')
          .doc(userId)
          .set({
        'userId': userId,
        'videoId': videoId,
        'favoritedAt': DateTime.now().toIso8601String(),
      });
      final doc = await firestore
          .collection('videos')
          .doc(videoId)
          .collection('bookmarks')
          .doc(userId)
          .get();
      expect(doc.exists, isTrue);
    });
  });
}
