import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Syncs video stats (views, likes) to creator's user doc.
/// Replaces onVideoWrite Cloud Function for app-initiated updates.
class CreatorStatsSyncService {
  static final CreatorStatsSyncService _instance =
      CreatorStatsSyncService._internal();
  factory CreatorStatsSyncService() => _instance;
  CreatorStatsSyncService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Sync like delta to creator's totalLikes. Call when app updates video.likes.
  Future<void> syncLikeToCreator({
    required String videoId,
    String? creatorId,
    required int delta,
  }) async {
    if (delta == 0) return;
    final cid = creatorId ?? await _getCreatorId(videoId);
    if (cid == null) return;
    try {
      await _firestore.collection('users').doc(cid).update({
        'totalLikes': FieldValue.increment(delta),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (kDebugMode) {
        debugPrint(
            'CreatorStatsSync: totalLikes ${delta >= 0 ? "+" : ""}$delta for $cid');
      }
    } catch (e) {
      debugPrint('CreatorStatsSync: syncLike failed: $e');
    }
  }

  /// Sync view delta to creator's totalViews. Call when app updates video.views.
  Future<void> syncViewToCreator({
    required String videoId,
    String? creatorId,
    required int delta,
  }) async {
    if (delta == 0) return;
    final cid = creatorId ?? await _getCreatorId(videoId);
    if (cid == null) return;
    try {
      await _firestore.collection('users').doc(cid).update({
        'totalViews': FieldValue.increment(delta),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (kDebugMode) {
        debugPrint(
            'CreatorStatsSync: totalViews ${delta >= 0 ? "+" : ""}$delta for $cid');
      }
    } catch (e) {
      debugPrint('CreatorStatsSync: syncView failed: $e');
    }
  }

  /// Sync both views and likes in one batch.
  Future<void> syncToCreator({
    required String videoId,
    String? creatorId,
    int deltaViews = 0,
    int deltaLikes = 0,
  }) async {
    if (deltaViews == 0 && deltaLikes == 0) return;
    final cid = creatorId ?? await _getCreatorId(videoId);
    if (cid == null) return;
    try {
      final updates = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (deltaViews != 0) updates['totalViews'] = FieldValue.increment(deltaViews);
      if (deltaLikes != 0) updates['totalLikes'] = FieldValue.increment(deltaLikes);
      await _firestore.collection('users').doc(cid).update(updates);
    } catch (e) {
      debugPrint('CreatorStatsSync: sync failed: $e');
    }
  }

  Future<String?> _getCreatorId(String videoId) async {
    try {
      final doc = await _firestore.collection('videos').doc(videoId).get();
      if (!doc.exists) return null;
      final data = doc.data();
      return (data?['userId'] ?? data?['creatorId'] ?? data?['creator_id'])
          as String?;
    } catch (_) {
      return null;
    }
  }
}
