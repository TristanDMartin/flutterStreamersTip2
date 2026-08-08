import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'notification_service.dart';

class EventTriggerService extends ChangeNotifier {
  // Lazy initialization for Firestore to prevent iOS cold start crashes
  FirebaseFirestore? _db;

  FirebaseFirestore get _dbInstance {
    if (_db == null) {
      try {
        if (Firebase.apps.isEmpty) {
          debugPrint('⚠️ EventTriggerService: Firebase not initialized yet');
          throw Exception('Firebase not initialized');
        }
        _db = FirebaseFirestore.instance;
      } catch (e) {
        debugPrint('❌ EventTriggerService: Error accessing Firestore: $e');
        rethrow;
      }
    }
    return _db!;
  }

  NotificationService? _notificationService;

  void setNotificationService(NotificationService notificationService) {
    _notificationService = notificationService;
  }

  // MARK: - Follow Event Triggers

  Future<void> triggerFollowEvent({
    required String followerId,
    required String followingId,
  }) async {
    // Note: FollowsService already handles database updates (follow relationship
    // and counters). Activity notifications are server-only — Cloud Function
    // onFollowCreate owns that write, so this is a no-op today.
  }

  Future<void> triggerUnfollowEvent({
    required String followerId,
    required String followingId,
  }) async {
    // appLog("🔄 EventTriggerService: Unfollow event triggered - $followerId -> $followingId");

    // Update follower count
    await _updateFollowerCount(followingId, -1);

    // Remove relationship from Firestore
    await _removeRelationship(followerId: followerId, followingId: followingId);
  }

  // MARK: - Like Event Triggers

  Future<void> triggerLikeEvent({
    required String likerId,
    required String videoId,
    required String videoOwnerId,
    String? postThumbnailUrl,
  }) async {
    debugPrint(
        "🔄 EventTriggerService: Like event triggered - $likerId -> $videoId");

    // Update like count
    await _updateLikeCount(videoId, 1);

    // Activity notifications are server-only — Cloud Function onLikeCreate
    // owns that write from likes/{videoId}/byUser/{userId}.

    // Store like in Firestore
    await _createLike(likerId: likerId, videoId: videoId);
  }

  Future<void> triggerUnlikeEvent({
    required String likerId,
    required String videoId,
    required String videoOwnerId,
  }) async {
    // appLog("🔄 EventTriggerService: Unlike event triggered - $likerId -> $videoId");

    // Update like count
    await _updateLikeCount(videoId, -1);

    // Remove like from Firestore
    await _removeLike(likerId: likerId, videoId: videoId);
  }

  // MARK: - Comment Event Triggers

  Future<void> triggerCommentEvent({
    required String commenterId,
    required String videoId,
    required String videoOwnerId,
    required String commentText,
    String? postThumbnailUrl,
  }) async {
    debugPrint(
        "🔄 EventTriggerService: Comment event triggered - $commenterId -> $videoId");

    // Update comment count
    await _updateCommentCount(videoId, 1);

    // Activity notifications are server-only — Cloud Function onCommentCreate
    // owns that write from videos/{videoId}/comments/{commentId}.

    // Store comment in Firestore
    await _createComment(
      commenterId: commenterId,
      videoId: videoId,
      commentText: commentText,
    );
  }

  Future<void> triggerCommentDeleteEvent({
    required String videoId,
  }) async {
    debugPrint(
        "🔄 EventTriggerService: Comment delete event triggered for video $videoId");

    // Decrement comment count
    await _updateCommentCount(videoId, -1);

    debugPrint("✅ Comment count decremented for video $videoId");
  }

  // MARK: - Tag Event Triggers

  Future<void> triggerTagEvent({
    required String taggerId,
    required String taggedUserId,
    required String videoId,
    String? postThumbnailUrl,
  }) async {
    debugPrint(
        "🔄 EventTriggerService: Tag event triggered - $taggerId -> $taggedUserId");

    // Activity notifications are server-only — Cloud Function onTagCreate
    // owns that write from tags/{tagId}.

    // Store tag in Firestore
    await _createTag(
      taggerId: taggerId,
      taggedUserId: taggedUserId,
      videoId: videoId,
    );
  }

