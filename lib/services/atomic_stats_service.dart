import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'creator_stats_sync_service.dart';

/// Atomic stats service for preventing race conditions
/// Ensures stats updates are consistent across mobile and web platforms
class AtomicStatsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Increment view count atomically (writes to video_analytics; sync job updates videos)
  Future<void> incrementViews(String videoId) async {
    try {
      await _firestore.collection('video_analytics').doc(videoId).set({
        'views': FieldValue.increment(1),
        'lastViewedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      debugPrint('✅ AtomicStatsService: View count incremented for $videoId');
    } catch (e) {
      debugPrint(
          '❌ AtomicStatsService: Error incrementing views for $videoId: $e');
      rethrow;
    }
  }

  /// Like video atomically
  Future<void> likeVideo({
    required String videoId,
    required String userId,
  }) async {
    try {
      final batch = _firestore.batch();
      // 1. Increment video likes count
      batch.update(
        _firestore.collection('videos').doc(videoId),
        {
          'likes': FieldValue.increment(1),
          'updatedAt': FieldValue.serverTimestamp(),
        },
      );
      // 2. Add to user's liked videos collection
      batch.set(
        _firestore
            .collection('users')
            .doc(userId)
            .collection('likedVideos')
            .doc(videoId),
        {
          'likedAt': FieldValue.serverTimestamp(),
          'videoId': videoId,
        },
      );
      // 3. Add to likes subcollection (for like notifications)
      batch.set(
        _firestore
            .collection('likes')
            .doc(videoId)
            .collection('byUser')
            .doc(userId),
        {
          'userId': userId,
          'videoId': videoId,
          'likedAt': FieldValue.serverTimestamp(),
        },
      );
      await batch.commit();
      await CreatorStatsSyncService().syncLikeToCreator(
        videoId: videoId,
        delta: 1,
      );
      debugPrint('✅ AtomicStatsService: Video $videoId liked by user $userId');
    } catch (e) {
      debugPrint(
          '❌ AtomicStatsService: Error liking video $videoId by $userId: $e');
      rethrow;
    }
  }

  /// Unlike video atomically
  Future<void> unlikeVideo({
    required String videoId,
    required String userId,
  }) async {
    try {
      final batch = _firestore.batch();
      // 1. Decrement video likes count
      batch.update(
        _firestore.collection('videos').doc(videoId),
        {
          'likes': FieldValue.increment(-1),
          'updatedAt': FieldValue.serverTimestamp(),
        },
      );
      // 2. Remove from user's liked videos collection
      batch.delete(
        _firestore
            .collection('users')
            .doc(userId)
            .collection('likedVideos')
            .doc(videoId),
      );
      // 3. Remove from likes subcollection
      batch.delete(
        _firestore
            .collection('likes')
            .doc(videoId)
            .collection('byUser')
            .doc(userId),
      );
      await batch.commit();
      await CreatorStatsSyncService().syncLikeToCreator(
        videoId: videoId,
        delta: -1,
      );
      debugPrint(
          '✅ AtomicStatsService: Video $videoId unliked by user $userId');
    } catch (e) {
      debugPrint(
          '❌ AtomicStatsService: Error unliking video $videoId by $userId: $e');
      rethrow;
    }
  }

  /// Check if user has liked a video
  Future<bool> hasLikedVideo({
    required String videoId,
    required String userId,
  }) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('likedVideos')
          .doc(videoId)
          .get();
      return doc.exists;
    } catch (e) {
      debugPrint(
          '❌ AtomicStatsService: Error checking like status for $videoId by $userId: $e');
      return false;
    }
  }

  /// Increment comment count atomically
  Future<void> incrementComments(String videoId) async {
    try {
      await _firestore.collection('videos').doc(videoId).update({
        'comments': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      debugPrint(
          '✅ AtomicStatsService: Comment count incremented for $videoId');
    } catch (e) {
      debugPrint(
          '❌ AtomicStatsService: Error incrementing comments for $videoId: $e');
      rethrow;
    }
  }

  /// Decrement comment count atomically (when comment is deleted)
  Future<void> decrementComments(String videoId) async {
    try {
      await _firestore.collection('videos').doc(videoId).update({
        'comments': FieldValue.increment(-1),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      debugPrint(
          '✅ AtomicStatsService: Comment count decremented for $videoId');
    } catch (e) {
      debugPrint(
          '❌ AtomicStatsService: Error decrementing comments for $videoId: $e');
      rethrow;
    }
  }

  /// Increment share count atomically
  Future<void> incrementShares(String videoId) async {
    try {
      await _firestore.collection('videos').doc(videoId).update({
        'shares': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      debugPrint('✅ AtomicStatsService: Share count incremented for $videoId');
    } catch (e) {
      debugPrint(
          '❌ AtomicStatsService: Error incrementing shares for $videoId: $e');
      rethrow;
    }
  }

  /// Watch video stats in real-time
  Stream<Map<String, dynamic>> watchVideoStats(String videoId) {
    return _firestore
        .collection('videos')
        .doc(videoId)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) {
        return {};
      }
      final data = snapshot.data()!;
      return {
        'views': data['views'] ?? 0,
        'likes': data['likes'] ?? 0,
        'comments': data['comments'] ?? 0,
        'shares': data['shares'] ?? 0,
        'updatedAt': data['updatedAt'],
      };
    });
  }

  /// Get current stats snapshot
  Future<Map<String, int>> getVideoStats(String videoId) async {
    try {
      final doc = await _firestore.collection('videos').doc(videoId).get();
      if (!doc.exists) {
        return {
          'views': 0,
          'likes': 0,
          'comments': 0,
          'shares': 0,
        };
      }
      final data = doc.data()!;
      return {
        'views': (data['views'] ?? 0) as int,
        'likes': (data['likes'] ?? 0) as int,
        'comments': (data['comments'] ?? 0) as int,
        'shares': (data['shares'] ?? 0) as int,
      };
    } catch (e) {
      debugPrint('❌ AtomicStatsService: Error getting stats for $videoId: $e');
      return {
        'views': 0,
        'likes': 0,
        'comments': 0,
        'shares': 0,
      };
    }
  }

  /// Batch update multiple stats at once
  Future<void> updateMultipleStats({
    required String videoId,
    int? viewsIncrement,
    int? likesIncrement,
    int? commentsIncrement,
    int? sharesIncrement,
  }) async {
    try {
      final updates = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (viewsIncrement != null && viewsIncrement != 0) {
        updates['views'] = FieldValue.increment(viewsIncrement);
      }
      if (likesIncrement != null && likesIncrement != 0) {
        updates['likes'] = FieldValue.increment(likesIncrement);
      }
      if (commentsIncrement != null && commentsIncrement != 0) {
        updates['comments'] = FieldValue.increment(commentsIncrement);
      }
      if (sharesIncrement != null && sharesIncrement != 0) {
        updates['shares'] = FieldValue.increment(sharesIncrement);
      }
      if (updates.length > 1) {
        // Only update if there are changes beyond updatedAt
        await _firestore.collection('videos').doc(videoId).update(updates);
        debugPrint('✅ AtomicStatsService: Multiple stats updated for $videoId');
      }
    } catch (e) {
      debugPrint(
          '❌ AtomicStatsService: Error updating multiple stats for $videoId: $e');
      rethrow;
    }
  }
}
