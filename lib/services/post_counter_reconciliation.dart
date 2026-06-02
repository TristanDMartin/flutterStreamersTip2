import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../utils/public_video_count_rules.dart';
import '../utils/swallow_non_fatal.dart';

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
      final List<Map<String, dynamic>> countablePosts =
          <Map<String, dynamic>>[];

      for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
          in docMap.values) {
        final Map<String, dynamic> data = doc.data();
        if (!videoOwnerIsUser(data, userId)) {
          continue;
        }
        if (!videoCountsAsPublicPostForStats(data)) {
          continue;
        }
        try {
          if (!await videoIsPlayableForProfileCount(doc.id, data)) {
            continue;
          }
        } catch (_) {
          continue;
        }
        actualCount++;
        countablePosts.add(<String, dynamic>{
          'id': doc.id,
          'status': data['status'],
          'privacy': data['privacy'],
          'caption': data['caption'] ?? 'No caption',
        });
      }

      // Update the counter with the actual count
      await _firestore.collection('users').doc(userId).update({
        'postCount': actualCount,
        'lastPostCountReconciliation': FieldValue.serverTimestamp(),
        'reconciliationDetails': {
          'totalVideosFound': docMap.length,
          'countablePosts': actualCount,
          'reconciledAt': FieldValue.serverTimestamp(),
        },
      });

      if (kDebugMode) {
        debugPrint(
            '✅ Reconciled post count for user $userId: $actualCount posts');
        debugPrint('📊 Total videos found: ${docMap.length}');
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

      final Map<String, int> statusCounts = <String, int>{};
      final Map<String, int> privacyCounts = <String, int>{};
      int countablePosts = 0;
      final int totalPosts = docMap.length;

      for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
          in docMap.values) {
        final Map<String, dynamic> data = doc.data();
        final String status = data['status'] as String? ?? 'draft';
        final String privacy = data['privacy'] as String? ?? 'private';

        statusCounts[status] = (statusCounts[status] ?? 0) + 1;

        privacyCounts[privacy] = (privacyCounts[privacy] ?? 0) + 1;

        if (!videoOwnerIsUser(data, userId)) {
          continue;
        }
        if (!videoCountsAsPublicPostForStats(data)) {
          continue;
        }
        try {
          if (await videoIsPlayableForProfileCount(doc.id, data)) {
            countablePosts++;
          }
        } catch (e, st) {
          swallowNonFatal('PostCounterReconciliation.countPost', e, st);
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
