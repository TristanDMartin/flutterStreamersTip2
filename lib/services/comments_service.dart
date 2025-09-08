import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import '../models/comment.dart';
import '../models/user.dart' as app_user;

class CommentsService {
  static final CommentsService _instance = CommentsService._internal();
  factory CommentsService() => _instance;
  CommentsService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final firebase_auth.FirebaseAuth _auth = firebase_auth.FirebaseAuth.instance;

  /// Fetch comments for a video
  Future<List<Comment>> fetchCommentsForVideo(String videoId) async {
    try {
      final snapshot = await _firestore
          .collection('videos')
          .doc(videoId)
          .collection('comments')
          .orderBy('timestamp', descending: true)
          .limit(50)
          .get();

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
      print('Error fetching comments: $e');
      return CommentMockData.mockData(); // Fallback to mock data
    }
  }

  /// Add a comment to a video
  Future<Comment> addComment({
    required String videoId,
    required String text,
    required app_user.User author,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw Exception('User not authenticated');

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

      return comment.copyWith(id: docRef.id);
    } catch (e) {
      print('Error adding comment: $e');
      rethrow;
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

      return reply.copyWith(id: 'reply-${DateTime.now().millisecondsSinceEpoch}');
    } catch (e) {
      print('Error adding reply: $e');
      rethrow;
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
      print('Error toggling like: $e');
      return false;
    }
  }

  /// Delete a comment
  Future<bool> deleteComment({
    required String videoId,
    required String commentId,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return false;

      await _firestore
          .collection('videos')
          .doc(videoId)
          .collection('comments')
          .doc(commentId)
          .delete();

      return true;
    } catch (e) {
      print('Error deleting comment: $e');
      return false;
    }
  }

  /// Search comments
  Future<List<Comment>> searchComments({
    required String videoId,
    required String query,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('videos')
          .doc(videoId)
          .collection('comments')
          .where('text', isGreaterThanOrEqualTo: query)
          .where('text', isLessThan: query + 'z')
          .get();

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
      print('Error searching comments: $e');
      return [];
    }
  }
}
