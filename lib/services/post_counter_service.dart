import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../utils/post_count_rules.dart';
import '../utils/public_video_count_rules.dart';

/// Post Counter Service - Single source of truth for user post counts
///
/// This service manages post counting according to strict rules:
/// ✅ Published, visible posts owned by the user
/// 🚫 Excludes: drafts, scheduled posts (not yet live), soft-deleted/archived,
///    posts under moderation/hidden, and private posts (if privacy excludes them)
class PostCounterService {
  static final PostCounterService _instance = PostCounterService._internal();
  factory PostCounterService() => _instance;
  PostCounterService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Map<String, dynamic> _postCountDelta(int delta) {
    return <String, dynamic>{
      'postCount': FieldValue.increment(delta),
      'stats.postCount': FieldValue.increment(delta),
      'lastPostCountUpdate': FieldValue.serverTimestamp(),
    };
  }

  /// Increment post count when a post is published
  Future<bool> incrementPostCount(String userId, {String? postId}) async {
    try {
      if (kDebugMode) {
        debugPrint(
            '📊 PostCounterService: Incrementing post count for user: $userId');
      }

      await _firestore.collection('users').doc(userId).update(_postCountDelta(1));

      if (kDebugMode) {
        debugPrint(
            '✅ PostCounterService: Post count incremented for user: $userId');
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ PostCounterService: Failed to increment post count: $e');
      }
      return false;
    }
  }

  /// Decrement post count when a post is unpublished/deleted/archived
  Future<bool> decrementPostCount(String userId, {String? postId}) async {
    try {
      if (kDebugMode) {
        debugPrint(
            '📊 PostCounterService: Decrementing post count for user: $userId');
      }

      await _firestore.collection('users').doc(userId).update(_postCountDelta(-1));

      // Ensure count doesn't go below 0
      await _ensureNonNegativeCount(userId);

      if (kDebugMode) {
        debugPrint(
            '✅ PostCounterService: Post count decremented for user: $userId');
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ PostCounterService: Failed to decrement post count: $e');
      }
      return false;
    }
  }

  /// Update post count based on post status change
  Future<bool> updatePostCountForStatusChange(
    String userId,
    String oldStatus,
    String newStatus, {
    String? postId,
  }) async {
    try {
      final bool oldCounts = videoCountsAsUserPost(<String, dynamic>{
        'status': oldStatus,
        'privacy': 'everyone',
      });
      final bool newCounts = videoCountsAsUserPost(<String, dynamic>{
        'status': newStatus,
        'privacy': 'everyone',
      });

      if (oldCounts && !newCounts) {
        // Post was countable, now it's not - decrement
        return await decrementPostCount(userId, postId: postId);
      } else if (!oldCounts && newCounts) {
        // Post wasn't countable, now it is - increment
        return await incrementPostCount(userId, postId: postId);
      }
      // No change needed
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
            '❌ PostCounterService: Failed to update post count for status change: $e');
      }
      return false;
    }
  }

  /// Update post count based on privacy change
  Future<bool> updatePostCountForPrivacyChange(
    String userId,
    String oldPrivacy,
    String newPrivacy, {
    String? postId,
  }) async {
    try {
      final bool oldCounts = videoCountsAsUserPost(<String, dynamic>{
        'status': 'published',
        'privacy': oldPrivacy,
      });
      final bool newCounts = videoCountsAsUserPost(<String, dynamic>{
        'status': 'published',
        'privacy': newPrivacy,
      });

      if (oldCounts && !newCounts) {
        // Post was countable, now it's not - decrement
        return await decrementPostCount(userId, postId: postId);
      } else if (!oldCounts && newCounts) {
        // Post wasn't countable, now it is - increment
        return await incrementPostCount(userId, postId: postId);
      }
      // No change needed
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
            '❌ PostCounterService: Failed to update post count for privacy change: $e');
      }
      return false;
    }
  }

  /// Get current post count for a user
  Future<int> getPostCount(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        return doc.data()?['postCount'] ?? 0;
      }
      return 0;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ PostCounterService: Failed to get post count: $e');
      }
      return 0;
    }
  }

  /// Stream post count changes for real-time updates
  Stream<int> watchPostCount(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .map((snapshot) => snapshot.data()?['postCount'] ?? 0);
  }

  /// Reconcile post count by counting actual posts (drift repair)
  Future<int> reconcilePostCount(String userId) async {
    try {
      if (kDebugMode) {
        debugPrint(
            '🔧 PostCounterService: Reconciling post count for user: $userId');
      }

      final Map<String, QueryDocumentSnapshot<Map<String, dynamic>>> docMap =
          <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
      for (final String ownerField in <String>['userId', 'user_id']) {
        final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
            .collection('videos')
            .where(ownerField, isEqualTo: userId)
            .get();
        for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
            in snapshot.docs) {
          docMap[doc.id] = doc;
        }
      }

      int actualCount = 0;
      for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
          in docMap.values) {
        final Map<String, dynamic> data = doc.data();
        if (!videoOwnerIsUser(data, userId)) {
          continue;
        }
        if (!videoCountsAsPublicPostForStats(data)) {
          continue;
        }
        actualCount++;
      }

      await _firestore.collection('users').doc(userId).update({
        'postCount': actualCount,
        'stats.postCount': actualCount,
        'lastPostCountReconciliation': FieldValue.serverTimestamp(),
      });

      if (kDebugMode) {
        debugPrint(
            '✅ PostCounterService: Reconciled post count for user: $userId - $actualCount posts');
      }

      return actualCount;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ PostCounterService: Failed to reconcile post count: $e');
      }
      return 0;
    }
  }

  /// Batch reconcile multiple users (admin function)
  Future<Map<String, int>> batchReconcilePostCounts(
      List<String> userIds) async {
    final results = <String, int>{};

    for (final userId in userIds) {
      try {
        final count = await reconcilePostCount(userId);
        results[userId] = count;
      } catch (e) {
        if (kDebugMode) {
          debugPrint(
              '❌ PostCounterService: Failed to reconcile for user $userId: $e');
        }
        results[userId] = 0;
      }
    }

    return results;
  }

  /// Ensure post count doesn't go below 0
  Future<void> _ensureNonNegativeCount(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        final currentCount = doc.data()?['postCount'] ?? 0;
        if (currentCount < 0) {
          await _firestore.collection('users').doc(userId).update({
            'postCount': 0,
            'stats.postCount': 0,
            'postCountCorrected': FieldValue.serverTimestamp(),
          });
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
            '❌ PostCounterService: Failed to ensure non-negative count: $e');
      }
    }
  }

  /// Get post count statistics for analytics
  Future<Map<String, dynamic>> getPostCountStats(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        final data = doc.data()!;
        return {
          'currentCount': data['postCount'] ?? 0,
          'lastUpdate': data['lastPostCountUpdate'],
          'lastReconciliation': data['lastPostCountReconciliation'],
          'corrected': data['postCountCorrected'] != null,
        };
      }
      return {'currentCount': 0};
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ PostCounterService: Failed to get post count stats: $e');
      }
      return {'currentCount': 0};
    }
  }
}
