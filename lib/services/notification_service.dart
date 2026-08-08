import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Activity notification docs (`notifications/{uid}/items/{id}`) are
/// server-only (Cloud Functions / Admin SDK). Clients may only update
/// `isRead`/`read`/`readAt`/`updatedAt` — see firestore.rules. The methods
/// below are kept as no-op stubs so existing call sites keep compiling
/// while the Cloud Functions in cloud_functions/index.js own all creates.
class NotificationService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  bool _hasUnreadNotifications = false;

  bool get hasUnreadNotifications => _hasUnreadNotifications;

  Future<void> markAllNotificationsAsRead() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      final batch = _db.batch();
      final notificationsRef = _db
          .collection('notifications')
          .doc(currentUser.uid)
          .collection('items')
          .where('isRead', isEqualTo: false);

      final snapshot = await notificationsRef.get();
      for (final doc in snapshot.docs) {
        batch.update(doc.reference, {
          'isRead': true,
          'read': true,
          'readAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
      _hasUnreadNotifications = false;
      debugPrint('✅ Marked all notifications as read');
    } catch (e) {
      debugPrint('❌ Error marking notifications as read: $e');
    }
  }

  Future<void> sendNotification({
    required String userId,
    required String title,
    required String body,
    required Map<String, dynamic> data,
  }) async {
    debugPrint(
        '🚫 NotificationService.sendNotification: server-only contract — Cloud Functions own Activity creates. Skipping flat notifications/ write.');
  }

  Future<List<Map<String, dynamic>>> getUserNotifications(String userId) async {
    try {
      final snapshot = await _db
          .collection('notifications')
          .doc(userId)
          .collection('items')
          .orderBy('timestamp', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          ...data,
        };
      }).toList();
    } catch (e) {
      debugPrint('❌ Error getting user notifications: $e');
      return [];
    }
  }

  /// CF `onFollowCreate` owns follow Activity notifications.
  Future<void> handleFollowEvent({
    required String followerId,
    required String followingId,
  }) async {
    debugPrint(
        '🚫 NotificationService.handleFollowEvent: server-only contract — Cloud Function onFollowCreate owns this write.');
  }

  /// CF `onLikeCreate` owns like Activity notifications.
  Future<void> handleLikeEvent({
    required String likerId,
    required String videoOwnerId,
    required String videoId,
    String? postThumbnailUrl,
  }) async {
    debugPrint(
        '🚫 NotificationService.handleLikeEvent: server-only contract — Cloud Function onLikeCreate owns this write.');
  }

  /// CF `onCommentCreate` owns comment Activity notifications.
  Future<void> handleCommentEvent({
    required String commenterId,
    required String videoOwnerId,
    required String videoId,
    required String commentText,
    String? postThumbnailUrl,
  }) async {
    debugPrint(
        '🚫 NotificationService.handleCommentEvent: server-only contract — Cloud Function onCommentCreate owns this write.');
  }

  /// CF `onTagCreate` owns tag Activity notifications.
  Future<void> handleTagEvent({
    required String taggerId,
    required String taggedUserId,
    required String videoId,
    String? postThumbnailUrl,
  }) async {
    debugPrint(
        '🚫 NotificationService.handleTagEvent: server-only contract — Cloud Function onTagCreate owns this write.');
  }

  /// CF `onMentionCreate` owns mention Activity notifications.
  Future<void> handleMentionEvent({
    required String mentionerId,
    required String mentionedUserId,
    required String videoId,
    String? postThumbnailUrl,
  }) async {
    debugPrint(
        '🚫 NotificationService.handleMentionEvent: server-only contract — Cloud Function onMentionCreate owns this write.');
  }

  Future<void> processBatchNotifications(
      List<Map<String, dynamic>> notifications) async {
    debugPrint(
        '🚫 NotificationService.processBatchNotifications: server-only contract — no batched Activity item writes from client.');
  }
}
