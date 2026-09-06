import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/home_provider.dart';
import '../providers/video_service_provider.dart';
import '../utils/video_caption_resolver.dart';
import 'mux_upload_service.dart';
import 'optimistic_video_service.dart';

/// Waits for Mux/Worker finalization and refreshes surfaces.
///
/// Does NOT write server-owned fields (`isReadyForFeed`, `status`, mux IDs,
/// playback URLs, or feed fan-out). Worker/webhook own those.
class VideoPublishFinalizeService {
  VideoPublishFinalizeService._();
  static final VideoPublishFinalizeService instance =
      VideoPublishFinalizeService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Called when Mux processing completes (or from background after upload).
  /// Prefer [container] over WidgetRef so work can finish after the publish
  /// screen is disposed/popped.
  Future<bool> finalizeDiscoverability({
    required String videoId,
    required String userId,
    ProviderContainer? container,
    String? caption,
    bool waitForMux = true,
    Duration timeout = const Duration(minutes: 5),
  }) async {
    debugPrint('FINALIZE_START videoId=$videoId waitForMux=$waitForMux');
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
    } catch (e) {
      debugPrint(
        'FINALIZE_FAILED videoId=$videoId reason=read_denied error=$e',
      );
      // Owner should be able to read their own PROCESSING doc. If not, fail.
      return false;
    }
    if (waitForMux) {
      return waitUntilDiscoverable(
        videoId: videoId,
        userId: userId,
        privacy: privacy,
        category: category,
        caption: caption,
        timeout: timeout,
        container: container,
      );
    }
    try {
      await _syncOwnerMirrorOnly(
        videoId: videoId,
        userId: userId,
        privacy: privacy,
        category: category,
        caption: caption,
      );
      await refreshAllSurfaces(userId: userId, container: container);
      debugPrint('FINALIZE_COMPLETE videoId=$videoId mode=no_wait');
      return true;
    } catch (e) {
      debugPrint(
        'FINALIZE_FAILED videoId=$videoId error=$e',
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
    ProviderContainer? container,
  }) async {
    try {
      final MuxReadyResult muxReady = await MuxUploadService.instance
          .waitForReady(videoId: videoId, timeout: timeout);
      await _syncOwnerMirrorOnly(
        videoId: videoId,
        userId: userId,
        privacy: privacy,
        category: category,
        caption: caption,
      );
      await _patchClientAllowlistedMetadataIfNeeded(
        videoId: videoId,
        caption: caption,
        thumbnailUrl: muxReady.thumbnailUrl,
      );
      await refreshAllSurfaces(userId: userId, container: container);
      debugPrint(
        'FINALIZE_COMPLETE videoId=$videoId '
        'muxPlaybackId=${muxReady.muxPlaybackId}',
      );
      return true;
    } catch (e, st) {
      debugPrint('FINALIZE_FAILED videoId=$videoId error=$e');
      debugPrint('$st');
      return false;
    }
  }

  /// Owner subcollection only — never touch feeds or canonical READY fields.
  Future<void> _syncOwnerMirrorOnly({
    required String videoId,
    required String userId,
    required String privacy,
    required String category,
    String? caption,
  }) async {
    final String trimmedCaption = caption?.trim() ?? '';
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('videos')
        .doc(videoId)
        .set(<String, dynamic>{
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
  }

  /// Optional caption/thumbnail fill using client-allowlisted keys only.
  Future<void> _patchClientAllowlistedMetadataIfNeeded({
    required String videoId,
    String? caption,
    String? thumbnailUrl,
  }) async {
    try {
      final DocumentSnapshot<Map<String, dynamic>> snap = await _firestore
          .collection('videos')
          .doc(videoId)
          .get(const GetOptions(source: Source.server));
      if (!snap.exists || snap.data() == null) {
        return;
      }
      final Map<String, dynamic> data = snap.data()!;
      final Map<String, dynamic> patch = <String, dynamic>{};
      final String repairedCaption =
          caption?.trim().isNotEmpty == true ? caption!.trim() : '';
      if (repairedCaption.isNotEmpty &&
          resolveVideoCaptionFromFirestoreData(data).isEmpty) {
        patch['caption'] = repairedCaption;
        patch['description'] = repairedCaption;
        patch['title'] = repairedCaption;
      }
      if (thumbnailUrl != null &&
          thumbnailUrl.isNotEmpty &&
          (data['thumbnailUrl'] as String?)?.isEmpty != false) {
        patch['thumbnailUrl'] = thumbnailUrl;
        patch['thumbnailURL'] = thumbnailUrl;
      }
      if (patch.isEmpty) {
        return;
      }
      patch['updatedAt'] = FieldValue.serverTimestamp();
      await _firestore.collection('videos').doc(videoId).update(patch);
    } catch (e) {
      debugPrint(
        '⚠️ VideoPublishFinalizeService: allowlisted metadata patch skipped: $e',
      );
    }
  }

  Future<void> refreshAllSurfaces({
    required String userId,
    ProviderContainer? container,
  }) async {
    if (container != null) {
      try {
        await container
            .read(videoServiceStateProvider.notifier)
            .loadAllVideos(source: 'publish_finalize');
        await container
            .read(videoServiceStateProvider.notifier)
            .mergeProfileVideosForUser(userId, forceServer: true);
        container.invalidate(userVideosProvider(userId));
        await container.read(homeProvider.notifier).refreshFeed();
      } catch (e) {
        debugPrint('⚠️ VideoPublishFinalizeService: riverpod refresh: $e');
      }
    }
    OptimisticVideoService().requestFeedRefresh();
  }
}
