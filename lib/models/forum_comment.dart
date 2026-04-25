import 'package:cloud_firestore/cloud_firestore.dart';
import 'forum_author.dart';

/// Forum comment model (comments within threads) - Regular class
class ForumComment {
  final String id;
  final String postId;
  final String content;
  final ForumAuthor author;
  final String? parentCommentId; // null for top-level comments
  final String? quotedCommentId;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final int likes;
  final int dislikes;
  final List<String> likedBy;
  final List<String> dislikedBy;
  final int replyCount;
  final bool deleted;
  final String? role; // 'creator' | 'mod' | 'member'

  ForumComment({
    required this.id,
    required this.postId,
    required this.content,
    required this.author,
    this.parentCommentId,
    this.quotedCommentId,
    required this.createdAt,
    this.updatedAt,
    this.likes = 0,
    this.dislikes = 0,
    this.likedBy = const [],
    this.dislikedBy = const [],
    this.replyCount = 0,
    this.deleted = false,
    this.role,
  });

  factory ForumComment.fromFirestore(DocumentSnapshot doc, String postId) {
    final data = doc.data() as Map<String, dynamic>;
    final createdAtValue = data['createdAt'];
    final updatedAtValue = data['updatedAt'];
    final rawAuthorMap = Map<String, dynamic>.from(
      (data['author'] as Map<String, dynamic>?) ?? const <String, dynamic>{},
    );
    final authorId = data['authorId'] as String?;
    if (authorId != null && authorId.isNotEmpty) {
      rawAuthorMap.putIfAbsent('uid', () => authorId);
      rawAuthorMap.putIfAbsent('id', () => authorId);
    }

    return ForumComment(
      id: doc.id,
      postId: postId,
      content: data['content'] as String? ?? '[deleted]',
      author: ForumAuthor.fromMap(rawAuthorMap),
      parentCommentId: data['parentCommentId'] as String?,
      quotedCommentId: data['quotedCommentId'] as String?,
      createdAt: createdAtValue is Timestamp
          ? createdAtValue.toDate()
          : DateTime.now(),
      updatedAt: updatedAtValue is Timestamp ? updatedAtValue.toDate() : null,
      likes: data['likes'] as int? ?? 0,
      dislikes: data['dislikes'] as int? ?? 0,
      likedBy: List<String>.from(data['likedBy'] ?? []),
      dislikedBy: List<String>.from(data['dislikedBy'] ?? []),
      replyCount: data['replyCount'] as int? ?? 0,
      deleted: data['deleted'] as bool? ?? false,
      role: data['role'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'postId': postId,
      'content': content,
      'author': author.toMap(),
      'parentCommentId': parentCommentId,
      'quotedCommentId': quotedCommentId,
      'likes': likes,
      'likedBy': likedBy,
      'dislikes': dislikes,
      'dislikedBy': dislikedBy,
      'replyCount': replyCount,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'deleted': deleted,
      'role': role,
    };
  }
}
