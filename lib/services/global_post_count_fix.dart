import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Global Post Count Fix - Automatically fixes post counts for all users
class GlobalPostCountFix {
  static final GlobalPostCountFix _instance = GlobalPostCountFix._internal();
  factory GlobalPostCountFix() => _instance;
  GlobalPostCountFix._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Fix post counts for all users globally
  Future<void> fixAllUsersPostCounts() async {
    try {
      if (kDebugMode) {
        debugPrint(
            '🌍 GLOBAL FIX: Starting global post count fix for all users');
      }

      // Get all users
      final usersSnapshot = await _firestore.collection('users').get();

      if (kDebugMode) {
        debugPrint(
            '🌍 GLOBAL FIX: Found ${usersSnapshot.docs.length} users to process');
      }

      int fixedCount = 0;
      int errorCount = 0;

      for (final userDoc in usersSnapshot.docs) {
        try {
          final userId = userDoc.id;
          final userData = userDoc.data();
          final currentPostCount = userData['postCount'] ?? 0;

          // Get all videos for this user
          final videosSnapshot = await _firestore
              .collection('videos')
              .where('userId', isEqualTo: userId)
              .get();

          // Count all videos (simplified logic - count any video that exists)
          int actualCount = videosSnapshot.docs.length;

          if (actualCount != currentPostCount) {
            // Update the user's postCount
            await _firestore.collection('users').doc(userId).update({
              'postCount': actualCount,
              'lastGlobalFix': FieldValue.serverTimestamp(),
            });

            if (kDebugMode) {
              debugPrint(
                  '🌍 GLOBAL FIX: Fixed user $userId: $currentPostCount → $actualCount');
            }
            fixedCount++;
          } else {
            if (kDebugMode) {
              debugPrint(
                  '🌍 GLOBAL FIX: User $userId already correct: $actualCount');
            }
          }
        } catch (e) {
          if (kDebugMode) {
            debugPrint('🌍 GLOBAL FIX: Error fixing user ${userDoc.id}: $e');
          }
          errorCount++;
        }
      }

      if (kDebugMode) {
        debugPrint(
            '🌍 GLOBAL FIX: Completed! Fixed $fixedCount users, $errorCount errors');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('🌍 GLOBAL FIX: Failed to fix all users: $e');
      }
    }
  }

  /// Fix post count for a specific user
  Future<bool> fixUserPostCount(String userId) async {
    try {
      if (kDebugMode) {
        debugPrint('🌍 GLOBAL FIX: Fixing post count for user $userId');
      }

      // Get all videos for this user
      final videosSnapshot = await _firestore
          .collection('videos')
          .where('userId', isEqualTo: userId)
          .get();

      // Count all videos (simplified logic - count any video that exists)
      int actualCount = videosSnapshot.docs.length;

      // Update the user's postCount
      await _firestore.collection('users').doc(userId).update({
        'postCount': actualCount,
        'lastGlobalFix': FieldValue.serverTimestamp(),
      });

      if (kDebugMode) {
        debugPrint('🌍 GLOBAL FIX: Fixed user $userId to $actualCount posts');
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('🌍 GLOBAL FIX: Failed to fix user $userId: $e');
      }
      return false;
    }
  }
}
