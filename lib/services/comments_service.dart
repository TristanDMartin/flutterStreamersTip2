import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/foundation.dart';
import '../models/comment.dart';
import '../models/user.dart' as app_user;
import 'event_trigger_service.dart';

class VideoCommentsSnapshot {
  final List<Comment> comments;
  final Map<String, String> linkedThreadIds;

  const VideoCommentsSnapshot({
    required this.comments,
    required this.linkedThreadIds,
  });
}

class _CommentDocumentData {
  const _CommentDocumentData({
    required this.id,
    required this.data,
    required this.isCanonical,
  });

  final String id;
  final Map<String, dynamic> data;
  final bool isCanonical;
}

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

      final actualCount = commentsSnapshot.docs.where((doc) {
        final data = doc.data();
        final parentCommentId = (data['parentCommentId'] as String?)?.trim();
        final deleted = data['deleted'] as bool? ?? false;
        return (parentCommentId == null || parentCommentId.isEmpty) && !deleted;
      }).length;

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

  CollectionReference<Map<String, dynamic>> _commentsCollection(
      String videoId) {
    return _firestore.collection('videos').doc(videoId).collection('comments');
  }

  Future<VideoCommentsSnapshot> _buildCommentsSnapshotFromDocs({
    required String videoId,
    required Iterable<_CommentDocumentData> docs,
  }) async {
    final currentUserId = _auth.currentUser?.uid;
    final topLevelDocs = <_CommentDocumentData>[];
    final repliesByParent = <String, List<Comment>>{};
    final linkedThreadIds = <String, String>{};
    final canonicalCommentKeys = <String>{};
    final filteredDocs = <_CommentDocumentData>[];

    for (final doc in docs) {
      final data = doc.data;
      if (_isDeletedComment(data)) {
        continue;
      }
      if (doc.isCanonical) {
        canonicalCommentKeys.add(_commentDedupeKey(data));
      }
      filteredDocs.add(doc);
    }

    for (final doc in filteredDocs) {
      final data = doc.data;
      if (!doc.isCanonical &&
          canonicalCommentKeys.contains(_commentDedupeKey(data))) {
        continue;
      }
      final parentCommentId = (data['parentCommentId'] as String?)?.trim();
      if (parentCommentId != null && parentCommentId.isNotEmpty) {
        final reply = _commentFromData(
          id: doc.id,
          data: data,
          currentUserId: currentUserId,
        );
        repliesByParent
            .putIfAbsent(parentCommentId, () => <Comment>[])
            .add(reply);
        continue;
      }

      final linkedThreadId = (data['linkedThreadId'] as String?)?.trim();
      if (linkedThreadId != null && linkedThreadId.isNotEmpty) {
        linkedThreadIds[doc.id] = linkedThreadId;
      }
      topLevelDocs.add(doc);
    }

    for (final entry in repliesByParent.entries) {
      entry.value.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    }

    final comments = topLevelDocs.map((doc) {
      final data = doc.data;
      final firstClassReplies = repliesByParent[doc.id];
      final legacyReplies = _legacyRepliesFromData(
        data,
        currentUserId: currentUserId,
      );

      return _commentFromData(
        id: doc.id,
        data: data,
        currentUserId: currentUserId,
        replies: (firstClassReplies != null && firstClassReplies.isNotEmpty)
            ? firstClassReplies
            : legacyReplies,
      );
    }).toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    return VideoCommentsSnapshot(
      comments: comments,
      linkedThreadIds: linkedThreadIds,
    );
  }

  String _commentDedupeKey(Map<String, dynamic> data) {
    final userId = _readCommentUserId(data);
    final text = (data['text'] ?? data['content'] ?? data['commentText'] ?? '')
        .toString()
        .trim();
    return '$userId::$text';
  }

  Comment _commentFromData({
    required String id,
    required Map<String, dynamic> data,
    required String? currentUserId,
    List<Comment>? replies,
  }) {
    final likedBy =
        (data['likedBy'] as List<dynamic>?)?.cast<String>() ?? const <String>[];
    final likeCount = (data['likeCount'] as num?)?.toInt() ??
        (data['likes'] as num?)?.toInt() ??
        likedBy.length;
    final deleted = data['deleted'] as bool? ?? false;
    final timestamp = _readCommentTimestamp(data);
    final userData = _readCommentUserData(id: id, data: data);

    return Comment(
      id: id,
      user: app_user.User.fromMap(userData),
      text: deleted
          ? '[deleted]'
          : (data['text'] ?? data['content'] ?? data['commentText'] ?? '')
              .toString(),
      timestamp: timestamp,
      likeCount: likeCount,
      isLiked: currentUserId != null && likedBy.contains(currentUserId),
      replies: replies,
    );
  }

  List<Comment> _legacyRepliesFromData(
    Map<String, dynamic> data, {
    required String? currentUserId,
  }) {
    final hasCanonicalReplyContract = data.containsKey('replyCount') ||
        data.containsKey('parentCommentId') ||
        data.containsKey('deleted') ||
        data.containsKey('likedBy');
    if (hasCanonicalReplyContract) {
      return const <Comment>[];
    }

    final rawReplies = (data['replies'] as List<dynamic>?) ?? const [];
    return rawReplies
        .whereType<Map<String, dynamic>>()
        .map((reply) => _commentFromData(
              id: (reply['id'] as String?)?.isNotEmpty == true
                  ? reply['id'] as String
                  : 'legacy-reply-${reply['timestamp'] ?? reply.hashCode}',
              data: reply,
              currentUserId: currentUserId,
              replies: const [],
            ))
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  bool _isDeletedComment(Map<String, dynamic> data) {
    return data['deleted'] as bool? ?? false;
  }

  DateTime _readCommentTimestamp(Map<String, dynamic> data) {
    final rawTimestamp =
        data['timestamp'] ?? data['createdAt'] ?? data['updatedAt'];
    if (rawTimestamp is Timestamp) {
      return rawTimestamp.toDate();
    }
    if (rawTimestamp is String) {
      return DateTime.tryParse(rawTimestamp) ?? DateTime.now();
    }
    return DateTime.now();
  }

  Map<String, dynamic> _readCommentUserData({
    required String id,
    required Map<String, dynamic> data,
  }) {
    final rawUser = data['user'] ?? data['author'];
    if (rawUser is Map) {
      return rawUser.cast<String, dynamic>();
    }

    final userId = (data['userId'] ??
            data['authorId'] ??
            data['commenterId'] ??
            data['uid'] ??
            '')
        .toString();
    final displayName = (data['displayName'] ??
            data['authorName'] ??
            data['username'] ??
            'Creator')
        .toString();

    return <String, dynamic>{
      'id': userId.isNotEmpty ? userId : 'comment-$id',
      'username': (data['username'] ?? displayName).toString(),
      'displayName': displayName,
      'bio': '',
      'avatarURL': data['avatarURL'] ?? data['avatarUrl'] ?? data['photoURL'],
      'onlineStatus': 'online',
      'hashtags': const <String>[],
      'postCount': 0,
      'followerCount': 0,
      'followingCount': 0,
    };
  }

  String _readCommentUserId(Map<String, dynamic> data) {
    final rawUser = data['user'] ?? data['author'];
    if (rawUser is Map) {
      final userId = rawUser['id'] ?? rawUser['uid'];
      if (userId != null && userId.toString().trim().isNotEmpty) {
        return userId.toString();
      }
    }
    return (data['userId'] ??
            data['authorId'] ??
            data['commenterId'] ??
            data['uid'] ??
            '')
        .toString();
  }

  Stream<VideoCommentsSnapshot> watchCommentsForVideo(String videoId) {
    late StreamController<VideoCommentsSnapshot> controller;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
        canonicalSubscription;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? legacySubscription;
    var canonicalDocs = <_CommentDocumentData>[];
    var legacyDocs = <_CommentDocumentData>[];
    var closed = false;
    var emitToken = 0;

    Future<void> emit() async {
      final token = ++emitToken;
      try {
        final snapshot = await _buildCommentsSnapshotFromDocs(
          videoId: videoId,
          docs: <_CommentDocumentData>[...canonicalDocs, ...legacyDocs],
        );
        if (!closed && token == emitToken) {
          controller.add(snapshot);
        }
      } catch (error, stackTrace) {
        if (!closed && token == emitToken) {
          controller.addError(error, stackTrace);
        }
      }
    }

    controller = StreamController<VideoCommentsSnapshot>.broadcast(
      onListen: () {
        canonicalSubscription = _commentsCollection(videoId).snapshots().listen(
          (QuerySnapshot<Map<String, dynamic>> snapshot) {
            canonicalDocs = snapshot.docs
                .map(
                  (doc) => _CommentDocumentData(
                    id: doc.id,
                    data: doc.data(),
                    isCanonical: true,
                  ),
                )
                .toList(growable: false);
            unawaited(emit());
          },
          onError: controller.addError,
        );
        legacySubscription = _firestore
            .collection('comments')
            .where('videoId', isEqualTo: videoId)
            .snapshots()
            .listen(
          (QuerySnapshot<Map<String, dynamic>> snapshot) {
            legacyDocs = snapshot.docs
                .map(
                  (doc) => _CommentDocumentData(
                    id: doc.id,
                    data: doc.data(),
                    isCanonical: false,
                  ),
                )
                .toList(growable: false);
            unawaited(emit());
          },
          onError: (Object error, StackTrace stackTrace) {
            debugPrint(
              '⚠️ CommentsService: legacy comments stream failed: $error',
            );
            unawaited(emit());
          },
        );
      },
      onCancel: () async {
        closed = true;
        await canonicalSubscription?.cancel();
        await legacySubscription?.cancel();
      },
    );
    return controller.stream;
  }

  /// Fetch comments for a video
  Future<List<Comment>> fetchCommentsForVideo(String videoId) async {
    try {
      if (_auth.currentUser == null) {
        // print('User not authenticated, returning mock data');
        return CommentMockData.mockData();
      }

      final snapshot = await _commentsCollection(videoId).get();

      if (snapshot.docs.isEmpty) {
        // print('No comments found for video $videoId, returning mock data');
        return CommentMockData.mockData();
      }

      final commentsSnapshot = await _buildCommentsSnapshotFromDocs(
        videoId: videoId,
        docs: snapshot.docs
            .map(
              (doc) => _CommentDocumentData(
                id: doc.id,
                data: doc.data(),
                isCanonical: true,
              ),
            )
            .toList(growable: false),
      );
      return commentsSnapshot.comments;
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

      final docRef = await _commentsCollection(videoId).add({
        ...comment.toJson(),
        ..._commentWriteMetadata(
          videoId: videoId,
          currentUserId: currentUser.uid,
          author: author,
        ),
        'parentCommentId': null,
        'likedBy': const <String>[],
        'replyCount': 0,
      });

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

      final parentRef = _commentsCollection(videoId).doc(parentId);
      final replyRef = _commentsCollection(videoId).doc();

      await _firestore.runTransaction((transaction) async {
        final parentDoc = await transaction.get(parentRef);
        if (!parentDoc.exists) {
          throw Exception('Parent comment not found');
        }
        final parentData = parentDoc.data();
        final parentDeleted = parentData?['deleted'] as bool? ?? false;
        if (parentDeleted) {
          throw Exception('Cannot reply to a deleted comment');
        }

        transaction.set(replyRef, {
          ...reply.toJson(),
          ..._commentWriteMetadata(
            videoId: videoId,
            currentUserId: currentUser.uid,
            author: author,
          ),
          'parentCommentId': parentId,
          'likedBy': const <String>[],
          'replyCount': 0,
        });
      });

      unawaited(_incrementReplyCount(parentRef));

      return reply.copyWith(id: replyRef.id);
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

  Map<String, dynamic> _commentWriteMetadata({
    required String videoId,
    required String currentUserId,
    required app_user.User author,
  }) {
    final authorId = author.id.isNotEmpty ? author.id : currentUserId;
    return <String, dynamic>{
      'videoId': videoId,
      'userId': authorId,
      'authorId': authorId,
      'commenterId': authorId,
      'uid': authorId,
      'username': author.username,
      'displayName': author.displayName,
      'authorName': author.displayName,
      'avatarURL': author.avatarURL,
    };
  }

  Future<void> _incrementReplyCount(
    DocumentReference<Map<String, dynamic>> parentRef,
  ) async {
    try {
      await parentRef.update({
        'replyCount': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('⚠️ CommentsService: Reply count update skipped: $e');
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

      final commentRef = _commentsCollection(videoId).doc(commentId);

      final doc = await commentRef.get();
      if (!doc.exists) return false;

      final data = doc.data()!;
      final likedBy = List<String>.from(data['likedBy'] ?? const []);
      final isLiked = likedBy.contains(currentUser.uid);

      if (isLiked) {
        likedBy.remove(currentUser.uid);
      } else {
        likedBy.add(currentUser.uid);
      }

      await commentRef.update({
        'likedBy': likedBy,
        'likeCount': likedBy.length,
        'isLiked': false,
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
      final commentAuthorId = _readCommentUserId(commentData);
      final parentCommentId =
          (commentData['parentCommentId'] as String?)?.trim();
      final alreadyDeleted = commentData['deleted'] as bool? ?? false;

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

      if (alreadyDeleted) {
        return true;
      }

      await _firestore.runTransaction((transaction) async {
        transaction.update(commentDoc.reference, {
          'deleted': true,
          'text': '[deleted]',
          'updatedAt': FieldValue.serverTimestamp(),
        });

        if (parentCommentId != null && parentCommentId.isNotEmpty) {
          final parentRef = _commentsCollection(videoId).doc(parentCommentId);
          final parentDoc = await transaction.get(parentRef);
          if (parentDoc.exists) {
            final parentData = parentDoc.data();
            final currentReplyCount =
                (parentData?['replyCount'] as num?)?.toInt() ?? 0;
            transaction.update(parentRef, {
              'replyCount': currentReplyCount > 0 ? currentReplyCount - 1 : 0,
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }
        }
      });

      // Only top-level comments affect the video-level comment counter.
      if (parentCommentId == null || parentCommentId.isEmpty) {
        await _eventTriggerService?.triggerCommentDeleteEvent(
          videoId: videoId,
        );
      }

      return true;
    } catch (e) {
      if (e is CommentError) {
        rethrow;
      }
      // print('Error deleting comment: $e');
      return false;
    }
  }

  /// Link comment to thread (updates Firestore directly, doesn't modify Comment model)
  Future<bool> linkCommentToThread({
    required String videoId,
    required String commentId,
    required String threadId,
  }) async {
    try {
      await _firestore
          .collection('videos')
          .doc(videoId)
          .collection('comments')
          .doc(commentId)
          .update({'linkedThreadId': threadId});
      debugPrint('✅ Comment $commentId linked to thread $threadId');
      return true;
    } catch (e) {
      debugPrint('❌ Error linking comment to thread: $e');
      return false;
    }
  }

  /// Get linked thread ID for a comment (queries Firestore directly)
  /// This avoids needing to modify the Comment freezed model
  Future<String?> getLinkedThreadId(String videoId, String commentId) async {
    try {
      final doc = await _firestore
          .collection('videos')
          .doc(videoId)
          .collection('comments')
          .doc(commentId)
          .get();
      if (!doc.exists) return null;
      return doc.data()?['linkedThreadId'] as String?;
    } catch (e) {
      debugPrint('❌ Error getting linked thread ID: $e');
      return null;
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
