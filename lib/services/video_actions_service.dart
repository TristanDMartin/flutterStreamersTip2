import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final videoActionsServiceProvider = Provider<VideoActionsService>((ref) {
  return VideoActionsService();
});

class VideoActionsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final firebase_auth.FirebaseAuth _auth = firebase_auth.FirebaseAuth.instance;

  Future<String?> getCurrentUserId() async {
    return _auth.currentUser?.uid;
  }

  Future<void> saveVideo(String videoId) async {
    try {
      final videoDoc = await _firestore.collection('videos').doc(videoId).get();
      if (!videoDoc.exists) {
        throw Exception('Video not found');
      }
      final userId = await getCurrentUserId();
      final ownerUid = videoDoc.data()?['userId'] as String?;
      final allowSave = videoDoc.data()?['allowSave'] as bool? ?? true;
      if (userId != ownerUid && !allowSave) {
        throw Exception('Video owner has disabled downloads');
      }
      throw UnimplementedError(
        'Video download feature requires additional dependencies. Coming soon!',
      );
    } catch (e) {
      rethrow;
    }
  }

  Future<void> setPrivacy(String videoId, String visibility) async {
    try {
      final userId = await getCurrentUserId();
      if (userId == null) throw Exception('User not authenticated');
      final videoRef = _firestore.collection('videos').doc(videoId);
      final videoDoc = await videoRef.get();
      if (!videoDoc.exists) {
        throw Exception('Video not found');
      }
      final ownerUid = videoDoc.data()?['userId'] as String?;
      if (ownerUid != userId) {
        throw Exception('Only video owner can change privacy');
      }
      await videoRef.update({
        'visibility': visibility,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateCaption(String videoId, String caption) async {
    try {
      final userId = await getCurrentUserId();
      if (userId == null) throw Exception('User not authenticated');
      final videoRef = _firestore.collection('videos').doc(videoId);
      final videoDoc = await videoRef.get();
      if (!videoDoc.exists) {
        throw Exception('Video not found');
      }
      final ownerUid = videoDoc.data()?['userId'] as String?;
      if (ownerUid != userId) {
        throw Exception('Only video owner can update caption');
      }
      await videoRef.update({
        'caption': caption,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      rethrow;
    }
  }

  Future<void> pinVideo(String videoId) async {
    try {
      final userId = await getCurrentUserId();
      if (userId == null) throw Exception('User not authenticated');
      final videoRef = _firestore.collection('videos').doc(videoId);
      final videoDoc = await videoRef.get();
      if (!videoDoc.exists) {
        throw Exception('Video not found');
      }
      final ownerUid = videoDoc.data()?['userId'] as String?;
      if (ownerUid != userId) {
        throw Exception('Only video owner can pin videos');
      }
      final userRef = _firestore.collection('users').doc(userId);
      final userDoc = await userRef.get();
      final pinnedVideoIds =
          List<String>.from(userDoc.data()?['pinnedVideoIds'] ?? []);
      if (pinnedVideoIds.contains(videoId)) {
        return;
      }
      if (pinnedVideoIds.length >= 3) {
        throw Exception('Maximum 3 videos can be pinned. Unpin one first.');
      }
      pinnedVideoIds.add(videoId);
      final batch = _firestore.batch();
      batch.update(userRef, {'pinnedVideoIds': pinnedVideoIds});
      batch.update(videoRef, {
        'isPinned': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await batch.commit();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> unpinVideo(String videoId) async {
    try {
      final userId = await getCurrentUserId();
      if (userId == null) throw Exception('User not authenticated');
      final videoRef = _firestore.collection('videos').doc(videoId);
      final videoDoc = await videoRef.get();
      if (!videoDoc.exists) {
        throw Exception('Video not found');
      }
      final ownerUid = videoDoc.data()?['userId'] as String?;
      if (ownerUid != userId) {
        throw Exception('Only video owner can unpin videos');
      }
      final userRef = _firestore.collection('users').doc(userId);
      final userDoc = await userRef.get();
      final pinnedVideoIds =
          List<String>.from(userDoc.data()?['pinnedVideoIds'] ?? []);
      pinnedVideoIds.remove(videoId);
      final batch = _firestore.batch();
      batch.update(userRef, {'pinnedVideoIds': pinnedVideoIds});
      batch.update(videoRef, {
        'isPinned': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await batch.commit();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteVideo(String videoId) async {
    try {
      final userId = await getCurrentUserId();
      if (userId == null) throw Exception('User not authenticated');
      final videoRef = _firestore.collection('videos').doc(videoId);
      final videoDoc = await videoRef.get();
      if (!videoDoc.exists) {
        throw Exception('Video not found');
      }
      final ownerUid = videoDoc.data()?['userId'] as String?;
      if (ownerUid != userId) {
        throw Exception('Only video owner can delete videos');
      }
      await videoRef.update({
        'status': 'deleted',
        'deletedAt': FieldValue.serverTimestamp(),
      });
      final userRef = _firestore.collection('users').doc(userId);
      await userRef.update({
        'postCount': FieldValue.increment(-1),
      });
      final userVideosRef = _firestore
          .collection('user_videos')
          .doc(userId)
          .collection('posts')
          .doc(videoId);
      await userVideosRef.delete();
      final pinnedVideoIds = List<String>.from(
        (await userRef.get()).data()?['pinnedVideoIds'] ?? [],
      );
      if (pinnedVideoIds.contains(videoId)) {
        pinnedVideoIds.remove(videoId);
        await userRef.update({'pinnedVideoIds': pinnedVideoIds});
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> addToFavorites(String videoId) async {
    try {
      final userId = await getCurrentUserId();
      if (userId == null) throw Exception('User not authenticated');
      final favoriteRef = _firestore
          .collection('user_favorites')
          .doc(userId)
          .collection('videos')
          .doc(videoId);
      await favoriteRef.set({
        'videoId': videoId,
        'createdAt': FieldValue.serverTimestamp(),
      });
      final videoRef = _firestore.collection('videos').doc(videoId);
      await videoRef.update({
        'isFavorited': true,
      });
    } catch (e) {
      rethrow;
    }
  }

  Future<void> removeFromFavorites(String videoId) async {
    try {
      final userId = await getCurrentUserId();
      if (userId == null) throw Exception('User not authenticated');
      final favoriteRef = _firestore
          .collection('user_favorites')
          .doc(userId)
          .collection('videos')
          .doc(videoId);
      await favoriteRef.delete();
      final videoRef = _firestore.collection('videos').doc(videoId);
      await videoRef.update({
        'isFavorited': false,
      });
    } catch (e) {
      rethrow;
    }
  }

  Future<void> reportVideo(String videoId, String reason) async {
    try {
      final userId = await getCurrentUserId();
      if (userId == null) throw Exception('User not authenticated');
      await _firestore.collection('reports').add({
        'videoId': videoId,
        'reporterId': userId,
        'reason': reason,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'pending',
      });
    } catch (e) {
      rethrow;
    }
  }

  Future<void> copyLink(String videoId) async {
    try {
      final link = 'https://streamerstip.com/video/$videoId';
      await Clipboard.setData(ClipboardData(text: link));
    } catch (e) {
      rethrow;
    }
  }

  Future<void> shareVideo(String videoId) async {
    try {
      final link = 'https://streamerstip.com/video/$videoId';
      await Share.share(
        link,
        subject: 'Check out this video on StreamersTip',
      );
    } catch (e) {
      rethrow;
    }
  }
}
