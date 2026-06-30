import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/home_provider.dart';
import '../providers/video_service_provider.dart';
import '../utils/category_schema.dart';
import '../utils/video_caption_resolver.dart';
import '../utils/video_url_resolver.dart';
import 'mux_upload_service.dart';
import 'optimistic_video_service.dart';

/// Waits for Mux/Firestore finalization, repairs owner fields, inserts feed
/// indexes if the webhook missed them, and refreshes profile/home/discover.
class VideoPublishFinalizeService {
  VideoPublishFinalizeService._();
  static final VideoPublishFinalizeService instance =
      VideoPublishFinalizeService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Called when Mux processing completes (or from background after upload).
  Future<bool> finalizeDiscoverability({
    required String videoId,
    required String userId,
    WidgetRef? ref,
    String? caption,
    bool waitForMux = true,
    Duration timeout = const Duration(minutes: 5),
  }) async {
    String privacy = 'Everyone';
    String category = 'gaming';
    try {
      final DocumentSnapshot<Map<String, dynamic>> snap = await _firestore
          .collection('videos')
          .doc(videoId)
          .get(const GetOptions(source: Source.server));
      final Map<String, dynamic>? data = snap.data();
      if (data != null) {
        privacy = (data['privacy'] as String?)?.trim().isNotEmpty == true
            ? data['privacy'] as String
            : privacy;
        category = (data['category'] as String?)?.trim().isNotEmpty == true
            ? data['category'] as String
            : (data['metadata']?['categoryCanonical'] as String?) ?? category;
      }
    } catch (_) {}
    if (waitForMux) {
      return waitUntilDiscoverable(
        videoId: videoId,
        userId: userId,
        privacy: privacy,
        category: category,
        caption: caption,
        timeout: timeout,
        ref: ref,
      );
    }
    try {
      await _repairVideoDocIfNeeded(
        videoId: videoId,
        userId: userId,
        privacy: privacy,
        category: category,
        caption: caption,
      );
      await _ensureFeedIndexes(
        videoId: videoId,
        userId: userId,
        privacy: privacy,
        category: category,
        caption: caption,
      );
      await refreshAllSurfaces(userId: userId, ref: ref);
      return true;
    } catch (e) {
      debugPrint(
        '❌ VideoPublishFinalizeService: finalizeDiscoverability failed: $e',
      );
      return false;
    }
  }

  Future<bool> waitUntilDiscoverable({
    required String videoId,
    required String userId,
    required String privacy,
    required String category,
    String? caption,
    Duration timeout = const Duration(minutes: 5),
    WidgetRef? ref,
  }) async {
    try {
      final MuxReadyResult muxReady = await MuxUploadService.instance
          .waitForReady(videoId: videoId, timeout: timeout);
      await _repairVideoDocIfNeeded(
        videoId: videoId,
        userId: userId,
        privacy: privacy,
        category: category,
        caption: caption,
        thumbnailUrl: muxReady.thumbnailUrl,
        hlsUrl: muxReady.hlsUrl,
      );
      await _ensureFeedIndexes(
        videoId: videoId,
        userId: userId,
        privacy: privacy,
        category: category,
        caption: caption,
      );
      await refreshAllSurfaces(userId: userId, ref: ref);
      debugPrint(
        '✅ VideoPublishFinalizeService: $videoId is discoverable '
        '(muxPlaybackId=${muxReady.muxPlaybackId})',
      );
      return true;
    } catch (e, st) {
      debugPrint(
        '❌ VideoPublishFinalizeService: finalize failed for $videoId: $e',
      );
      debugPrint('$st');
      return false;
    }
  }

