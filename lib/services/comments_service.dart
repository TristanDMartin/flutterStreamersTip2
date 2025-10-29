import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/foundation.dart';
import '../models/comment.dart';
import '../models/user.dart' as app_user;
import 'event_trigger_service.dart';

class CommentsService {
  static final CommentsService _instance = CommentsService._internal();
  factory CommentsService() => _instance;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final firebase_auth.FirebaseAuth _auth = firebase_auth.FirebaseAuth.instance;
  EventTriggerService? _eventTriggerService;

  CommentsService._internal();

  /// Set the EventTriggerService instance (should be called from provider)
  void setEventTriggerService(EventTriggerService eventTriggerService) {
    _eventTriggerService = eventTriggerService;
  }

  /// Resync comment counter with actual comment count in subcollection
  /// This is useful if the counter got out of sync due to manual deletions
  Future<void> resyncCommentCounter(String videoId) async {
    try {
      debugPrint('🔄 Resyncing comment counter for video: $videoId');

      // Get actual count from subcollection
      final commentsSnapshot = await _firestore
          .collection('videos')
          .doc(videoId)
          .collection('comments')
          .get();

      final actualCount = commentsSnapshot.docs.length;

      // Update the video document's comments field
      await _firestore.collection('videos').doc(videoId).update({
        'comments': actualCount,
      });

      debugPrint(
          '✅ Comment counter resynced for video $videoId: $actualCount comments');
    } catch (e) {
      debugPrint('❌ Error resyncing comment counter for $videoId: $e');
    }
  }

  /// Fetch comments for a video
  Future<List<Comment>> fetchCommentsForVideo(String videoId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        // print('User not authenticated, returning mock data');
        return CommentMockData.mockData();
      }

      final snapshot = await _firestore
          .collection('videos')
          .doc(videoId)
          .collection('comments')
          .orderBy('timestamp', descending: true)
          .limit(50)
          .get();

