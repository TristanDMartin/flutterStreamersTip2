import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'notification_service.dart';

class EventTriggerService extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  NotificationService? _notificationService;
  
  void setNotificationService(NotificationService notificationService) {
    _notificationService = notificationService;
  }
  
  // MARK: - Follow Event Triggers
  
  Future<void> triggerFollowEvent({
    required String followerId,
    required String followingId,
  }) async {
    // print("🔄 EventTriggerService: Follow event triggered - $followerId -> $followingId");
    
    // Update follower count
    await _updateFollowerCount(followingId, 1);
    
    // Create notification
    await _notificationService?.handleFollowEvent(
      followerId: followerId,
      followingId: followingId,
    );
    
    // Update relationship in Firestore
    await _createRelationship(followerId: followerId, followingId: followingId);
  }
  
  Future<void> triggerUnfollowEvent({
    required String followerId,
    required String followingId,
  }) async {
    // print("🔄 EventTriggerService: Unfollow event triggered - $followerId -> $followingId");
    
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
    // print("🔄 EventTriggerService: Like event triggered - $likerId -> $videoId");
    
    // Update like count
    await _updateLikeCount(videoId, 1);
    
    // Create notification
    await _notificationService?.handleLikeEvent(
      likerId: likerId,
      videoOwnerId: videoOwnerId,
      videoId: videoId,
      postThumbnailUrl: postThumbnailUrl,
    );
    
    // Store like in Firestore
    await _createLike(likerId: likerId, videoId: videoId);
  }
  
  Future<void> triggerUnlikeEvent({
    required String likerId,
    required String videoId,
    required String videoOwnerId,
  }) async {
    // print("🔄 EventTriggerService: Unlike event triggered - $likerId -> $videoId");
    
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
    // print("🔄 EventTriggerService: Comment event triggered - $commenterId -> $videoId");
    
    // Update comment count
    await _updateCommentCount(videoId, 1);
    
    // Create notification
    await _notificationService?.handleCommentEvent(
      commenterId: commenterId,
      videoOwnerId: videoOwnerId,
      videoId: videoId,
      commentText: commentText,
      postThumbnailUrl: postThumbnailUrl,
    );
    
    // Store comment in Firestore
    await _createComment(
      commenterId: commenterId,
      videoId: videoId,
      commentText: commentText,
    );
  }
  
  // MARK: - Tag Event Triggers
  
  Future<void> triggerTagEvent({
    required String taggerId,
    required String taggedUserId,
    required String videoId,
    String? postThumbnailUrl,
  }) async {
    // print("🔄 EventTriggerService: Tag event triggered - $taggerId -> $taggedUserId");
    
    // Create notification
    await _notificationService?.handleTagEvent(
      taggerId: taggerId,
      taggedUserId: taggedUserId,
      videoId: videoId,
      postThumbnailUrl: postThumbnailUrl,
    );
    
    // Store tag in Firestore
    await _createTag(
      taggerId: taggerId,
      taggedUserId: taggedUserId,
      videoId: videoId,
    );
  }
  
  // MARK: - Batch Event Processing
  
  Future<void> processBatchEvents(List<EventData> events) async {
    // print("🔄 EventTriggerService: Processing batch of ${events.length} events");
    
    final notifications = <Map<String, dynamic>>[];
    
    for (final event in events) {
      switch (event.type) {
        case EventType.follow:
          await _updateFollowerCount(event.targetUserId, 1);
          await _createRelationship(followerId: event.senderId, followingId: event.targetUserId);
          
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
    
    // print("✅ EventTriggerService: Batch processing completed");
  }
  
  // MARK: - Firestore Operations
  
  Future<void> _updateFollowerCount(String userId, int increment) async {
    try {
      await _db.collection("users").doc(userId).update({
        "followerCount": FieldValue.increment(increment),
      });
    // print("✅ Updated follower count for user: $userId");
    } catch (e) {
    // print("❌ Error updating follower count: $e");
    }
  }
  
  Future<void> _updateLikeCount(String videoId, int increment) async {
    try {
      await _db.collection("videos").doc(videoId).update({
        "likeCount": FieldValue.increment(increment),
      });
    // print("✅ Updated like count for video: $videoId");
    } catch (e) {
    // print("❌ Error updating like count: $e");
    }
  }
  
  Future<void> _updateCommentCount(String videoId, int increment) async {
    try {
      await _db.collection("videos").doc(videoId).update({
        "commentCount": FieldValue.increment(increment),
      });
    // print("✅ Updated comment count for video: $videoId");
    } catch (e) {
    // print("❌ Error updating comment count: $e");
    }
  }
  
  Future<void> _createRelationship({
    required String followerId,
    required String followingId,
  }) async {
    try {
      await _db.collection("relationships").add({
        "followerId": followerId,
        "followingId": followingId,
        "timestamp": FieldValue.serverTimestamp(),
      });
    // print("✅ Created relationship: $followerId -> $followingId");
    } catch (e) {
    // print("❌ Error creating relationship: $e");
    }
  }
  
  Future<void> _removeRelationship({
    required String followerId,
    required String followingId,
  }) async {
    try {
      final snapshot = await _db
          .collection("relationships")
          .where("followerId", isEqualTo: followerId)
          .where("followingId", isEqualTo: followingId)
          .get();
      
      for (final document in snapshot.docs) {
        await document.reference.delete();
      }
    // print("✅ Removed relationship: $followerId -> $followingId");
    } catch (e) {
    // print("❌ Error removing relationship: $e");
    }
  }
  
  Future<void> _createLike({
    required String likerId,
    required String videoId,
  }) async {
    try {
      await _db.collection("likes").add({
        "likerId": likerId,
        "videoId": videoId,
        "timestamp": FieldValue.serverTimestamp(),
      });
    // print("✅ Created like: $likerId -> $videoId");
    } catch (e) {
    // print("❌ Error creating like: $e");
    }
  }
  
  Future<void> _removeLike({
    required String likerId,
    required String videoId,
  }) async {
    try {
      final snapshot = await _db
          .collection("likes")
          .where("likerId", isEqualTo: likerId)
          .where("videoId", isEqualTo: videoId)
          .get();
      
      for (final document in snapshot.docs) {
        await document.reference.delete();
      }
    // print("✅ Removed like: $likerId -> $videoId");
    } catch (e) {
    // print("❌ Error removing like: $e");
    }
  }
  
  Future<void> _createComment({
    required String commenterId,
    required String videoId,
    required String commentText,
  }) async {
    try {
      await _db.collection("comments").add({
        "commenterId": commenterId,
        "videoId": videoId,
        "commentText": commentText,
        "timestamp": FieldValue.serverTimestamp(),
      });
    // print("✅ Created comment: $commenterId -> $videoId");
    } catch (e) {
    // print("❌ Error creating comment: $e");
    }
  }
  
  Future<void> _createTag({
    required String taggerId,
    required String taggedUserId,
    required String videoId,
  }) async {
    try {
      await _db.collection("tags").add({
        "taggerId": taggerId,
        "taggedUserId": taggedUserId,
        "videoId": videoId,
        "timestamp": FieldValue.serverTimestamp(),
      });
    // print("✅ Created tag: $taggerId -> $taggedUserId");
    } catch (e) {
    // print("❌ Error creating tag: $e");
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
