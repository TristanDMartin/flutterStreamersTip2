import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/foundation.dart';
import '../models/forum_post.dart';
import '../models/forum_comment.dart';
import '../models/forum_category.dart';
import '../models/forum_author.dart';
import 'discussion_author_service.dart';

/// Thread sort options
enum ThreadSortBy {
  recent,
  popular,
  trending,
  activeNow,
  new_,
}

/// Forum service for managing threads and thread comments
/// Uses regular classes (NOT freezed) to avoid build_runner issues
class ForumService {
  static final ForumService _instance = ForumService._internal();
  factory ForumService() => _instance;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final firebase_auth.FirebaseAuth _auth = firebase_auth.FirebaseAuth.instance;
  final DiscussionAuthorService _discussionAuthorService =
      DiscussionAuthorService();

  ForumService._internal();

  /// Get threads with filters
  Future<List<ForumPost>> getPosts({
    String? categoryId,
    String? searchQuery,
    ThreadSortBy sortBy = ThreadSortBy.recent,
    int pageSize = 10,
    DocumentSnapshot? startAfterDoc,
    String? currentUserId,
  }) async {
    try {
      Query query = _firestore
          .collection('forumPosts')
          .where('deleted', isEqualTo: false);

      if (categoryId != null && categoryId.isNotEmpty) {
        query = query.where('category', isEqualTo: categoryId);
      }

      switch (sortBy) {
        case ThreadSortBy.recent:
          query = query.orderBy('createdAt', descending: true);
          break;
        case ThreadSortBy.popular:
          query = query.orderBy('likes', descending: true);
          break;
        case ThreadSortBy.trending:
          query = query.orderBy('createdAt', descending: true);
          break;
        case ThreadSortBy.activeNow:
          query = query.orderBy('updatedAt', descending: true);
          break;
        case ThreadSortBy.new_:
          query = query.orderBy('createdAt', descending: true);
          break;
      }

      if (startAfterDoc != null) {
        query = query.startAfterDocument(startAfterDoc);
      }

      query = query.limit(pageSize);

      final snapshot = await query.get();
      final posts =
          snapshot.docs.map((doc) => ForumPost.fromFirestore(doc)).toList();

      // TEMPORARILY DISABLED: Avatar enrichment causes memory issues
      // TODO: Re-enable with proper caching and pagination
      // final enrichedPosts = await _enrichPostsWithUserAvatars(posts);
      final enrichedPosts = posts;

      // Apply search query filter if provided
      if (searchQuery != null && searchQuery.isNotEmpty) {
        final lowerQuery = searchQuery.toLowerCase();
        return enrichedPosts.where((post) {
          return post.title.toLowerCase().contains(lowerQuery) ||
              post.content.toLowerCase().contains(lowerQuery) ||
              post.tags.any((tag) => tag.toLowerCase().contains(lowerQuery));
        }).toList();
      }

      return enrichedPosts;
    } catch (e) {
      debugPrint('❌ Error fetching threads: $e');
      rethrow;
    }
  }

  /// Get thread details
  Future<ForumPost?> getPost(String postId) async {
    try {
      final doc = await _firestore.collection('forumPosts').doc(postId).get();
      if (!doc.exists || (doc.data()?['deleted'] as bool? ?? false)) {
        return null;
      }
      return ForumPost.fromFirestore(doc);
    } catch (e) {
      debugPrint('❌ Error fetching thread: $e');
      rethrow;
    }
  }

