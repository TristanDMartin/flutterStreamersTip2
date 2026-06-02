import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'video_download_service.dart';

final videoActionsServiceProvider = Provider<VideoActionsService>((ref) {
  return VideoActionsService();
});

class VideoActionsService {
  static FirebaseFirestore? _firestoreOverride;
  static firebase_auth.FirebaseAuth? _authOverride;
  static FirebaseFunctions? _functionsOverride;

  @visibleForTesting
  static void debugSetOverrides({
    FirebaseFirestore? firestore,
    firebase_auth.FirebaseAuth? auth,
    FirebaseFunctions? functions,
  }) {
    _firestoreOverride = firestore;
    _authOverride = auth;
    _functionsOverride = functions;
  }

  FirebaseFirestore get _firestore =>
      _firestoreOverride ?? FirebaseFirestore.instance;
  firebase_auth.FirebaseAuth get _auth =>
      _authOverride ?? firebase_auth.FirebaseAuth.instance;
  FirebaseFunctions get _functions =>
      _functionsOverride ??
      FirebaseFunctions.instanceFor(region: 'us-central1');

  Future<String?> getCurrentUserId() async {
    return _auth.currentUser?.uid;
  }

  Future<void> saveVideo(String videoId) async {
    try {
      final videoDoc = await _firestore.collection('videos').doc(videoId).get();
      if (!videoDoc.exists) {
        throw Exception('Video not found');
      }
      final data = videoDoc.data()!;
      final userId = await getCurrentUserId();
      final ownerUid = data['userId'] as String?;
      final allowSave = data['allowSave'] as bool? ?? true;
      final videoUrl = data['videoUrl'] ?? data['videoURL'] as String?;

      if (videoUrl == null || videoUrl.isEmpty) {
        throw Exception('Video URL not available');
      }

      if (userId != ownerUid && !allowSave) {
        throw Exception('Video owner has disabled downloads');
      }

      // Use VideoDownloadService to download the video
      final downloadService = VideoDownloadService();
      await downloadService.downloadVideo(videoId, videoUrl);
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

  /// Soft-delete via `deleteVideo` callable (us-central1) only.
  Future<void> deleteVideo(String videoId, {String source = 'app'}) async {
    try {
      final HttpsCallable callable = _functions.httpsCallable('deleteVideo');
      await callable.call(<String, dynamic>{
        'videoId': videoId,
        'source': source,
      });
      debugPrint('✅ VideoActionsService: Video $videoId soft-deleted');
    } catch (e) {
      debugPrint('❌ VideoActionsService: Error deleting video $videoId: $e');
      rethrow;
    }
  }

  Future<void> deleteVideos(
    List<String> videoIds, {
    String source = 'app',
  }) async {
    if (videoIds.isEmpty) {
      return;
    }
    try {
      final HttpsCallable callable = _functions.httpsCallable('deleteVideos');
      await callable.call(<String, dynamic>{
        'videoIds': videoIds,
        'source': source,
      });
      debugPrint(
        '✅ VideoActionsService: Soft-deleted ${videoIds.length} videos',
      );
    } catch (e) {
      debugPrint('❌ VideoActionsService: Bulk delete failed: $e');
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

  /// Negative signal for feed ranking (see [EnhancedAlgorithmService]).
  Future<void> markNotInterested({
    required String videoId,
    required String creatorId,
  }) async {
    final String? userId = await getCurrentUserId();
    if (userId == null) {
      throw Exception('User not authenticated');
    }
    await _firestore.collection('user_interactions').add({
      'userId': userId,
      'videoId': videoId,
      'creatorId': creatorId,
      'interactionType': 'not_interested',
      'watchPercentage': 0.0,
      'timestamp': FieldValue.serverTimestamp(),
    });
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
      await SharePlus.instance.share(
        ShareParams(
          text: link,
          subject: 'Check out this video on StreamersTip',
        ),
      );
    } catch (e) {
      rethrow;
    }
  }
}
