import 'package:cloud_firestore/cloud_firestore.dart';
import 'forum_author.dart';
import 'source_comment.dart';

/// Forum post (thread) model - Regular class (NOT freezed to avoid build_runner)
class ForumPost {
  final String id;
  final String title;
  final String content;

  /// `forumCategories` document id (used for queries).
  final String category;

  /// Resolved label for UI; never show [category] raw in the app.
  final String? categoryDisplayName;
  final List<String> tags;
  final ForumAuthor author;
  final String visibility;
  final int likes;
  final int commentCount;
  final List<String> likedBy;
  final List<String> bookmarkedBy;
  final List<String> followedBy;
  final String? linkedVideoId;
  final String? linkedCommentId;
  final SourceComment? sourceComment;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool deleted;

  ForumPost({
    required this.id,
    required this.title,
    required this.content,
    required this.category,
    this.categoryDisplayName,
    required this.tags,
    required this.author,
    required this.visibility,
    required this.likes,
    required this.commentCount,
    required this.likedBy,
    required this.bookmarkedBy,
    required this.followedBy,
    this.linkedVideoId,
    this.linkedCommentId,
    this.sourceComment,
    required this.createdAt,
    required this.updatedAt,
    required this.deleted,
  });

  factory ForumPost.fromFirestore(DocumentSnapshot doc) {
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

    return ForumPost(
      id: doc.id,
      title: data['title'] as String,
      content: data['content'] as String,
      category: data['category'] as String? ?? '',
      categoryDisplayName: data['categoryName'] as String?,
      tags: List<String>.from(data['tags'] ?? []),
      author: ForumAuthor.fromMap(rawAuthorMap),
      visibility: data['visibility'] as String? ?? 'public',
      likes: data['likes'] as int? ?? 0,
      commentCount: data['commentCount'] as int? ?? 0,
      likedBy: List<String>.from(data['likedBy'] ?? []),
      bookmarkedBy: List<String>.from(data['bookmarkedBy'] ?? []),
      followedBy: List<String>.from(data['followedBy'] ?? []),
      linkedVideoId: data['linkedVideoId'] as String?,
      linkedCommentId: data['linkedCommentId'] as String?,
      sourceComment: data['sourceComment'] != null
          ? SourceComment.fromMap(data['sourceComment'] as Map<String, dynamic>)
          : null,
      createdAt: createdAtValue is Timestamp
          ? createdAtValue.toDate()
          : DateTime.now(),
      updatedAt: updatedAtValue is Timestamp
          ? updatedAtValue.toDate()
          : DateTime.now(),
      deleted: data['deleted'] as bool? ?? false,
    );
  }
}