  // MARK: - Mention Event Triggers

  Future<void> triggerMentionEvent({
    required String mentionerId,
    required String mentionedUserId,
    required String videoId,
    String? postThumbnailUrl,
  }) async {
    debugPrint(
        "🔄 EventTriggerService: Mention event triggered - $mentionerId -> $mentionedUserId");

    // Activity notifications are server-only — Cloud Function onMentionCreate
    // owns that write from mentions/{mentionId}.

    // Store mention in Firestore
    await _createMention(
      mentionerId: mentionerId,
      mentionedUserId: mentionedUserId,
      videoId: videoId,
    );
  }

  // MARK: - Batch Event Processing

  Future<void> processBatchEvents(List<EventData> events) async {
    // appLog("🔄 EventTriggerService: Processing batch of ${events.length} events");

    final notifications = <Map<String, dynamic>>[];

    for (final event in events) {
      switch (event.type) {
        case EventType.follow:
          await _updateFollowerCount(event.targetUserId, 1);
          await _createRelationship(
              followerId: event.senderId, followingId: event.targetUserId);

          notifications.add({
            "type": "follow",
            "senderId": event.senderId,
            "userId": event.targetUserId,
            "timestamp": FieldValue.serverTimestamp(),
            "isRead": false,
            "status": "pending",
            "retryCount": 0,
          });

        case EventType.like:
          await _updateLikeCount(event.videoId!, 1);
          await _createLike(likerId: event.senderId, videoId: event.videoId!);

          notifications.add({
            "type": "like",
            "senderId": event.senderId,
            "userId": event.targetUserId,
            "videoId": event.videoId!,
            "postThumbnailUrl": event.postThumbnailUrl,
            "timestamp": FieldValue.serverTimestamp(),
            "isRead": false,
            "status": "pending",
            "retryCount": 0,
          });

        case EventType.comment:
          await _updateCommentCount(event.videoId!, 1);
          await _createComment(
            commenterId: event.senderId,
            videoId: event.videoId!,
            commentText: event.commentText!,
          );

          notifications.add({
            "type": "comment",
            "senderId": event.senderId,
            "userId": event.targetUserId,
            "videoId": event.videoId!,
            "commentText": event.commentText!,
            "postThumbnailUrl": event.postThumbnailUrl,
            "timestamp": FieldValue.serverTimestamp(),
            "isRead": false,
            "status": "pending",
            "retryCount": 0,
          });

        case EventType.tag:
          await _createTag(
            taggerId: event.senderId,
            taggedUserId: event.targetUserId,
            videoId: event.videoId!,
          );

          notifications.add({
            "type": "tag",
            "senderId": event.senderId,
            "userId": event.targetUserId,
            "videoId": event.videoId!,
            "postThumbnailUrl": event.postThumbnailUrl,
            "timestamp": FieldValue.serverTimestamp(),
            "isRead": false,
            "status": "pending",
            "retryCount": 0,
          });
      }
    }

    // Process notifications in batch
    await _notificationService?.processBatchNotifications(notifications);

    // appLog("✅ EventTriggerService: Batch processing completed");
  }

  // MARK: - Firestore Operations

  Future<void> _updateFollowerCount(String userId, int increment) async {
    try {
      await _dbInstance.collection("users").doc(userId).update({
        "followerCount": FieldValue.increment(increment),
      });
      // appLog("✅ Updated follower count for user: $userId");
    } catch (e) {
      // appLog("❌ Error updating follower count: $e");
    }
  }

  Future<void> _updateLikeCount(String videoId, int increment) async {
    try {
      await _dbInstance.collection("videos").doc(videoId).update({
        "likeCount": FieldValue.increment(increment),
      });
      // appLog("✅ Updated like count for video: $videoId");
    } catch (e) {
      // appLog("❌ Error updating like count: $e");
    }
  }

