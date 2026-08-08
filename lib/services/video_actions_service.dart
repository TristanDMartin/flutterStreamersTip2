import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'unified_bookmark_service.dart';
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
      final Map<String, dynamic> data =
          Map<String, dynamic>.from(videoDoc.data() ?? <String, dynamic>{});
      final String ownerUid = _resolveOwnerId(data);
      if (ownerUid != userId) {
        throw Exception('Only video owner can change privacy');
      }
      final Map<String, dynamic> privacyPatch =
          _privacyPatchFromVisibility(visibility);
      privacyPatch['updatedAt'] = FieldValue.serverTimestamp();
      await videoRef.update(privacyPatch);
      try {
        await _firestore
            .collection('users')
            .doc(userId)
            .collection('videos')
            .doc(videoId)
            .set(privacyPatch, SetOptions(merge: true));
      } catch (_) {}
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateCaption(String videoId, String caption) async {
    await updateVideoMetadata(
      videoId: videoId,
      caption: caption,
    );
  }

  /// Canonical post-publish metadata update (no media reupload).
  /// Writes only Firestore-allowlisted fields and mirrors the user subdoc.
  Future<void> updateVideoMetadata({
    required String videoId,
    String? caption,
    List<String>? hashtags,
    String? category,
    String? privacy,
    bool? allowComments,
    String? thumbnailUrl,
  }) async {
    final String? userId = await getCurrentUserId();
    if (userId == null) throw Exception('User not authenticated');
    final DocumentReference<Map<String, dynamic>> videoRef =
        _firestore.collection('videos').doc(videoId);
    final DocumentSnapshot<Map<String, dynamic>> videoDoc =
        await videoRef.get();
    if (!videoDoc.exists) {
      throw Exception('Video not found');
    }
    final Map<String, dynamic> data =
        Map<String, dynamic>.from(videoDoc.data() ?? <String, dynamic>{});
    if (data['isDeleted'] == true ||
        (data['status']?.toString().toLowerCase() == 'deleted')) {
      throw Exception('Video is deleted');
    }
    final String ownerUid = _resolveOwnerId(data);
    if (ownerUid != userId) {
      throw Exception('Only video owner can update metadata');
    }
    final Map<String, dynamic> patch = <String, dynamic>{};
    if (caption != null) {
      final String nextCaption = caption.trim();
      patch['caption'] = nextCaption;
      patch['title'] = nextCaption;
    }
    if (hashtags != null) {
      patch['hashtags'] = _normalizeHashtags(hashtags);
    }
    if (category != null) {
      final String nextCategory = category.trim();
      patch['category'] = nextCategory;
      if (nextCategory.isNotEmpty) {
        patch['categoryId'] =
            nextCategory.toLowerCase().replaceAll(RegExp(r'\s+'), '_');
      }
    }
    if (allowComments != null) {
      patch['allowComments'] = allowComments;
    }
    if (thumbnailUrl != null) {
      final String nextThumb = thumbnailUrl.trim();
      patch['thumbnailUrl'] = nextThumb;
      patch['thumbnailURL'] = nextThumb;
      patch['thumbnail_url'] = nextThumb;
    }
    if (privacy != null) {
      patch.addAll(_privacyPatchFromVisibility(privacy));
    }
    if (patch.isEmpty) {
      throw Exception('No editable fields provided');
    }
    patch['updatedAt'] = FieldValue.serverTimestamp();
    await videoRef.update(patch);
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('videos')
          .doc(videoId)
          .set(patch, SetOptions(merge: true));
    } catch (_) {}
  }

  String _resolveOwnerId(Map<String, dynamic> data) {
    for (final String key in <String>[
      'ownerId',
      'userId',
      'user_id',
      'creatorId',
      'creator_id',
      'uid',
      'authorId',
      'uploadedBy',
    ]) {
      final Object? value = data[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return '';
  }

  Map<String, dynamic> _privacyPatchFromVisibility(String visibility) {
    final String raw = visibility.trim().toLowerCase();
    if (raw == 'connections' ||
        raw == 'followers' ||
        raw == 'followers_only' ||
        raw == 'followers-only') {
      return <String, dynamic>{
        'privacy': 'Connections',
        'isPublic': false,
        'isConnectionsOnly': true,
      };
    }
    if (raw == 'private' || raw == 'only me' || raw == 'onlyme') {
      return <String, dynamic>{
        'privacy': 'Private',
        'isPublic': false,
        'isConnectionsOnly': false,
      };
    }
    return <String, dynamic>{
      'privacy': 'Everyone',
      'isPublic': true,
      'isConnectionsOnly': false,
    };
  }

  List<String> _normalizeHashtags(List<String> input) {
    final List<String> out = <String>[];
    final Set<String> seen = <String>{};
    for (final String raw in input) {
      final String cleaned =
          raw.trim().replaceFirst(RegExp(r'^#+'), '').replaceAll(RegExp(r'\s+'), '');
      if (cleaned.isEmpty) continue;
      final String tag = '#${cleaned.toLowerCase()}';
      if (seen.contains(tag)) continue;
      seen.add(tag);
      out.add(tag);
      if (out.length >= 20) break;
    }
    return out;
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
    final String? userId = await getCurrentUserId();
    if (userId == null) {
      throw Exception('User not authenticated');
    }
    final UnifiedBookmarkService bookmarks = UnifiedBookmarkService.instance;
    await bookmarks.initialize(userId);
    if (bookmarks.isBookmarked(videoId)) {
      return;
    }
    final BookmarkResult result = await bookmarks.toggleBookmark(videoId);
    if (!result.success) {
      throw Exception(result.error ?? 'Failed to favorite video');
    }
  }

  Future<void> removeFromFavorites(String videoId) async {
    final String? userId = await getCurrentUserId();
    if (userId == null) {
      throw Exception('User not authenticated');
    }
    final UnifiedBookmarkService bookmarks = UnifiedBookmarkService.instance;
    await bookmarks.initialize(userId);
    if (!bookmarks.isBookmarked(videoId)) {
      return;
    }
    final BookmarkResult result = await bookmarks.toggleBookmark(videoId);
    if (!result.success) {
      throw Exception(result.error ?? 'Failed to remove favorite');
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
