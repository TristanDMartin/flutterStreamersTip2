import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/foundation.dart';
import '../models/forum_post.dart';
import '../models/forum_comment.dart';
import '../models/forum_category.dart';
import '../models/forum_author.dart';
import '../utils/video_document_rules.dart';
import '../utils/avatar_url_resolver.dart';
import '../features/threads/thread_visibility.dart';
import 'discussion_author_service.dart';
import 'progression_service.dart';
import 'public_profile_firestore.dart';
import 'thread_invite_service.dart';

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

  /// [ForumPost.category] stores a `forumCategories` doc id; resolve labels for UI.
  Future<List<ForumPost>> _attachCategoryDisplayNames(
    List<ForumPost> posts,
  ) async {
    if (posts.isEmpty) {
      return posts;
    }
    try {
      final List<ForumCategory> categories = await getCategories();
      final Map<String, String> idToName = <String, String>{
        for (final ForumCategory c in categories) c.id: c.name,
      };
      return posts.map((ForumPost p) {
        final String? resolved = idToName[p.category]?.trim();
        final String? name = (resolved != null && resolved.isNotEmpty)
            ? resolved
            : p.categoryDisplayName?.trim();
        if (name == null || name.isEmpty) {
          return p;
        }
        return ForumPost(
          id: p.id,
          title: p.title,
          content: p.content,
          category: p.category,
          categoryDisplayName: name,
          tags: p.tags,
          author: p.author,
          visibility: p.visibility,
          likes: p.likes,
          commentCount: p.commentCount,
          likedBy: p.likedBy,
          bookmarkedBy: p.bookmarkedBy,
          followedBy: p.followedBy,
          linkedVideoId: p.linkedVideoId,
          linkedCommentId: p.linkedCommentId,
          status: p.status,
          deletedReason: p.deletedReason,
          sourceComment: p.sourceComment,
          createdAt: p.createdAt,
          updatedAt: p.updatedAt,
          deleted: p.deleted,
        );
      }).toList();
    } catch (e) {
      debugPrint('❌ Error resolving category names: $e');
      return posts;
    }
  }

  ForumPost _copyPostWith({
    required ForumPost post,
    String? categoryDisplayName,
    int? commentCount,
    DateTime? updatedAt,
  }) {
    return ForumPost(
      id: post.id,
      title: post.title,
      content: post.content,
      category: post.category,
      categoryDisplayName: categoryDisplayName ?? post.categoryDisplayName,
      tags: post.tags,
      author: post.author,
      visibility: post.visibility,
      likes: post.likes,
      commentCount: commentCount ?? post.commentCount,
      likedBy: post.likedBy,
      bookmarkedBy: post.bookmarkedBy,
      followedBy: post.followedBy,
      linkedVideoId: post.linkedVideoId,
      linkedCommentId: post.linkedCommentId,
      status: post.status,
      deletedReason: post.deletedReason,
      sourceComment: post.sourceComment,
      createdAt: post.createdAt,
      updatedAt: updatedAt ?? post.updatedAt,
      deleted: post.deleted,
    );
  }

  Future<List<ForumPost>> _attachLiveCommentCounts(
    List<ForumPost> posts,
  ) async {
    if (posts.isEmpty) {
      return posts;
    }
    try {
      final List<ForumPost> updated = await Future.wait(
        posts.map((ForumPost post) async {
          final QuerySnapshot<Map<String, dynamic>> comments = await _firestore
              .collection('forumPosts')
              .doc(post.id)
              .collection('comments')
              .where('deleted', isEqualTo: false)
              .get();
          final int count = comments.docs.length;
          if (count == post.commentCount) {
            return post;
          }
          unawaited(
            _firestore.collection('forumPosts').doc(post.id).set(
              <String, Object?>{
                'commentCount': count,
                'updatedAt': FieldValue.serverTimestamp(),
              },
              SetOptions(merge: true),
            ),
          );
          return _copyPostWith(
            post: post,
            commentCount: count,
            updatedAt: DateTime.now(),
          );
        }),
      );
      return updated;
    } catch (e) {
      debugPrint('❌ Error resolving live thread reply counts: $e');
      return posts;
    }
  }

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
      final List<ForumPost> posts =
          snapshot.docs.map((doc) => ForumPost.fromFirestore(doc)).toList();

      final List<ForumPost> withAvatars =
          await _enrichPostsWithUserAvatars(posts);
      final List<ForumPost> enrichedPosts = await _attachLiveCommentCounts(
          await _attachCategoryDisplayNames(withAvatars));
      final List<ForumPost> audienceVisible =
          await _filterPostsByAudience(enrichedPosts, currentUserId);

      // Apply search query filter if provided
      if (searchQuery != null && searchQuery.isNotEmpty) {
        final lowerQuery = searchQuery.toLowerCase();
        return audienceVisible.where(_isThreadVisible).where((post) {
          return post.title.toLowerCase().contains(lowerQuery) ||
              post.content.toLowerCase().contains(lowerQuery) ||
              post.tags.any((tag) => tag.toLowerCase().contains(lowerQuery));
        }).toList();
      }

      return audienceVisible.where(_isThreadVisible).toList();
    } on FirebaseException catch (e) {
      if (e.code == 'failed-precondition' &&
          (sortBy == ThreadSortBy.activeNow ||
              sortBy == ThreadSortBy.popular)) {
        debugPrint(
          '⚠️ forumPosts index not ready for $sortBy (${e.message}); '
          'using recent',
        );
        return getPosts(
          categoryId: categoryId,
          searchQuery: searchQuery,
          sortBy: ThreadSortBy.recent,
          pageSize: pageSize,
          startAfterDoc: startAfterDoc,
          currentUserId: currentUserId,
        );
      }
      debugPrint('❌ Error fetching threads: $e');
      rethrow;
    } catch (e) {
      debugPrint('❌ Error fetching threads: $e');
      rethrow;
    }
  }

  /// Get thread details
  Future<ForumPost?> getPost(
    String postId, {
    String? currentUserId,
  }) async {
    try {
      final doc = await _firestore.collection('forumPosts').doc(postId).get();
      if (!doc.exists || !_isThreadDocVisible(doc.data())) {
        return null;
      }
      final ForumPost post = ForumPost.fromFirestore(doc);
      final List<ForumPost> accessible =
          await _filterPostsByAudience(<ForumPost>[post], currentUserId);
      if (accessible.isEmpty) {
        return null;
      }
      final List<ForumPost> withNames =
          await _attachCategoryDisplayNames(accessible);
      final List<ForumPost> withCounts =
          await _attachLiveCommentCounts(withNames);
      return withCounts.first;
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
    String? linkedVideoId,
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
        'visibility': normalizeThreadVisibility(visibility),
        'likes': 0,
        'commentCount': 0,
        'likedBy': [],
        'bookmarkedBy': [],
        'followedBy': [],
        if (linkedVideoId != null && linkedVideoId.trim().isNotEmpty)
          'linkedVideoId': linkedVideoId.trim(),
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
        'visibility': normalizeThreadVisibility(visibility),
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
        .asyncMap((QuerySnapshot<Map<String, dynamic>> snapshot) async {
      final List<ForumComment> comments = snapshot.docs
          .where((QueryDocumentSnapshot<Map<String, dynamic>> doc) {
            final Map<String, dynamic> data = doc.data();
            return (data['deleted'] as bool? ?? false) == false;
          })
          .map(
            (QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
                ForumComment.fromFirestore(doc, postId),
          )
          .toList()
        ..sort((ForumComment a, ForumComment b) =>
            b.createdAt.compareTo(a.createdAt));
      return _enrichCommentsWithUserAvatars(comments);
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
        'authorId': author.uid,
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

      unawaited(ProgressionService.instance.markTaskCompleted(
        user.uid,
        ProgressionTaskIds.firstCommentMade,
        source: 'comments',
      ));

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
      final data = doc.data();
      if (data == null || !isVideoVisibleInFeed(data)) return null;
      return data;
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

  static const int _avatarCacheMaxEntries = 200;
  final Map<String, String?> _avatarCache = <String, String?>{};

  void _putAvatarInCache(String userId, String? avatarUrl) {
    if (_avatarCache.length >= _avatarCacheMaxEntries) {
      _avatarCache.remove(_avatarCache.keys.first);
    }
    _avatarCache[userId] = avatarUrl;
  }

  /// Enrich forum posts with current user avatar data (batched + cached).
  Future<List<ForumPost>> _enrichPostsWithUserAvatars(
      List<ForumPost> posts) async {
    if (posts.isEmpty) return posts;

    try {
      final List<String> authorIds =
          posts.map((ForumPost post) => post.author.uid).toSet().toList();
      final Map<String, String?> avatarMap = <String, String?>{};
      final List<String> missingIds = <String>[];
      for (final String userId in authorIds) {
        if (_avatarCache.containsKey(userId)) {
          avatarMap[userId] = _avatarCache[userId];
        } else {
          missingIds.add(userId);
        }
      }
      for (int i = 0; i < missingIds.length; i += 10) {
        final List<String> batch = missingIds.skip(i).take(10).toList();
        final Map<String, Map<String, dynamic>> profiles =
            await PublicProfileFirestore.instance.getProfileMaps(batch);
        for (final String userId in batch) {
          final Map<String, dynamic>? data = profiles[userId];
          if (data == null) {
            _putAvatarInCache(userId, null);
            continue;
          }
          final String? avatarUrl = resolveAvatarUrl(data);
          _putAvatarInCache(userId, avatarUrl);
          if (avatarUrl != null && avatarUrl.isNotEmpty) {
            avatarMap[userId] = avatarUrl;
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
            categoryDisplayName: post.categoryDisplayName,
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
            status: post.status,
            deletedReason: post.deletedReason,
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

  /// Enriches comments with cached user avatar URLs.
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

      final Map<String, String> currentAvatarUrls = <String, String>{};
      final List<String> missingUids = <String>[];
      for (final String uid in authorUids) {
        final String? cached = _avatarCache[uid];
        if (cached != null && cached.isNotEmpty) {
          currentAvatarUrls[uid] = cached;
        } else if (!_avatarCache.containsKey(uid)) {
          missingUids.add(uid);
        }
      }
      for (int i = 0; i < missingUids.length; i += 10) {
        final List<String> chunk =
            missingUids.sublist(i, (i + 10).clamp(0, missingUids.length));
        final Map<String, Map<String, dynamic>> profiles =
            await PublicProfileFirestore.instance.getProfileMaps(chunk);
        for (final MapEntry<String, Map<String, dynamic>> entry
            in profiles.entries) {
          final String? avatarUrl = resolveAvatarUrl(entry.value);
          _putAvatarInCache(entry.key, avatarUrl);
          if (avatarUrl != null && avatarUrl.isNotEmpty) {
            currentAvatarUrls[entry.key] = avatarUrl;
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

  bool _isThreadVisible(ForumPost post) {
    if (post.deleted) {
      return false;
    }
    if (post.status == 'deleted') {
      return false;
    }
    if (post.deletedReason == 'source_video_deleted') {
      return false;
    }
    return true;
  }

  Future<List<ForumPost>> _filterPostsByAudience(
    List<ForumPost> posts,
    String? currentUserId,
  ) async {
    if (posts.isEmpty) {
      return posts;
    }
    final String? viewerId = (currentUserId != null && currentUserId.isNotEmpty)
        ? currentUserId
        : firebase_auth.FirebaseAuth.instance.currentUser?.uid;
    final Map<String, bool> followCache = <String, bool>{};
    final Map<String, bool> inviteCache = <String, bool>{};
    final List<ForumPost> visible = <ForumPost>[];
    for (final ForumPost post in posts) {
      final String authorId = post.author.uid.trim().isNotEmpty
          ? post.author.uid.trim()
          : '';
      final String vis = normalizeThreadVisibility(post.visibility);
      bool follows = false;
      bool inviteAccess = false;
      if (vis == kThreadVisibilityFollowers &&
          viewerId != null &&
          viewerId.isNotEmpty &&
          viewerId != authorId) {
        follows = followCache[authorId] ??=
            await _viewerFollowsAuthor(viewerId, authorId);
      }
      if (vis == kThreadVisibilityInviteOnly &&
          viewerId != null &&
          viewerId.isNotEmpty &&
          viewerId != authorId) {
        inviteAccess = inviteCache[post.id] ??=
            await ThreadInviteService().viewerHasThreadInviteAccess(
          post.id,
          viewerId,
        );
      }
      if (canViewerAccessThread(
        visibility: vis,
        authorId: authorId,
        viewerId: viewerId,
        viewerFollowsAuthor: follows,
        viewerHasInviteAccess: inviteAccess,
      )) {
        visible.add(post);
      }
    }
    return visible;
  }

  Future<bool> _viewerFollowsAuthor(String viewerId, String authorId) async {
    try {
      final DocumentSnapshot<Map<String, dynamic>> edge = await _firestore
          .collection('follows')
          .doc('${viewerId}_$authorId')
          .get();
      if (edge.exists) {
        return true;
      }
      final DocumentSnapshot<Map<String, dynamic>> sub = await _firestore
          .collection('users')
          .doc(authorId)
          .collection('followers')
          .doc(viewerId)
          .get();
      return sub.exists;
    } catch (_) {
      return false;
    }
  }

  bool _isThreadDocVisible(Map<String, dynamic>? data) {
    if (data == null) {
      return false;
    }
    if (data['deleted'] == true) {
      return false;
    }
    if (data['status'] == 'deleted') {
      return false;
    }
    if (data['deletedReason'] == 'source_video_deleted') {
      return false;
    }
    return true;
  }
}
