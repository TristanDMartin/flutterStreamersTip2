import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'push_notification_service.dart';

class NotificationService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final PushNotificationService _pushNotificationService =
      PushNotificationService();
  bool _hasUnreadNotifications = false;

  bool get hasUnreadNotifications => _hasUnreadNotifications;

  Future<void> markAllNotificationsAsRead() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      // Mark all notifications as read for the current user
      final batch = _db.batch();
      final notificationsRef = _db
          .collection('notifications')
          .doc(currentUser.uid)
          .collection('items')
          .where('isRead', isEqualTo: false);

      final snapshot = await notificationsRef.get();
      for (final doc in snapshot.docs) {
        batch.update(doc.reference, {'isRead': true});
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
    try {
      await _db.collection('notifications').add({
        'userId': userId,
        'title': title,
        'body': body,
        'data': data,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
      });
      debugPrint('✅ Notification sent to user: $userId');
    } catch (e) {
      debugPrint('❌ Error sending notification: $e');
    }
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

  // Real implementations for EventTriggerService calls
  Future<void> handleFollowEvent({
    required String followerId,
    required String followingId,
  }) async {
    try {
      // Get follower user data
      final followerDoc = await _db.collection('users').doc(followerId).get();
      if (!followerDoc.exists) return;

      final followerData = followerDoc.data()!;

      // Create notification for the user being followed
      await _db
          .collection('notifications')
          .doc(followingId)
          .collection('items')
          .add({
        'type': 'follow',
        'user': {
          'id': followerId,
          'username': followerData['username'] ?? 'Unknown',
          'displayName': followerData['displayName'] ?? 'Unknown',
          'avatarURL': followerData['avatarURL'] ?? followerData['avatarUrl'],
        },
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'status': 'delivered',
      });

      debugPrint('✅ Follow notification created: $followerId -> $followingId');

      // Send push notification
      await _pushNotificationService.sendNotificationToUser(
        userId: followingId,
        title: 'New Follower',
        body:
            '${followerData['displayName'] ?? 'Someone'} started following you',
        type: 'follow',
        data: {
          'followerId': followerId,
          'followerUsername': followerData['username'],
          'followerDisplayName': followerData['displayName'],
        },
      );
    } catch (e) {
      debugPrint('❌ Error creating follow notification: $e');
    }
  }

  Future<void> handleLikeEvent({
    required String likerId,
    required String videoOwnerId,
    required String videoId,
    String? postThumbnailUrl,
  }) async {
    try {
      debugPrint(
          '🔔 NotificationService.handleLikeEvent called: $likerId -> $videoOwnerId for video $videoId');

      // Don't create notification if user is liking their own video
      if (likerId == videoOwnerId) {
        debugPrint('🔔 Skipping notification - user liking their own video');
        return;
      }

      // Get liker user data
      final likerDoc = await _db.collection('users').doc(likerId).get();
      if (!likerDoc.exists) {
        debugPrint('🔔 Skipping notification - liker user not found: $likerId');
        return;
      }

      final likerData = likerDoc.data()!;
      debugPrint(
          '🔔 Got liker data: ${likerData['username']} (${likerData['displayName']})');

      // Create notification for the video owner
      final notificationData = {
        'type': 'like',
        'user': {
          'id': likerId,
          'username': likerData['username'] ?? 'Unknown',
          'displayName': likerData['displayName'] ?? 'Unknown',
          'avatarURL': likerData['avatarURL'] ?? likerData['avatarUrl'],
        },
        'videoId': videoId,
        'postThumbnailUrl': postThumbnailUrl,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'status': 'delivered',
      };

      debugPrint(
          '🔔 Creating notification in Firestore: notifications/$videoOwnerId/items');
      await _db
          .collection('notifications')
          .doc(videoOwnerId)
          .collection('items')
          .add(notificationData);

      debugPrint(
          '✅ Like notification created successfully: $likerId -> $videoOwnerId for video $videoId');

      // Send push notification
      await _pushNotificationService.sendNotificationToUser(
        userId: videoOwnerId,
        title: 'New Like',
        body: '${likerData['displayName'] ?? 'Someone'} liked your video',
        type: 'like',
        data: {
          'likerId': likerId,
          'likerUsername': likerData['username'],
          'likerDisplayName': likerData['displayName'],
          'videoId': videoId,
        },
      );
    } catch (e) {
      debugPrint('❌ Error creating like notification: $e');
    }
  }

  Future<void> handleCommentEvent({
    required String commenterId,
    required String videoOwnerId,
    required String videoId,
    required String commentText,
    String? postThumbnailUrl,
  }) async {
    try {
      // Don't create notification if user is commenting on their own video
      if (commenterId == videoOwnerId) return;

      // Get commenter user data
      final commenterDoc = await _db.collection('users').doc(commenterId).get();
      if (!commenterDoc.exists) return;

      final commenterData = commenterDoc.data()!;

      // Create notification for the video owner
      await _db
          .collection('notifications')
          .doc(videoOwnerId)
          .collection('items')
          .add({
        'type': 'comment',
        'user': {
          'id': commenterId,
          'username': commenterData['username'] ?? 'Unknown',
          'displayName': commenterData['displayName'] ?? 'Unknown',
          'avatarURL': commenterData['avatarURL'] ?? commenterData['avatarUrl'],
        },
        'videoId': videoId,
        'commentText': commentText,
        'postThumbnailUrl': postThumbnailUrl,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'status': 'delivered',
      });

      debugPrint(
          '✅ Comment notification created: $commenterId -> $videoOwnerId for video $videoId');

      // Send push notification
      await _pushNotificationService.sendNotificationToUser(
        userId: videoOwnerId,
        title: 'New Comment',
        body:
            '${commenterData['displayName'] ?? 'Someone'} commented: "${commentText.length > 50 ? '${commentText.substring(0, 50)}...' : commentText}"',
        type: 'comment',
        data: {
          'commenterId': commenterId,
          'commenterUsername': commenterData['username'],
          'commenterDisplayName': commenterData['displayName'],
          'videoId': videoId,
          'commentText': commentText,
        },
      );
    } catch (e) {
      debugPrint('❌ Error creating comment notification: $e');
    }
  }

  Future<void> handleTagEvent({
    required String taggerId,
    required String taggedUserId,
    required String videoId,
    String? postThumbnailUrl,
  }) async {
    try {
      // Get tagger user data
      final taggerDoc = await _db.collection('users').doc(taggerId).get();
      if (!taggerDoc.exists) return;

      final taggerData = taggerDoc.data()!;

      // Create notification for the tagged user
      await _db
          .collection('notifications')
          .doc(taggedUserId)
          .collection('items')
          .add({
        'type': 'tag',
        'user': {
          'id': taggerId,
          'username': taggerData['username'] ?? 'Unknown',
          'displayName': taggerData['displayName'] ?? 'Unknown',
          'avatarURL': taggerData['avatarURL'] ?? taggerData['avatarUrl'],
        },
        'videoId': videoId,
        'postThumbnailUrl': postThumbnailUrl,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'status': 'delivered',
      });

      debugPrint(
          '✅ Tag notification created: $taggerId -> $taggedUserId for video $videoId');

      // Send push notification
      await _pushNotificationService.sendNotificationToUser(
        userId: taggedUserId,
        title: 'You Were Tagged',
        body:
            '${taggerData['displayName'] ?? 'Someone'} tagged you in their video',
        type: 'tag',
        data: {
          'taggerId': taggerId,
          'taggerUsername': taggerData['username'],
          'taggerDisplayName': taggerData['displayName'],
          'videoId': videoId,
        },
      );
    } catch (e) {
      debugPrint('❌ Error creating tag notification: $e');
    }
  }

  Future<void> handleMentionEvent({
    required String mentionerId,
    required String mentionedUserId,
    required String videoId,
    String? postThumbnailUrl,
  }) async {
    try {
      // Get mentioner user data
      final mentionerDoc = await _db.collection('users').doc(mentionerId).get();
      if (!mentionerDoc.exists) return;

      final mentionerData = mentionerDoc.data()!;

      // Create notification for the mentioned user
      await _db
          .collection('notifications')
          .doc(mentionedUserId)
          .collection('items')
          .add({
        'type': 'mention',
        'user': {
          'id': mentionerId,
          'username': mentionerData['username'] ?? 'Unknown',
          'displayName': mentionerData['displayName'] ?? 'Unknown',
          'avatarURL': mentionerData['avatarURL'] ?? mentionerData['avatarUrl'],
        },
        'videoId': videoId,
        'postThumbnailUrl': postThumbnailUrl,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'status': 'delivered',
      });

      debugPrint(
          '✅ Mention notification created: $mentionerId -> $mentionedUserId for video $videoId');

      // Send push notification
      await _pushNotificationService.sendNotificationToUser(
        userId: mentionedUserId,
        title: 'You Were Mentioned',
        body:
            '${mentionerData['displayName'] ?? 'Someone'} mentioned you in their video',
        type: 'mention',
        data: {
          'mentionerId': mentionerId,
          'mentionerUsername': mentionerData['username'],
          'mentionerDisplayName': mentionerData['displayName'],
          'videoId': videoId,
        },
      );
    } catch (e) {
      debugPrint('❌ Error creating mention notification: $e');
    }
  }

  Future<void> processBatchNotifications(
      List<Map<String, dynamic>> notifications) async {
    try {
      final batch = _db.batch();

      for (final notification in notifications) {
        final userId = notification['userId'] as String;
        final docRef = _db
            .collection('notifications')
            .doc(userId)
            .collection('items')
            .doc();

        batch.set(docRef, notification);
      }

      await batch.commit();
      debugPrint('✅ Processed batch of ${notifications.length} notifications');
    } catch (e) {
      debugPrint('❌ Error processing batch notifications: $e');
    }
  }
}
