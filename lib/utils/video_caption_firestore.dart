import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'video_caption_resolver.dart';

/// Writes [caption] when the server doc is still missing caption text.
Future<bool> persistVideoCaptionIfMissing({
  required FirebaseFirestore firestore,
  required String videoId,
  required String userId,
  required String caption,
}) async {
  final String trimmedCaption = caption.trim();
  if (trimmedCaption.isEmpty || videoId.isEmpty || userId.isEmpty) {
    return false;
  }
  try {
    final DocumentReference<Map<String, dynamic>> docRef =
        firestore.collection('videos').doc(videoId);
    final DocumentSnapshot<Map<String, dynamic>> snapshot =
        await docRef.get(const GetOptions(source: Source.server));
    if (!snapshot.exists || snapshot.data() == null) {
      return false;
    }
    final Map<String, dynamic> existing = snapshot.data()!;
    final String? storedUserId = existing['userId'] as String?;
    final String? storedCreatorId = existing['creatorId'] as String?;
    final String? storedCreatorSnake = existing['creator_id'] as String?;
    if (storedUserId != userId &&
        storedCreatorId != userId &&
        storedCreatorSnake != userId) {
      return false;
    }
    if (resolveVideoCaptionFromFirestoreData(existing).isNotEmpty) {
      return false;
    }
    await docRef.update(<String, dynamic>{
      'caption': trimmedCaption,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    debugPrint(
      '✅ persistVideoCaptionIfMissing: wrote caption on videos/$videoId',
    );
    return true;
  } catch (e) {
    debugPrint(
      '⚠️ persistVideoCaptionIfMissing: failed for videos/$videoId: $e',
    );
    return false;
  }
}

void scheduleVideoCaptionBackfill({
  required FirebaseFirestore firestore,
  required String videoId,
  required String userId,
  required String caption,
  List<Duration> delays = const <Duration>[
    Duration(seconds: 3),
    Duration(seconds: 12),
    Duration(seconds: 30),
  ],
}) {
  final String trimmedCaption = caption.trim();
  if (trimmedCaption.isEmpty) {
    return;
  }
  for (final Duration delay in delays) {
    Future<void>.delayed(delay, () async {
      await persistVideoCaptionIfMissing(
        firestore: firestore,
        videoId: videoId,
        userId: userId,
        caption: trimmedCaption,
      );
    });
  }
}
