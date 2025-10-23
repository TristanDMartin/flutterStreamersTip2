import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:csv/csv.dart';
import 'admin_service.dart';

class AdvancedAdminService {
  static final AdvancedAdminService instance = AdvancedAdminService._internal();
  factory AdvancedAdminService() => instance;
  AdvancedAdminService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Ban a user
  Future<void> banUser({
    required String userId,
    required String reason,
    DateTime? until,
  }) async {
    try {
      await AdminService.instance.logAdminAction('ban_user', data: {
        'userId': userId,
        'reason': reason,
        'until': until?.toIso8601String(),
      });

      await _firestore.collection('users').doc(userId).update({
        'status': 'banned',
        'banReason': reason,
        'bannedAt': FieldValue.serverTimestamp(),
        'bannedUntil': until,
        'bannedBy': _auth.currentUser?.uid,
      });

      debugPrint('✅ User banned: $userId');
    } catch (e) {
      debugPrint('❌ Error banning user: $e');
      rethrow;
    }
  }

  /// Suspend a user temporarily
  Future<void> suspendUser({
    required String userId,
    required String reason,
    required Duration duration,
  }) async {
    final until = DateTime.now().add(duration);
    await banUser(userId: userId, reason: reason, until: until);
  }

  /// Unban a user
  Future<void> unbanUser(String userId) async {
    try {
      await AdminService.instance.logAdminAction('unban_user', data: {
        'userId': userId,
      });

      await _firestore.collection('users').doc(userId).update({
        'status': 'active',
        'banReason': FieldValue.delete(),
        'bannedAt': FieldValue.delete(),
        'bannedUntil': FieldValue.delete(),
        'bannedBy': FieldValue.delete(),
        'unbannedAt': FieldValue.serverTimestamp(),
        'unbannedBy': _auth.currentUser?.uid,
      });

      debugPrint('✅ User unbanned: $userId');
    } catch (e) {
      debugPrint('❌ Error unbanning user: $e');
      rethrow;
    }
  }

  /// Delete a video
  Future<void> deleteVideo({
    required String videoId,
    required String reason,
  }) async {
    try {
      await AdminService.instance.logAdminAction('delete_video', data: {
        'videoId': videoId,
        'reason': reason,
      });

      await _firestore.collection('videos').doc(videoId).update({
        'status': 'deleted',
        'deletedAt': FieldValue.serverTimestamp(),
        'deletedBy': _auth.currentUser?.uid,
        'deletionReason': reason,
      });

      debugPrint('✅ Video deleted: $videoId');
    } catch (e) {
      debugPrint('❌ Error deleting video: $e');
      rethrow;
    }
  }

  /// Delete a comment
  Future<void> deleteComment({
    required String videoId,
    required String commentId,
    required String reason,
  }) async {
    try {
      await AdminService.instance.logAdminAction('delete_comment', data: {
        'videoId': videoId,
        'commentId': commentId,
        'reason': reason,
      });

      await _firestore
          .collection('videos')
          .doc(videoId)
          .collection('comments')
          .doc(commentId)
          .update({
        'status': 'deleted',
        'deletedAt': FieldValue.serverTimestamp(),
        'deletedBy': _auth.currentUser?.uid,
        'deletionReason': reason,
      });

      debugPrint('✅ Comment deleted: $commentId');
    } catch (e) {
      debugPrint('❌ Error deleting comment: $e');
      rethrow;
    }
  }

  /// Export analytics to CSV
  Future<String> exportAnalyticsToCSV() async {
    try {
      final users = await _firestore.collection('users').get();
      final videos = await _firestore.collection('videos').get();

      List<List<String>> csvData = [
        ['Type', 'ID', 'Username/Caption', 'Created At', 'Stats'],
      ];

      for (final user in users.docs) {
        final data = user.data();
        csvData.add([
          'User',
          user.id,
          data['username'] ?? 'N/A',
          data['createdAt']?.toString() ?? 'N/A',
          'Followers: ${data['followerCount'] ?? 0}, Following: ${data['followingCount'] ?? 0}',
        ]);
      }

      for (final video in videos.docs) {
        final data = video.data();
        csvData.add([
          'Video',
          video.id,
          data['caption'] ?? 'N/A',
          data['createdAt']?.toString() ?? 'N/A',
          'Views: ${data['views'] ?? 0}, Likes: ${data['likeCount'] ?? 0}',
        ]);
      }

      final csv = const ListToCsvConverter().convert(csvData);
      await AdminService.instance.logAdminAction('export_analytics_csv');
      return csv;
    } catch (e) {
      debugPrint('❌ Error exporting analytics: $e');
      rethrow;
    }
  }

  /// Advanced search across collections
  Future<Map<String, List<Map<String, dynamic>>>> advancedSearch(
      String query) async {
    try {
      final results = <String, List<Map<String, dynamic>>>{
        'users': [],
        'videos': [],
        'messages': [],
      };

      final queryLower = query.toLowerCase();

      // Search users
      final users = await _firestore
          .collection('users')
          .where('username', isGreaterThanOrEqualTo: queryLower)
          .where('username', isLessThan: '${queryLower}z')
          .limit(20)
          .get();

      for (final doc in users.docs) {
        results['users']!.add({'id': doc.id, ...doc.data()});
      }

      // Search videos by caption
      final videos = await _firestore
          .collection('videos')
          .where('caption', isGreaterThanOrEqualTo: queryLower)
          .where('caption', isLessThan: '${queryLower}z')
          .limit(20)
          .get();

      for (final doc in videos.docs) {
        results['videos']!.add({'id': doc.id, ...doc.data()});
      }

      // Search messages (limited for performance)
      final messages = await _firestore
          .collection('messages')
          .where('text', isGreaterThanOrEqualTo: queryLower)
          .where('text', isLessThan: '${queryLower}z')
          .limit(20)
          .get();

      for (final doc in messages.docs) {
        results['messages']!.add({'id': doc.id, ...doc.data()});
      }

      await AdminService.instance.logAdminAction('advanced_search', data: {
        'query': query,
        'resultsCount':
            results.values.map((e) => e.length).reduce((a, b) => a + b),
      });

      return results;
    } catch (e) {
      debugPrint('❌ Error performing advanced search: $e');
      rethrow;
    }
  }

