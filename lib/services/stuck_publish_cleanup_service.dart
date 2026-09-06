import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'optimistic_video_persistence.dart';
import 'optimistic_video_service.dart';
import 'upload_job_storage_service.dart';
import 'upload_status_manager.dart';
import 'video_deletion_service.dart';
import 'video_service.dart';

/// Clears Instant Publish / upload ghosts that never became READY.
class StuckPublishCleanupService {
  StuckPublishCleanupService._();

  static final StuckPublishCleanupService instance =
      StuckPublishCleanupService._();

  // v2: no illegal client isReadyForFeed / deleted / visible patches.
  static const String _oneShotPrefsKey = 'stuck_publish_purge_v2_done';

  static const Set<String> _stuckStatuses = <String>{
    'uploading',
    'pending',
    'processing',
    'failed',
  };

  /// Local durable pending + upload jobs + optional Firestore tombstones.
  ///
  /// Full purge (local jobs + server stuck uploading/processing) runs once.
  /// Later launches only clear orphan Instant Publish rows (no upload job).
  Future<StuckPublishCleanupResult> discardAllStuckPublishes({
    bool tombstoneServerStuck = true,
    VideoService? videoService,
  }) async {
    final String? uid = FirebaseAuth.instance.currentUser?.uid;
    final bool oneShot = !(await _hasCompletedOneShotPurge());
    final List<String> localIds = OptimisticVideoService()
        .optimisticVideos
        .map((v) => v.videoId)
        .toList();
    final List<String> persistedIds =
        (await OptimisticVideoPersistence.instance.loadAll())
            .map((v) => v.videoId)
            .toList();
    final Set<String> knownLocalIds = <String>{...localIds, ...persistedIds};

    if (oneShot) {
      OptimisticVideoService().clearAllOptimisticVideos();
      await UploadStatusManager().discardAllUploads();
    } else {
      // Keep Instant Publish rows that still have a resumable upload job.
      final Set<String> jobVideoIds = (await UploadJobStorageService()
              .loadResumableJobs())
          .map((job) => job.videoId)
          .whereType<String>()
          .where((id) => id.isNotEmpty)
          .toSet();
      for (final String id in knownLocalIds) {
        if (!jobVideoIds.contains(id)) {
          OptimisticVideoService().removeOptimisticVideo(id);
        }
      }
    }

    int removedFromFeed = 0;
    final VideoService? feed = videoService;
    if (feed != null) {
      for (final String id in knownLocalIds) {
        feed.removeVideo(
          id,
          source: 'stuck_publish_cleanup',
          reason: 'discard_pending_publish',
        );
        removedFromFeed += 1;
      }
    }

    int serverDeleted = 0;
    final bool shouldTombstoneServer = tombstoneServerStuck && oneShot;
    if (shouldTombstoneServer) {
      if (uid != null && uid.isNotEmpty) {
        serverDeleted = await _tombstoneServerStuckVideos(uid);
        await _markOneShotPurgeDone();
      } else {
        unawaited(_tombstoneWhenSignedIn());
      }
    }

    debugPrint(
      'STUCK_PUBLISH_CLEANUP local=${knownLocalIds.length} '
      'feedRemoved=$removedFromFeed serverDeleted=$serverDeleted '
      'oneShot=$oneShot uid=${uid ?? '-'}',
    );
    return StuckPublishCleanupResult(
      localPendingCleared: knownLocalIds.length,
      serverStuckDeleted: serverDeleted,
      clearedVideoIds: knownLocalIds.toList(),
    );
  }

  Future<bool> _hasCompletedOneShotPurge() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_oneShotPrefsKey) == true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _markOneShotPurgeDone() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_oneShotPrefsKey, true);
    } catch (_) {
      // Best-effort.
    }
  }

  Future<void> _tombstoneWhenSignedIn() async {
    try {
      if (await _hasCompletedOneShotPurge()) {
        return;
      }
      final User? user = await FirebaseAuth.instance
          .authStateChanges()
          .firstWhere((User? u) => u != null)
          .timeout(const Duration(seconds: 30));
      final String? nextUid = user?.uid;
      if (nextUid == null || nextUid.isEmpty) {
        return;
      }
      final int deleted = await _tombstoneServerStuckVideos(nextUid);
      await _markOneShotPurgeDone();
      debugPrint(
        'STUCK_PUBLISH_CLEANUP deferred_server_deleted=$deleted uid=$nextUid',
      );
    } catch (e) {
      debugPrint('STUCK_PUBLISH_CLEANUP deferred_server skipped: $e');
    }
  }

  Future<int> _tombstoneServerStuckVideos(String uid) async {
    final FirebaseFirestore db = FirebaseFirestore.instance;
    final Set<String> ids = <String>{};
    for (final String field in <String>['ownerId', 'userId', 'creatorId']) {
      try {
        final QuerySnapshot<Map<String, dynamic>> snap = await db
            .collection('videos')
            .where(field, isEqualTo: uid)
            .limit(80)
            .get();
        for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
            in snap.docs) {
          final Map<String, dynamic> data = doc.data();
          if (_isStuckPublishDoc(data)) {
            ids.add(doc.id);
          }
        }
      } catch (e) {
        debugPrint('STUCK_PUBLISH_CLEANUP query $field failed: $e');
      }
    }

    if (ids.isEmpty) {
      await _markOneShotPurgeDone();
      return 0;
    }

    final VideoDeletionService deletion = VideoDeletionService();
    int deleted = 0;
    for (final String videoId in ids) {
      try {
        await deletion.deleteVideo(videoId, source: 'stuck_publish_cleanup');
        deleted += 1;
        continue;
      } catch (e) {
        debugPrint(
          'STUCK_PUBLISH_CLEANUP callable failed videoId=$videoId error=$e',
        );
      }
      // Rules allow owner soft-delete only with this exact field set.
      // Never write isReadyForFeed / deleted / visible (permission-denied toast).
      try {
        await db.collection('videos').doc(videoId).update(<String, dynamic>{
          'status': 'deleted',
          'isDeleted': true,
          'deletedAt': FieldValue.serverTimestamp(),
          'deletedBy': uid,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        deleted += 1;
      } catch (e2) {
        debugPrint(
          'STUCK_PUBLISH_CLEANUP soft-delete failed videoId=$videoId error=$e2',
        );
      }
    }
    return deleted;
  }

  bool _isStuckPublishDoc(Map<String, dynamic> data) {
    if (data['isDeleted'] == true || data['deleted'] == true) {
      return false;
    }
    if (data['isReadyForFeed'] == true) {
      return false;
    }
    final String status =
        (data['status'] as String? ?? '').trim().toLowerCase();
    if (_stuckStatuses.contains(status)) {
      return true;
    }
    final String muxStatus =
        (data['muxStatus'] as String? ?? '').trim().toLowerCase();
    if (muxStatus == 'waiting' || muxStatus == 'processing') {
      return true;
    }
    return false;
  }
}

class StuckPublishCleanupResult {
  const StuckPublishCleanupResult({
    required this.localPendingCleared,
    required this.serverStuckDeleted,
    required this.clearedVideoIds,
  });

  final int localPendingCleared;
  final int serverStuckDeleted;
  final List<String> clearedVideoIds;
}
