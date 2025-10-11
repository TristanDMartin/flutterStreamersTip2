import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

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

  /// Post counting rules - what counts as a "post"
  static const List<String> _countableStatuses = [
    'published',
    'public',
  ];

  static const List<String> _excludedStatuses = [
    'draft',
    'scheduled',
    'archived',
    'deleted',
    'hidden',
    'moderation',
    'private',
  ];

  static const List<String> _countablePrivacyLevels = [
    'everyone', // Maps to 'Everyone' privacy level
    'connections', // Maps to 'Connections' privacy level
    'public', // Legacy support
    'followers', // Legacy support
  ];

  /// Increment post count when a post is published
  Future<bool> incrementPostCount(String userId, {String? postId}) async {
    try {
      if (kDebugMode) {
        debugPrint(
            '📊 PostCounterService: Incrementing post count for user: $userId');
      }

      // Use atomic increment to prevent race conditions
      await _firestore.collection('users').doc(userId).update({
        'postCount': FieldValue.increment(1),
        'lastPostCountUpdate': FieldValue.serverTimestamp(),
      });

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

      // Use atomic decrement with minimum value of 0
      await _firestore.collection('users').doc(userId).update({
        'postCount': FieldValue.increment(-1),
        'lastPostCountUpdate': FieldValue.serverTimestamp(),
      });

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
      final oldCounts = _shouldCountPost(oldStatus);
      final newCounts = _shouldCountPost(newStatus);

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
      final oldCounts = _shouldCountPrivacy(oldPrivacy);
      final newCounts = _shouldCountPrivacy(newPrivacy);

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

      // Count actual countable posts
      final querySnapshot = await _firestore
          .collection('videos')
          .where('userId', isEqualTo: userId)
          .get();

      int actualCount = 0;
      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        final status = data['status'] as String? ?? 'draft';
        final privacy = data['privacy'] as String? ?? 'private';

        if (_shouldCountPost(status) && _shouldCountPrivacy(privacy)) {
          actualCount++;
        }
      }

      // Update the counter with the actual count
      await _firestore.collection('users').doc(userId).update({
        'postCount': actualCount,
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

  /// Check if a post status should be counted
  bool _shouldCountPost(String status) {
    return _countableStatuses.contains(status.toLowerCase()) &&
        !_excludedStatuses.contains(status.toLowerCase());
  }

  /// Check if a privacy level should be counted
  bool _shouldCountPrivacy(String privacy) {
    return _countablePrivacyLevels.contains(privacy.toLowerCase());
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