  /// Create thread
  Future<String> createPost({
    required String title,
    required String content,
    required String categoryId,
    required List<String> tags,
    required ForumAuthor author,
    String visibility = 'public',
  }) async {
    try {
      final docRef = await _firestore.collection('forumPosts').add({
        'title': title,
        'content': content,
        'category': categoryId,
        'tags': tags,
        'authorId': author.uid,
        'author': {
          'uid': author.uid,
          'username': author.username,
          'displayName': author.displayName,
          'avatarUrl': author.avatarUrl,
        },
        'visibility': visibility,
        'likes': 0,
        'commentCount': 0,
        'likedBy': [],
        'bookmarkedBy': [],
        'followedBy': [],
        'contentType': 'text',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'deleted': false,
      });

      // Update category post count
      await _firestore.collection('forumCategories').doc(categoryId).update({
        'postCount': FieldValue.increment(1),
      });

      debugPrint('✅ Thread created: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      debugPrint('❌ Error creating thread: $e');
      rethrow;
    }
  }

  /// Create thread from comment
  Future<String> createThreadFromComment({
    required String threadTitle,
    required String commentText,
    required Map<String, dynamic> commentAuthor,
    required ForumAuthor threadAuthor,
    required String videoId,
    required String commentId,
    required String categoryId,
    required List<String> tags,
    String visibility = 'public',
  }) async {
    try {
      final allTags = ['from-video-comment', ...tags];

      final docRef = await _firestore.collection('forumPosts').add({
        'title': threadTitle,
        'content': commentText,
        'category': categoryId,
        'tags': allTags,
        'authorId': threadAuthor.uid,
        'author': {
          'uid': threadAuthor.uid,
          'username': threadAuthor.username,
          'displayName': threadAuthor.displayName,
          'avatarUrl': threadAuthor.avatarUrl,
        },
        'visibility': visibility,
        'likes': 0,
        'commentCount': 0,
        'likedBy': [],
        'bookmarkedBy': [],
        'followedBy': [],
        'linkedVideoId': videoId,
        'linkedCommentId': commentId,
        'sourceComment': {
          'text': commentText,
          'authorId': commentAuthor['id'],
          'authorName': commentAuthor['displayName'] ?? commentAuthor['name'],
          'authorUsername': commentAuthor['username'],
        },
        'contentType': 'text',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'deleted': false,
      });

      await _firestore.collection('forumCategories').doc(categoryId).update({
        'postCount': FieldValue.increment(1),
      });

      debugPrint('✅ Thread created from comment: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      debugPrint('❌ Error creating thread from comment: $e');
      rethrow;
    }
  }

  /// Toggle like on thread
  Future<void> togglePostLike(
      String postId, String userId, ForumAuthor author) async {
    try {
      final postRef = _firestore.collection('forumPosts').doc(postId);

      await _firestore.runTransaction((transaction) async {
        final postDoc = await transaction.get(postRef);
        if (!postDoc.exists) throw Exception('Post not found');

        final data = postDoc.data()!;
        final likedBy = List<String>.from(data['likedBy'] ?? []);

        if (likedBy.contains(userId)) {
          likedBy.remove(userId);
        } else {
          likedBy.add(userId);
        }

        transaction.update(postRef, {
          'likedBy': likedBy,
          'likes': likedBy.length,
        });
      });

      debugPrint('✅ Toggled like on thread: $postId');
    } catch (e) {
      debugPrint('❌ Error toggling like: $e');
      rethrow;
    }
  }

  /// Toggle bookmark on thread
  Future<void> togglePostBookmark(String postId, String userId) async {
    try {
      final postRef = _firestore.collection('forumPosts').doc(postId);

      await _firestore.runTransaction((transaction) async {
        final postDoc = await transaction.get(postRef);
        if (!postDoc.exists) throw Exception('Post not found');

        final data = postDoc.data()!;
        final bookmarkedBy = List<String>.from(data['bookmarkedBy'] ?? []);

        if (bookmarkedBy.contains(userId)) {
          bookmarkedBy.remove(userId);
        } else {
          bookmarkedBy.add(userId);
        }

        transaction.update(postRef, {
          'bookmarkedBy': bookmarkedBy,
        });
      });

      debugPrint('✅ Toggled bookmark on thread: $postId');
    } catch (e) {
      debugPrint('❌ Error toggling bookmark: $e');
      rethrow;
    }
  }

  /// Toggle follow on thread
  Future<void> toggleThreadFollow(String postId, String userId) async {
    try {
      final postRef = _firestore.collection('forumPosts').doc(postId);

      await _firestore.runTransaction((transaction) async {
        final postDoc = await transaction.get(postRef);
        if (!postDoc.exists) throw Exception('Post not found');

        final data = postDoc.data()!;
        final followedBy = List<String>.from(data['followedBy'] ?? []);

        if (followedBy.contains(userId)) {
          followedBy.remove(userId);
        } else {
          followedBy.add(userId);
        }

        transaction.update(postRef, {
          'followedBy': followedBy,
        });
      });

      debugPrint('✅ Toggled follow on thread: $postId');
    } catch (e) {
      debugPrint('❌ Error toggling follow: $e');
      rethrow;
    }
  }

  /// Delete thread
  Future<void> deletePost(String postId, String userId) async {
    try {
      final postDoc =
          await _firestore.collection('forumPosts').doc(postId).get();
      if (!postDoc.exists) throw Exception('Post not found');

      final data = postDoc.data()!;
      final authorId = data['authorId'] as String?;

      if (authorId != userId) {
        throw Exception('Not authorized to delete this thread');
      }

      await _firestore.collection('forumPosts').doc(postId).update({
        'deleted': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ Thread deleted: $postId');
    } catch (e) {
      debugPrint('❌ Error deleting thread: $e');
      rethrow;
    }
  }

  /// Get categories
  Future<List<ForumCategory>> getCategories() async {
    try {
      final snapshot = await _firestore.collection('forumCategories').get();
      return snapshot.docs
          .map((doc) => ForumCategory.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('❌ Error fetching categories: $e');
      return [];
    }
  }

  /// Watch top-level comments for a thread (parentCommentId is null)
  Stream<List<ForumComment>> watchComments(String postId) {
    return _firestore
        .collection('forumPosts')
        .doc(postId)
        .collection('comments')
        .where('parentCommentId', isNull: true)
        .limit(50)
        .snapshots()
        .map((snapshot) {
      final comments = snapshot.docs
          .where((doc) {
            final data = doc.data();
            return (data['deleted'] as bool? ?? false) == false;
          })
          .map((doc) => ForumComment.fromFirestore(doc, postId))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return comments;
    });
  }

  /// Watch replies for a specific comment
  Stream<List<ForumComment>> watchCommentReplies(
    String postId,
    String commentId,
  ) {
    return _firestore
        .collection('forumPosts')
        .doc(postId)
        .collection('comments')
        .where('parentCommentId', isEqualTo: commentId)
        .limit(50)
        .snapshots()
        .map((snapshot) {
      final comments = snapshot.docs
          .where((doc) {
            final data = doc.data();
            return (data['deleted'] as bool? ?? false) == false;
          })
          .map((doc) => ForumComment.fromFirestore(doc, postId))
          .toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      return comments;
    });
  }

  /// Add comment to thread (top-level or reply)
  Future<String> addComment(
    String postId,
    String content,
    ForumAuthor author, {
    String? parentCommentId,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final commentRef = _firestore
          .collection('forumPosts')
          .doc(postId)
          .collection('comments')
          .doc();

      final commentData = {
        'postId': postId,
        'content': content.trim(),
        'author': {
          'uid': author.uid,
          'username': author.username,
          'displayName': author.displayName,
          'avatarUrl': author.avatarUrl,
        },
        'parentCommentId': parentCommentId,
        'likes': 0,
        'likedBy': [],
        'dislikes': 0,
        'dislikedBy': [],
        'replyCount': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'deleted': false,
      };

      await commentRef.set(commentData);

      // Update parent comment's reply count if this is a reply
      if (parentCommentId != null) {
        final parentRef = _firestore
            .collection('forumPosts')
            .doc(postId)
            .collection('comments')
            .doc(parentCommentId);

        await parentRef.update({
          'replyCount': FieldValue.increment(1),
        });
      }

      // Update thread's comment count
      final postRef = _firestore.collection('forumPosts').doc(postId);
      await postRef.update({
        'commentCount': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ Comment added to thread: $postId');
      return commentRef.id;
    } catch (e) {
      debugPrint('❌ Error adding comment: $e');
      rethrow;
    }
  }

  /// Toggle like on thread comment (mutually exclusive with dislike)
  Future<void> toggleCommentLike(
      String postId, String commentId, String userId) async {
    try {
      final commentRef = _firestore
          .collection('forumPosts')
          .doc(postId)
          .collection('comments')
          .doc(commentId);

      await _firestore.runTransaction((transaction) async {
        final commentDoc = await transaction.get(commentRef);
        if (!commentDoc.exists) throw Exception('Comment not found');

        final data = commentDoc.data()!;
        final likedBy = List<String>.from(data['likedBy'] ?? []);
        final dislikedBy = List<String>.from(data['dislikedBy'] ?? []);
        final isLiked = likedBy.contains(userId);
        final isDisliked = dislikedBy.contains(userId);

        if (isLiked) {
          // Unlike
          transaction.update(commentRef, {
            'likes': FieldValue.increment(-1),
            'likedBy': FieldValue.arrayRemove([userId]),
          });
        } else {
          // Like
          if (isDisliked) {
            // Remove dislike first (mutually exclusive)
            transaction.update(commentRef, {
              'dislikes': FieldValue.increment(-1),
              'dislikedBy': FieldValue.arrayRemove([userId]),
            });
          }
          transaction.update(commentRef, {
            'likes': FieldValue.increment(1),
            'likedBy': FieldValue.arrayUnion([userId]),
          });
        }
      });

      debugPrint('✅ Toggled like on thread comment: $commentId');
    } catch (e) {
      debugPrint('❌ Error toggling comment like: $e');
      rethrow;
    }
  }

  /// Toggle dislike on thread comment (mutually exclusive with like)
  Future<void> toggleCommentDislike(
      String postId, String commentId, String userId) async {
    try {
      final commentRef = _firestore
          .collection('forumPosts')
          .doc(postId)
          .collection('comments')
          .doc(commentId);

      await _firestore.runTransaction((transaction) async {
        final commentDoc = await transaction.get(commentRef);
        if (!commentDoc.exists) throw Exception('Comment not found');

        final data = commentDoc.data()!;
        final likedBy = List<String>.from(data['likedBy'] ?? []);
        final dislikedBy = List<String>.from(data['dislikedBy'] ?? []);
        final isLiked = likedBy.contains(userId);
        final isDisliked = dislikedBy.contains(userId);

        if (isDisliked) {
          // Undislike
          transaction.update(commentRef, {
            'dislikes': FieldValue.increment(-1),
            'dislikedBy': FieldValue.arrayRemove([userId]),
          });
        } else {
          // Dislike
          if (isLiked) {
            // Remove like first (mutually exclusive)
            transaction.update(commentRef, {
              'likes': FieldValue.increment(-1),
              'likedBy': FieldValue.arrayRemove([userId]),
            });
          }
          transaction.update(commentRef, {
            'dislikes': FieldValue.increment(1),
            'dislikedBy': FieldValue.arrayUnion([userId]),
          });
        }
      });

      debugPrint('✅ Toggled dislike on thread comment: $commentId');
    } catch (e) {
      debugPrint('❌ Error toggling comment dislike: $e');
      rethrow;
    }
  }

  /// Delete thread comment (soft delete, author only)
  Future<void> deleteComment(String postId, String commentId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User must be authenticated');

      final commentRef = _firestore
          .collection('forumPosts')
          .doc(postId)
          .collection('comments')
          .doc(commentId);

      final commentDoc = await commentRef.get();
      if (!commentDoc.exists) throw Exception('Comment not found');

      final data = commentDoc.data()!;
      final author =
          ForumAuthor.fromMap(data['author'] as Map<String, dynamic>);

      // Only author can delete
      if (author.uid != user.uid) {
        throw Exception('Only the comment author can delete this comment');
      }

      final parentCommentId = data['parentCommentId'] as String?;
      final batch = _firestore.batch();

      // Soft delete
      batch.update(commentRef, {
        'deleted': true,
        'content': '[deleted]',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update parent comment's reply count if this is a reply
      if (parentCommentId != null) {
        final parentRef = _firestore
            .collection('forumPosts')
            .doc(postId)
            .collection('comments')
            .doc(parentCommentId);

        batch.update(parentRef, {
          'replyCount': FieldValue.increment(-1),
        });
      }

      // Update thread's comment count
      final postRef = _firestore.collection('forumPosts').doc(postId);
      batch.update(postRef, {
        'commentCount': FieldValue.increment(-1),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      debugPrint('✅ Comment deleted from thread: $commentId');
    } catch (e) {
      debugPrint('❌ Error deleting comment: $e');
      rethrow;
    }
  }

  /// Get video details for embedding
  Future<Map<String, dynamic>?> getVideoDetails(String videoId) async {
    try {
      final doc = await _firestore.collection('videos').doc(videoId).get();
      if (!doc.exists) return null;
      return doc.data();
    } catch (e) {
      debugPrint('❌ Error fetching video details: $e');
      return null;
    }
  }

  /// Get user profile data for author enrichment
  Future<ForumAuthor> getUserProfile(String userId) async {
    try {
      return await _discussionAuthorService.loadForumAuthor(userId);
    } catch (e) {
      debugPrint('❌ Error fetching user profile: $e');
      rethrow;
    }
  }

  /// Enrich forum posts with current user avatar data from users collection
  /// TEMPORARILY DISABLED: Commented out to prevent memory issues
  /// TODO: Re-enable with proper caching and pagination
  // ignore: unused_element
  Future<List<ForumPost>> _enrichPostsWithUserAvatars(
      List<ForumPost> posts) async {
    if (posts.isEmpty) return posts;

    try {
      // Collect unique author IDs
      final authorIds = posts.map((post) => post.author.uid).toSet().toList();

      // Batch fetch user data (Firestore 'in' query limit is 10)
      final Map<String, String?> avatarMap = {};
      for (int i = 0; i < authorIds.length; i += 10) {
        final batch = authorIds.skip(i).take(10).toList();
        final userDocs = await Future.wait(
          batch.map(
              (userId) => _firestore.collection('users').doc(userId).get()),
        );

        for (var doc in userDocs) {
          if (doc.exists && doc.data() != null) {
            final userData = doc.data()!;
            final avatarUrl = userData['avatarURL'] as String?;
            if (avatarUrl != null && avatarUrl.isNotEmpty) {
              avatarMap[doc.id] = avatarUrl;
            }
          }
        }
      }

      // Update posts with current avatar URLs
      return posts.map((post) {
        final currentAvatarUrl = avatarMap[post.author.uid];
        if (currentAvatarUrl != null && currentAvatarUrl.isNotEmpty) {
          // Create new ForumAuthor with updated avatar
          final updatedAuthor = ForumAuthor(
            uid: post.author.uid,
            username: post.author.username,
            displayName: post.author.displayName,
            avatarUrl: currentAvatarUrl,
          );

          // Return new ForumPost with updated author
          return ForumPost(
            id: post.id,
            title: post.title,
            content: post.content,
            category: post.category,
            tags: post.tags,
            author: updatedAuthor,
            visibility: post.visibility,
            likes: post.likes,
            commentCount: post.commentCount,
            likedBy: post.likedBy,
            bookmarkedBy: post.bookmarkedBy,
            followedBy: post.followedBy,
            linkedVideoId: post.linkedVideoId,
            linkedCommentId: post.linkedCommentId,
            sourceComment: post.sourceComment,
            createdAt: post.createdAt,
            updatedAt: post.updatedAt,
            deleted: post.deleted,
          );
        }
        return post;
      }).toList();
    } catch (e) {
      debugPrint('❌ Error enriching posts with avatars: $e');
      // Return original posts if enrichment fails
      return posts;
    }
  }

  /// Enriches a list of ForumComments with current user avatar URLs from the 'users' collection.
  /// This is necessary because the 'author' field in comments might contain outdated avatar URLs.
  /// TEMPORARILY DISABLED: Commented out to prevent memory issues
  /// TODO: Re-enable with proper caching and pagination
  // ignore: unused_element
  Future<List<ForumComment>> _enrichCommentsWithUserAvatars(
      List<ForumComment> comments) async {
    if (comments.isEmpty) return comments;

    // Limit enrichment to prevent memory issues
    if (comments.length > 100) {
      debugPrint(
          '⚠️ Too many comments to enrich (${comments.length}), skipping enrichment');
      return comments;
    }

    try {
      // Collect unique author UIDs
      final Set<String> authorUids =
          comments.map((comment) => comment.author.uid).toSet();

      // Limit the number of unique authors to prevent excessive queries
      if (authorUids.length > 50) {
        debugPrint(
            '⚠️ Too many unique authors (${authorUids.length}), skipping enrichment');
        return comments;
      }

      // Fetch user documents in batches (Firestore 'whereIn' limit is 10)
      final Map<String, String> currentAvatarUrls = {};
      final List<String> uidsList = authorUids.toList();

      for (int i = 0; i < uidsList.length; i += 10) {
        final chunk = uidsList.sublist(i, (i + 10).clamp(0, uidsList.length));
        final usersSnapshot = await _firestore
            .collection('users')
            .where(FieldPath.documentId, whereIn: chunk)
            .get();

        for (final doc in usersSnapshot.docs) {
          final userData = doc.data();
          final avatarUrl = userData['avatarURL'] as String?;
          if (avatarUrl != null && avatarUrl.isNotEmpty) {
            currentAvatarUrls[doc.id] = avatarUrl;
          }
        }
      }

      // Create new ForumComment objects with updated author avatars
      return comments.map((comment) {
        final currentAvatarUrl = currentAvatarUrls[comment.author.uid];
        if (currentAvatarUrl != null &&
            currentAvatarUrl != comment.author.avatarUrl) {
          return ForumComment(
            id: comment.id,
            postId: comment.postId,
            content: comment.content,
            author: ForumAuthor(
              uid: comment.author.uid,
              username: comment.author.username,
              displayName: comment.author.displayName,
              avatarUrl: currentAvatarUrl, // Use the current avatar URL
            ),
            parentCommentId: comment.parentCommentId,
            quotedCommentId: comment.quotedCommentId,
            createdAt: comment.createdAt,
            updatedAt: comment.updatedAt,
            likes: comment.likes,
            dislikes: comment.dislikes,
            likedBy: comment.likedBy,
            dislikedBy: comment.dislikedBy,
            replyCount: comment.replyCount,
            deleted: comment.deleted,
            role: comment.role,
          );
        }
        return comment; // No change needed
      }).toList();
    } catch (e) {
      debugPrint('❌ Error enriching comments with avatars: $e');
      // Return original comments if enrichment fails
      return comments;
    }
  }
}