  /// Send push notification to specific users
  Future<void> sendPushNotification({
    required List<String> userIds,
    required String title,
    required String body,
    Map<String, String>? data,
  }) async {
    try {
      await AdminService.instance
          .logAdminAction('send_push_notification', data: {
        'userIds': userIds,
        'title': title,
        'recipientCount': userIds.length,
      });

      for (final userId in userIds) {
        await _firestore
            .collection('users')
            .doc(userId)
            .collection('admin_notifications')
            .add({
          'title': title,
          'body': body,
          'data': data,
          'sentAt': FieldValue.serverTimestamp(),
          'sentBy': _auth.currentUser?.uid,
        });
      }

      debugPrint('✅ Push notification sent to ${userIds.length} users');
    } catch (e) {
      debugPrint('❌ Error sending push notification: $e');
      rethrow;
    }
  }

  /// Send push notification to all users
  Future<void> sendBroadcastNotification({
    required String title,
    required String body,
    Map<String, String>? data,
  }) async {
    try {
      final users = await _firestore.collection('users').get();
      final userIds = users.docs.map((doc) => doc.id).toList();
      await sendPushNotification(
        userIds: userIds,
        title: title,
        body: body,
        data: data,
      );
    } catch (e) {
      debugPrint('❌ Error sending broadcast notification: $e');
      rethrow;
    }
  }

  /// Get full activity history
  Stream<QuerySnapshot> getActivityHistory({int limit = 1000}) {
    return _firestore
        .collection('admin_logs')
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots();
  }

  /// Set system maintenance mode
  Future<void> setMaintenanceMode(bool enabled, {String? message}) async {
    try {
      await AdminService.instance.logAdminAction('set_maintenance_mode', data: {
        'enabled': enabled,
        'message': message,
      });

      await _firestore.collection('system').doc('settings').set({
        'maintenanceMode': enabled,
        'maintenanceMessage': message ?? 'System under maintenance',
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': _auth.currentUser?.uid,
      }, SetOptions(merge: true));

      debugPrint('✅ Maintenance mode: $enabled');
    } catch (e) {
      debugPrint('❌ Error setting maintenance mode: $e');
      rethrow;
    }
  }

  /// Set feature flag
  Future<void> setFeatureFlag(String flagName, bool enabled) async {
    try {
      await AdminService.instance.logAdminAction('set_feature_flag', data: {
        'flagName': flagName,
        'enabled': enabled,
      });

      await _firestore.collection('system').doc('feature_flags').set({
        flagName: enabled,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': _auth.currentUser?.uid,
      }, SetOptions(merge: true));

      debugPrint('✅ Feature flag $flagName: $enabled');
    } catch (e) {
      debugPrint('❌ Error setting feature flag: $e');
      rethrow;
    }
  }

  /// Get system settings
  Future<Map<String, dynamic>> getSystemSettings() async {
    try {
      final doc = await _firestore.collection('system').doc('settings').get();
      return doc.data() ?? {};
    } catch (e) {
      debugPrint('❌ Error getting system settings: $e');
      return {};
    }
  }

  /// Get feature flags
  Future<Map<String, dynamic>> getFeatureFlags() async {
    try {
      final doc =
          await _firestore.collection('system').doc('feature_flags').get();
      return doc.data() ?? {};
    } catch (e) {
      debugPrint('❌ Error getting feature flags: $e');
      return {};
    }
  }

  /// Get analytics data for charts
  Future<Map<String, dynamic>> getAnalyticsData() async {
    try {
      final now = DateTime.now();
      final last30Days = now.subtract(const Duration(days: 30));

      // User growth
      final userGrowth = <DateTime, int>{};
      for (int i = 0; i < 30; i++) {
        final date = last30Days.add(Duration(days: i));
        final users = await _firestore
            .collection('users')
            .where('createdAt',
                isLessThan:
                    Timestamp.fromDate(date.add(const Duration(days: 1))))
            .count()
            .get();
        userGrowth[date] = users.count ?? 0;
      }

      // Video uploads
      final videoUploads = <DateTime, int>{};
      for (int i = 0; i < 30; i++) {
        final date = last30Days.add(Duration(days: i));
        final videos = await _firestore
            .collection('videos')
            .where('createdAt',
                isGreaterThanOrEqualTo: Timestamp.fromDate(date),
                isLessThan:
                    Timestamp.fromDate(date.add(const Duration(days: 1))))
            .count()
            .get();
        videoUploads[date] = videos.count ?? 0;
      }

      return {
        'userGrowth': userGrowth,
        'videoUploads': videoUploads,
      };
    } catch (e) {
      debugPrint('❌ Error getting analytics data: $e');
      return {};
    }
  }
}