      if (snapshot.docs.isEmpty) {
        // print('No comments found for video $videoId, returning mock data');
        return CommentMockData.mockData();
      }

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return Comment(
          id: doc.id,
          user: app_user.User.fromMap(data['user']),
          text: data['text'] ?? '',
          timestamp: (data['timestamp'] as Timestamp).toDate(),
          likeCount: data['likeCount'] ?? 0,
          isLiked: data['isLiked'] ?? false,
          replies: (data['replies'] as List<dynamic>?)
              ?.map((reply) => Comment.fromJson(reply))
              .toList(),
        );
      }).toList();
    } catch (e) {
      // print('Error fetching comments: $e');
      // Return mock data as fallback for better UX
      return CommentMockData.mockData();
    }
  }

  /// Add a comment to a video
  Future<Comment> addComment({
    required String videoId,
    required String text,
    required app_user.User author,
  }) async {
    debugPrint('🔔 CommentsService.addComment called: $videoId');
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw Exception('User not authenticated');

      debugPrint('🔔 CommentsService: Current user: ${currentUser.uid}');

      final comment = Comment(
        id: '', // Will be set by Firestore
        user: author,
        text: text,
        timestamp: DateTime.now(),
        likeCount: 0,
        isLiked: false,
        replies: [],
      );

      final docRef = await _firestore
          .collection('videos')
          .doc(videoId)
          .collection('comments')
          .add(comment.toJson());

      final commentWithId = comment.copyWith(id: docRef.id);

      // Trigger comment event for notifications
      await _triggerCommentEvent(videoId, currentUser.uid, text);

      return commentWithId;
    } catch (e) {
      // print('Error adding comment: $e');
      // Provide more specific error messages
      if (e.toString().contains('permission-denied')) {
        throw Exception(
            'Permission denied. Please check your authentication status.');
      } else if (e.toString().contains('network')) {
        throw Exception('Network error. Please check your connection.');
      } else {
        throw Exception('Failed to add comment. Please try again.');
      }
    }
  }

  /// Add a reply to a comment
  Future<Comment> addReply({
    required String videoId,
    required String parentId,
    required String text,
    required app_user.User author,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw Exception('User not authenticated');

      final reply = Comment(
        id: '', // Will be set by Firestore
        user: author,
        text: text,
        timestamp: DateTime.now(),
        likeCount: 0,
        isLiked: false,
        replies: [],
      );

      final parentRef = _firestore
          .collection('videos')
          .doc(videoId)
          .collection('comments')
          .doc(parentId);

      await parentRef.update({
        'replies': FieldValue.arrayUnion([reply.toJson()]),
      });

      return reply.copyWith(
          id: 'reply-${DateTime.now().millisecondsSinceEpoch}');
    } catch (e) {
      // print('Error adding reply: $e');
      // Provide more specific error messages
      if (e.toString().contains('permission-denied')) {
        throw Exception(
            'Permission denied. Please check your authentication status.');
      } else if (e.toString().contains('network')) {
        throw Exception('Network error. Please check your connection.');
      } else {
        throw Exception('Failed to add reply. Please try again.');
      }
    }
  }

  /// Toggle like on a comment
  Future<bool> toggleLike({
    required String videoId,
    required String commentId,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return false;

      final commentRef = _firestore
          .collection('videos')
          .doc(videoId)
          .collection('comments')
          .doc(commentId);

      final doc = await commentRef.get();
      if (!doc.exists) return false;

      final data = doc.data()!;
      final isLiked = data['isLiked'] ?? false;
      final likeCount = data['likeCount'] ?? 0;

      await commentRef.update({
        'isLiked': !isLiked,
        'likeCount': isLiked ? likeCount - 1 : likeCount + 1,
      });

      return true;
    } catch (e) {
      // print('Error toggling like: $e');
      return false;
    }
  }

  /// Delete a comment with permission checking
  Future<bool> deleteComment({
    required String videoId,
    required String commentId,
    String? videoOwnerId,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return false;

      // Get the comment to check permissions
      final commentDoc = await _firestore
          .collection('videos')
          .doc(videoId)
          .collection('comments')
          .doc(commentId)
          .get();

      if (!commentDoc.exists) return false;

      final commentData = commentDoc.data()!;
      final commentAuthorId = commentData['user']?['id'];

      // Check if current user can delete this comment
      bool canDelete = false;

      // Comment author can delete their own comment
      if (commentAuthorId == currentUser.uid) {
        canDelete = true;
      }

      // Video owner can delete any comment on their video
      if (videoOwnerId != null && videoOwnerId == currentUser.uid) {
        canDelete = true;
      }

      if (!canDelete) {
        throw CommentError.unauthorized;
      }

      // Delete the comment
      await _firestore
          .collection('videos')
          .doc(videoId)
          .collection('comments')
          .doc(commentId)
          .delete();

      // Trigger comment delete event to decrement counter
      await _eventTriggerService?.triggerCommentDeleteEvent(
        videoId: videoId,
      );

      return true;
    } catch (e) {
      if (e is CommentError) {
        rethrow;
      }
      // print('Error deleting comment: $e');
      return false;
    }
  }

  /// Trigger comment event for notifications
  Future<void> _triggerCommentEvent(
      String videoId, String commenterId, String commentText) async {
    try {
      debugPrint(
          '🔔 CommentsService._triggerCommentEvent called: $commenterId -> $videoId');

      if (_eventTriggerService == null) {
        debugPrint('🔔 EventTriggerService not set - skipping notification');
        return;
      }

      // Get video owner ID
      final videoDoc = await _firestore.collection('videos').doc(videoId).get();
      if (!videoDoc.exists) {
        debugPrint('🔔 Video document not found: $videoId');
        return;
      }

      final videoData = videoDoc.data()!;
      final videoOwnerId = videoData['userId'] as String?;

      if (videoOwnerId != null) {
        debugPrint(
            '🔔 Triggering comment event: $commenterId -> $videoOwnerId for video $videoId');
        await _eventTriggerService!.triggerCommentEvent(
          commenterId: commenterId,
          videoId: videoId,
          videoOwnerId: videoOwnerId,
          commentText: commentText,
          postThumbnailUrl: videoData['thumbnailUrl'] as String?,
        );
        debugPrint('✅ Comment event triggered successfully');
      } else {
        debugPrint('🔔 Video owner ID not found in video data');
      }
    } catch (e) {
      debugPrint('❌ Error triggering comment event: $e');
    }
  }
}
