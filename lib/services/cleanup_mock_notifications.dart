import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// One-time cleanup service to remove mock/test notifications from Firestore
///
/// Run this once to clean up test data:
/// - test_user_1, test_user_2, etc.
/// - video_1, video_2, etc.
/// - test_video
///
/// This will leave real notifications intact.
class CleanupMockNotifications {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Clean up mock notifications for a specific user
  Future<void> cleanupForUser(String userId) async {
    try {
      debugPrint('🧹 Starting mock notification cleanup for user: $userId');

      final notificationsRef = _firestore
          .collection('notifications')
          .doc(userId)
          .collection('items');

      // Get all notifications
      final snapshot = await notificationsRef.get();

      debugPrint('📊 Found ${snapshot.docs.length} total notifications');

      int mockCount = 0;
      int realCount = 0;
      final batch = _firestore.batch();

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final isMock = _isMockNotification(data);

        if (isMock) {
          mockCount++;
          batch.delete(doc.reference);
          debugPrint(
              '❌ Deleting mock: ${doc.id} (${data['type']}, user: ${data['user']?['id']})');
        } else {
          realCount++;
          debugPrint(
              '✅ Keeping real: ${doc.id} (${data['type']}, user: ${data['user']?['id']})');
        }
      }

      if (mockCount > 0) {
        await batch.commit();
        debugPrint('✅ Deleted $mockCount mock notifications');
        debugPrint('✅ Kept $realCount real notifications');
      } else {
        debugPrint('ℹ️ No mock notifications found');
      }

      debugPrint('🎉 Cleanup complete!');
    } catch (e) {
      debugPrint('❌ Error cleaning up mock notifications: $e');
      rethrow;
    }
  }

  /// Check if a notification is mock/test data
  bool _isMockNotification(Map<String, dynamic> data) {
    final userId = data['user']?['id'] as String?;
    final videoId = data['videoId'] as String?;

    // Check for test user IDs
    if (userId != null) {
      if (userId.startsWith('test_user') ||
          userId == 'test_user' ||
          userId.contains('test_')) {
        return true;
      }
    }

    // Check for test video IDs
    if (videoId != null) {
      if (videoId == 'test_video' ||
          videoId.startsWith('video_') ||
          RegExp(r'^video_\d+$').hasMatch(videoId)) {
        return true;
      }
    }

    // Check for stock Unsplash photos (mock data)
    final avatarUrl = data['user']?['avatarURL'] as String?;
    if (avatarUrl != null && avatarUrl.contains('images.unsplash.com')) {
      return true;
    }

    return false;
  }

  /// Preview what would be deleted (dry run)
  Future<void> previewCleanup(String userId) async {
    try {
      debugPrint('👀 Preview: Checking what would be deleted...');

      final snapshot = await _firestore
          .collection('notifications')
          .doc(userId)
          .collection('items')
          .get();

      int mockCount = 0;
      int realCount = 0;

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final isMock = _isMockNotification(data);

        if (isMock) {
          mockCount++;
          debugPrint('❌ Would delete: ${doc.id}');
          debugPrint('   Type: ${data['type']}');
          debugPrint(
              '   User: ${data['user']?['displayName']} (${data['user']?['id']})');
          debugPrint('   VideoId: ${data['videoId']}');
          debugPrint('');
        } else {
          realCount++;
        }
      }

      debugPrint('📊 Summary:');
      debugPrint('   Mock notifications: $mockCount (will be deleted)');
      debugPrint('   Real notifications: $realCount (will be kept)');
      debugPrint('   Total: ${snapshot.docs.length}');
    } catch (e) {
      debugPrint('❌ Error previewing cleanup: $e');
    }
  }
}