  Future<void> _updateCommentCount(String videoId, int increment) async {
    try {
      await _dbInstance.collection("videos").doc(videoId).update({
        "comments": FieldValue.increment(
            increment), // Fixed: Use 'comments' to match listener
      });
      // appLog("✅ Updated comment count for video: $videoId");
    } catch (e) {
      // appLog("❌ Error updating comment count: $e");
    }
  }

  Future<void> _createRelationship({
    required String followerId,
    required String followingId,
  }) async {
    try {
      await _dbInstance.collection("relationships").add({
        "followerId": followerId,
        "followingId": followingId,
        "timestamp": FieldValue.serverTimestamp(),
      });
      // appLog("✅ Created relationship: $followerId -> $followingId");
    } catch (e) {
      // appLog("❌ Error creating relationship: $e");
    }
  }

  Future<void> _removeRelationship({
    required String followerId,
    required String followingId,
  }) async {
    try {
      final snapshot = await _dbInstance
          .collection("relationships")
          .where("followerId", isEqualTo: followerId)
          .where("followingId", isEqualTo: followingId)
          .get();

      for (final document in snapshot.docs) {
        await document.reference.delete();
      }
      // appLog("✅ Removed relationship: $followerId -> $followingId");
    } catch (e) {
      // appLog("❌ Error removing relationship: $e");
    }
  }

  Future<void> _createLike({
    required String likerId,
    required String videoId,
  }) async {
    try {
      await _dbInstance.collection("likes").add({
        "likerId": likerId,
        "videoId": videoId,
        "timestamp": FieldValue.serverTimestamp(),
      });
      // appLog("✅ Created like: $likerId -> $videoId");
    } catch (e) {
      // appLog("❌ Error creating like: $e");
    }
  }

  Future<void> _removeLike({
    required String likerId,
    required String videoId,
  }) async {
    try {
      final snapshot = await _dbInstance
          .collection("likes")
          .where("likerId", isEqualTo: likerId)
          .where("videoId", isEqualTo: videoId)
          .get();

      for (final document in snapshot.docs) {
        await document.reference.delete();
      }
      // appLog("✅ Removed like: $likerId -> $videoId");
    } catch (e) {
      // appLog("❌ Error removing like: $e");
    }
  }

  Future<void> _createComment({
    required String commenterId,
    required String videoId,
    required String commentText,
  }) async {
    try {
      await _dbInstance.collection("comments").add({
        "commenterId": commenterId,
        "videoId": videoId,
        "commentText": commentText,
        "timestamp": FieldValue.serverTimestamp(),
      });
      // appLog("✅ Created comment: $commenterId -> $videoId");
    } catch (e) {
      // appLog("❌ Error creating comment: $e");
    }
  }

  Future<void> _createTag({
    required String taggerId,
    required String taggedUserId,
    required String videoId,
  }) async {
    try {
      await _dbInstance.collection("tags").add({
        "taggerId": taggerId,
        "taggedUserId": taggedUserId,
        "videoId": videoId,
        "timestamp": FieldValue.serverTimestamp(),
      });
      // appLog("✅ Created tag: $taggerId -> $taggedUserId");
    } catch (e) {
      // appLog("❌ Error creating tag: $e");
    }
  }

  Future<void> _createMention({
    required String mentionerId,
    required String mentionedUserId,
    required String videoId,
  }) async {
    try {
      await _dbInstance.collection("mentions").add({
        "mentionerId": mentionerId,
        "mentionedUserId": mentionedUserId,
        "videoId": videoId,
        "timestamp": FieldValue.serverTimestamp(),
      });
      // appLog("✅ Created mention: $mentionerId -> $mentionedUserId");
    } catch (e) {
      // appLog("❌ Error creating mention: $e");
    }
  }
}

// MARK: - Event Data Models

enum EventType {
  follow,
  like,
  comment,
  tag,
}

class EventData {
  final EventType type;
  final String senderId;
  final String targetUserId;
  final String? videoId;
  final String? commentText;
  final String? postThumbnailUrl;

  const EventData({
    required this.type,
    required this.senderId,
    required this.targetUserId,
    this.videoId,
    this.commentText,
    this.postThumbnailUrl,
  });
}