  Future<void> _repairVideoDocIfNeeded({
    required String videoId,
    required String userId,
    required String privacy,
    required String category,
    String? caption,
    String? thumbnailUrl,
    String? hlsUrl,
  }) async {
    final DocumentSnapshot<Map<String, dynamic>> snap = await _firestore
        .collection('videos')
        .doc(videoId)
        .get(const GetOptions(source: Source.server));
    if (!snap.exists || snap.data() == null) {
      throw Exception('videos/$videoId missing after Mux ready');
    }
    final Map<String, dynamic> data = snap.data()!;
    final String? owner = getOwnerId(data);
    final CanonicalCategory existing = readCanonicalCategoryFromVideo(data);
    final String categorySource = existing.isPopulated
        ? existing.categoryId
        : (category.trim().isEmpty ? kDefaultCategoryId : category);
    final Map<String, dynamic> categoryFields =
        buildCanonicalCategoryFields(categorySource);
    final String visibility = switch (privacy) {
      'Followers' || 'followers_only' => 'followers_only',
      'Private' || 'private' => 'private',
      _ => 'public',
    };
    final Map<String, dynamic> patch = <String, dynamic>{};
    final String repairedCaption =
        caption?.trim().isNotEmpty == true ? caption!.trim() : '';
    if (owner == null || owner != userId) {
      patch['userId'] = userId;
      patch['creatorId'] = userId;
      patch['creator_id'] = userId;
      debugPrint(
        '🔧 VideoPublishFinalizeService: repaired owner on videos/$videoId',
      );
    }
    if (data['privacy'] == null && privacy.isNotEmpty) {
      patch['privacy'] = privacy;
    }
    if (data['visibility'] == null) {
      patch['visibility'] = visibility;
    }
    if (repairedCaption.isNotEmpty &&
        resolveVideoCaptionFromFirestoreData(data).isEmpty) {
      patch['caption'] = repairedCaption;
      patch['description'] = repairedCaption;
      patch['title'] = repairedCaption;
    }
    if (!videoHasCanonicalCategoryFields(data) || !existing.isPopulated) {
      patch.addAll(categoryFields);
    } else if (data['categoryName'] == null ||
        (data['categoryName'] as String?)?.trim().isEmpty == true) {
      patch['categoryName'] = categoryFields['categoryName'];
    }
    if (data['isReadyForFeed'] != true) {
      patch['isReadyForFeed'] = true;
    }
    if (data['isDeleted'] != false) {
      patch['isDeleted'] = false;
    }
    if (data['visible'] != true) {
      patch['visible'] = true;
    }
    final String? status = data['status'] as String?;
    if (status == 'processing' || status == 'uploading') {
      patch['status'] = 'ready';
    }
    if (thumbnailUrl != null &&
        thumbnailUrl.isNotEmpty &&
        (data['thumbnailUrl'] as String?)?.isEmpty != false) {
      patch['thumbnailUrl'] = thumbnailUrl;
      patch['thumbnailURL'] = thumbnailUrl;
    }
    if (hlsUrl != null &&
        hlsUrl.isNotEmpty &&
        (data['videoUrl'] as String?)?.isEmpty != false) {
      patch['videoUrl'] = hlsUrl;
      patch['videoURL'] = hlsUrl;
      patch['hlsUrl'] = hlsUrl;
      patch['hls_url'] = hlsUrl;
      patch['canonicalPlaybackUrl'] = hlsUrl;
    }
    if (patch.isEmpty) {
      return;
    }
    patch['updatedAt'] = FieldValue.serverTimestamp();
    await _firestore.collection('videos').doc(videoId).set(
          patch,
          SetOptions(merge: true),
        );
  }

  Future<void> _ensureFeedIndexes({
    required String videoId,
    required String userId,
    required String privacy,
    required String category,
    String? caption,
  }) async {
    final String trimmedCaption = caption?.trim() ?? '';
    final DocumentReference<Map<String, dynamic>> userVideoRef = _firestore
        .collection('users')
        .doc(userId)
        .collection('videos')
        .doc(videoId);
    await userVideoRef.set(<String, dynamic>{
      'videoId': videoId,
      'userId': userId,
      'status': 'ready',
      'visible': true,
      'category': category,
      'privacy': privacy,
      if (trimmedCaption.isNotEmpty) 'caption': trimmedCaption,
      if (trimmedCaption.isNotEmpty) 'description': trimmedCaption,
      if (trimmedCaption.isNotEmpty) 'title': trimmedCaption,
      'updatedAt': FieldValue.serverTimestamp(),
      'addedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    final bool isPublic =
        privacy == 'Everyone' || privacy == 'Public' || privacy == 'public';
    if (!isPublic) {
      return;
    }
    final DocumentReference<Map<String, dynamic>> forYouRef = _firestore
        .collection('feeds')
        .doc('for_you')
        .collection('videos')
        .doc(videoId);
    final DocumentSnapshot<Map<String, dynamic>> forYouSnap =
        await forYouRef.get();
    if (!forYouSnap.exists) {
      await forYouRef.set(<String, dynamic>{
        'videoId': videoId,
        'userId': userId,
        'privacy': privacy,
        'category': category,
        'status': 'ready',
        'addedAt': FieldValue.serverTimestamp(),
      });
      debugPrint(
        '🔧 VideoPublishFinalizeService: inserted feeds/for_you/videos/$videoId',
      );
    }
    final DocumentReference<Map<String, dynamic>> followingRef = _firestore
        .collection('feeds')
        .doc('following')
        .collection('videos')
        .doc(videoId);
    final DocumentSnapshot<Map<String, dynamic>> followingSnap =
        await followingRef.get();
    if (!followingSnap.exists) {
      await followingRef.set(<String, dynamic>{
        'videoId': videoId,
        'userId': userId,
        'privacy': privacy,
        'status': 'ready',
        'addedAt': FieldValue.serverTimestamp(),
      });
    }
    if (category.isNotEmpty) {
      final DocumentReference<Map<String, dynamic>> categoryRef = _firestore
          .collection('feeds')
          .doc('categories')
          .collection(category)
          .doc(videoId);
      final DocumentSnapshot<Map<String, dynamic>> categorySnap =
          await categoryRef.get();
      if (!categorySnap.exists) {
        await categoryRef.set(<String, dynamic>{
          'videoId': videoId,
          'userId': userId,
          'category': category,
          'privacy': privacy,
          'status': 'ready',
          'addedAt': FieldValue.serverTimestamp(),
        });
      }
    }
  }

  Future<void> refreshAllSurfaces({
    required String userId,
    WidgetRef? ref,
  }) async {
    if (ref != null) {
      try {
        await ref
            .read(videoServiceStateProvider.notifier)
            .loadAllVideos(source: 'publish_finalize');
        await ref
            .read(videoServiceStateProvider.notifier)
            .mergeProfileVideosForUser(userId, forceServer: true);
        ref.invalidate(userVideosProvider(userId));
        await ref.read(homeProvider.notifier).refreshFeed();
      } catch (e) {
        debugPrint('⚠️ VideoPublishFinalizeService: riverpod refresh: $e');
      }
    }
    OptimisticVideoService().requestFeedRefresh();
  }
}
