import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Post Counter Reconciliation Service
///
/// This service reconciles existing posts with the post counter system
/// to fix any discrepancies between actual posts and the counter.
class PostCounterReconciliation {
  static final PostCounterReconciliation _instance =
      PostCounterReconciliation._internal();
  factory PostCounterReconciliation() => _instance;
  PostCounterReconciliation._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Post counting rules (same as PostCounterService)
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
    'public',
    'followers',
  ];

  /// Reconcile post count for current user
  Future<int> reconcileCurrentUserPosts() async {
    final user = _auth.currentUser;
    if (user == null) {
      if (kDebugMode) {
        debugPrint('❌ No authenticated user for reconciliation');
      }
      return 0;
    }

    return await reconcileUserPosts(user.uid);
  }

  /// Reconcile post count for a specific user
  Future<int> reconcileUserPosts(String userId) async {
    try {
      if (kDebugMode) {
        debugPrint('🔧 Reconciling post count for user: $userId');
      }

      // Count actual countable posts
      final querySnapshot = await _firestore
          .collection('videos')
          .where('userId', isEqualTo: userId)
          .get();

      int actualCount = 0;
      final List<Map<String, dynamic>> countablePosts = [];

      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        final status = data['status'] as String? ?? 'draft';
        final privacy = data['privacy'] as String? ?? 'private';

        if (_shouldCountPost(status, privacy)) {
          actualCount++;
          countablePosts.add({
            'id': doc.id,
            'status': status,
            'privacy': privacy,
            'caption': data['caption'] ?? 'No caption',
          });
        }
      }

      // Update the counter with the actual count
      await _firestore.collection('users').doc(userId).update({
        'postCount': actualCount,
        'lastPostCountReconciliation': FieldValue.serverTimestamp(),
        'reconciliationDetails': {
          'totalVideosFound': querySnapshot.docs.length,
          'countablePosts': actualCount,
          'reconciledAt': FieldValue.serverTimestamp(),
        },
      });

      if (kDebugMode) {
        debugPrint(
            '✅ Reconciled post count for user $userId: $actualCount posts');
        debugPrint('📊 Total videos found: ${querySnapshot.docs.length}');
        debugPrint('📊 Countable posts: $actualCount');

        if (countablePosts.isNotEmpty) {
          debugPrint('📋 Countable posts:');
          for (final post in countablePosts) {
            debugPrint(
                '  - ${post['id']}: ${post['status']}/${post['privacy']} - "${post['caption']}"');
          }
        }
      }

      return actualCount;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Failed to reconcile post count for user $userId: $e');
      }
      return 0;
    }
  }

  /// Reconcile all users (admin function)
  Future<Map<String, int>> reconcileAllUsers() async {
    final results = <String, int>{};

    try {
      // Get all users
      final usersSnapshot = await _firestore.collection('users').get();

      if (kDebugMode) {
        debugPrint(
            '🔧 Reconciling post counts for ${usersSnapshot.docs.length} users');
      }

      for (final userDoc in usersSnapshot.docs) {
        final userId = userDoc.id;
        try {
          final count = await reconcileUserPosts(userId);
          results[userId] = count;
        } catch (e) {
          if (kDebugMode) {
            debugPrint('❌ Failed to reconcile for user $userId: $e');
          }
          results[userId] = 0;
        }
      }

      if (kDebugMode) {
        debugPrint('✅ Reconciliation complete for ${results.length} users');
        final totalPosts =
            results.values.fold(0, (total, postCount) => total + postCount);
        debugPrint('📊 Total posts counted: $totalPosts');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Failed to reconcile all users: $e');
      }
    }

    return results;
  }

  /// Get detailed post analysis for a user
  Future<Map<String, dynamic>> analyzeUserPosts(String userId) async {
    try {
      final querySnapshot = await _firestore
          .collection('videos')
          .where('userId', isEqualTo: userId)
          .get();

      final Map<String, int> statusCounts = {};
      final Map<String, int> privacyCounts = {};
      int countablePosts = 0;
      int totalPosts = querySnapshot.docs.length;

      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        final status = data['status'] as String? ?? 'draft';
        final privacy = data['privacy'] as String? ?? 'private';

        // Count by status
        statusCounts[status] = (statusCounts[status] ?? 0) + 1;

        // Count by privacy
        privacyCounts[privacy] = (privacyCounts[privacy] ?? 0) + 1;

        // Check if countable
        if (_shouldCountPost(status, privacy)) {
          countablePosts++;
        }
      }

      return {
        'userId': userId,
        'totalPosts': totalPosts,
        'countablePosts': countablePosts,
        'statusBreakdown': statusCounts,
        'privacyBreakdown': privacyCounts,
        'currentCounter': await _getCurrentCounter(userId),
        'needsReconciliation':
            countablePosts != await _getCurrentCounter(userId),
      };
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Failed to analyze posts for user $userId: $e');
      }
      return {'error': e.toString()};
    }
  }

  /// Get current counter value from user document
  Future<int> _getCurrentCounter(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        return userDoc.data()?['postCount'] ?? 0;
      }
      return 0;
    } catch (e) {
      return 0;
    }
  }

  /// Check if a post should be counted
  bool _shouldCountPost(String status, String privacy) {
    final statusLower = status.toLowerCase();
    final privacyLower = privacy.toLowerCase();

    return _countableStatuses.contains(statusLower) &&
        !_excludedStatuses.contains(statusLower) &&
        _countablePrivacyLevels.contains(privacyLower);
  }

  /// Quick fix for current user (call this to fix your profile)
  Future<bool> quickFixCurrentUser() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        if (kDebugMode) {
          debugPrint('❌ No authenticated user for quick fix');
        }
        return false;
      }

      if (kDebugMode) {
        debugPrint('🚀 Quick fix: Reconciling posts for current user...');
      }

      final count = await reconcileUserPosts(user.uid);

      if (kDebugMode) {
        debugPrint('✅ Quick fix complete! Your post count is now: $count');
      }

      return count > 0;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Quick fix failed: $e');
      }
      return false;
    }
  }
}
