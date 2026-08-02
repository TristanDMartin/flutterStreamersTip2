import '../../models/forum_author.dart';
import '../../models/forum_post.dart';
import '../../models/source_comment.dart';
import 'threads_contract.dart';
import 'threads_models.dart';

/// Projects legacy `forumPosts` documents into canonical [ThreadDto].
class ThreadsLegacyAdapter {
  const ThreadsLegacyAdapter();

  ThreadDto fromForumPost(ForumPost post) {
    final String status =
        post.deleted ? 'deleted' : normalizeThreadStatus(post.status);
    final DateTime lastActivity = post.updatedAt;
    final int replyCount = post.commentCount;
    final int saveCount = post.bookmarkedBy.length;
    final int followCount = post.followedBy.length;
    final int participantEstimate =
        _uniqueParticipantEstimate(replyCount);
    final String type = _inferType(post);
    final String categoryId = normalizeCategoryId(
      post.categoryDisplayName ?? post.category,
    );
    final String momentum = status == 'deleted' || status == 'resolved'
        ? 'resolved'
        : computeMomentumState(
            createdAt: post.createdAt,
            lastActivityAt: lastActivity,
            replyCountInWindow: replyCount,
            uniqueParticipantsInWindow: participantEstimate,
            savesInWindow: saveCount,
            status: status,
          );
    return ThreadDto(
      id: post.id,
      schemaVersion: kThreadsSchemaVersion,
      authorId: post.author.uid,
      type: type,
      title: post.title,
      body: post.content,
      categoryId: categoryId,
      categoryLabel: post.categoryDisplayName ?? categoryLabel(categoryId),
      status: status,
      momentumState: momentum,
      visibility: post.visibility == 'inviteOnly'
          ? 'invite_only'
          : post.visibility,
      replyCount: replyCount,
      participantCount: participantEstimate,
      helpfulCount: 0,
      saveCount: saveCount,
      followCount: followCount,
      lastActivityAt: lastActivity,
      createdAt: post.createdAt,
      updatedAt: post.updatedAt,
      authorDisplayName: post.author.displayName,
      authorUsername: post.author.username,
      authorAvatarUrl: post.author.avatarUrl,
      topicTags: post.tags,
      sourceVideoId: post.linkedVideoId,
      sourceCommentId: post.linkedCommentId,
      sourceCommentText: post.sourceComment?.text,
      legacyLikeCount: post.likes,
      legacyLikedBy: post.likedBy,
      legacyBookmarkedBy: post.bookmarkedBy,
      deleted: post.deleted || status == 'deleted',
      deletedReason: post.deletedReason,
      migratedFrom: 'forumPosts',
    );
  }

  ThreadDto fromLegacyMap(String id, Map<String, dynamic> data) {
    final Object? authorRaw = data['author'];
    final Map<String, dynamic> authorMap = authorRaw is Map
        ? Map<String, dynamic>.from(authorRaw)
        : <String, dynamic>{};
    final String authorId = (data['authorId'] as String?) ??
        (authorMap['uid'] as String?) ??
        (authorMap['id'] as String?) ??
        '';
    final bool deleted = data['deleted'] == true ||
        data['isDeleted'] == true ||
        data['status'] == 'deleted';
    final DateTime createdAt = _readDate(data['createdAt']) ?? DateTime.now();
    final DateTime updatedAt = _readDate(data['updatedAt']) ?? createdAt;
    final List<String> likedBy =
        List<String>.from(data['likedBy'] as List? ?? const <dynamic>[]);
    final List<String> bookmarkedBy =
        List<String>.from(data['bookmarkedBy'] as List? ?? const <dynamic>[]);
    final List<String> followedBy =
        List<String>.from(data['followedBy'] as List? ?? const <dynamic>[]);
    final List<String> tags =
        List<String>.from(data['tags'] as List? ?? const <dynamic>[]);
    final int replyCount = (data['commentCount'] as num?)?.toInt() ?? 0;
    final Object? sourceRaw = data['sourceComment'];
    final SourceComment? sourceComment = sourceRaw is Map
        ? SourceComment.fromMap(Map<String, dynamic>.from(sourceRaw))
        : null;
    final ForumPost post = ForumPost(
      id: id,
      title: (data['title'] as String?) ?? '',
      content: (data['content'] as String?) ?? '',
      category: (data['category'] as String?) ?? '',
      categoryDisplayName: data['categoryName'] as String?,
      tags: tags,
      author: ForumAuthor(
        uid: authorId,
        username: (authorMap['username'] as String?) ?? '',
        displayName: (authorMap['displayName'] as String?) ??
            (authorMap['username'] as String?) ??
            'Creator',
        avatarUrl: authorMap['avatarUrl'] as String?,
      ),
      visibility: (data['visibility'] as String?) ?? 'public',
      likes: (data['likes'] as num?)?.toInt() ?? likedBy.length,
      commentCount: replyCount,
      likedBy: likedBy,
      bookmarkedBy: bookmarkedBy,
      followedBy: followedBy,
      linkedVideoId: (data['linkedVideoId'] as String?) ??
          data['sourceVideoId'] as String?,
      linkedCommentId: (data['linkedCommentId'] as String?) ??
          data['sourceCommentId'] as String?,
      status: deleted ? 'deleted' : data['status'] as String?,
      deletedReason: data['deletedReason'] as String?,
      sourceComment: sourceComment,
      createdAt: createdAt,
      updatedAt: updatedAt,
      deleted: deleted,
    );
    return fromForumPost(post);
  }

  String _inferType(ForumPost post) {
    final String haystack =
        '${post.tags.join(' ')} ${post.title} ${post.content}'.toLowerCase();
    if (haystack.contains('debate') || haystack.contains('vs ')) {
      return 'debate';
    }
    if (haystack.contains('feedback') || haystack.contains('review my')) {
      return 'feedback_request';
    }
    if (haystack.contains('win') || haystack.contains('milestone')) {
      return 'creator_win';
    }
    if (haystack.contains('collab') || haystack.contains('lfg')) {
      return 'collaboration';
    }
    if (haystack.contains('day ') || haystack.contains('build in public')) {
      return 'build_in_public';
    }
    return kLegacyDefaultThreadType;
  }

  int _uniqueParticipantEstimate(int replyCount) {
    if (replyCount <= 0) {
      return 1;
    }
    return (replyCount / 2).ceil().clamp(1, replyCount + 1);
  }

  DateTime? _readDate(Object? value) {
    if (value is DateTime) {
      return value;
    }
    if (value == null) {
      return null;
    }
    try {
      final dynamic dyn = value;
      if (dyn.runtimeType.toString().contains('Timestamp')) {
        return dyn.toDate() as DateTime;
      }
    } catch (_) {}
    if (value is String) {
      return DateTime.tryParse(value);
    }
    return null;
  }
}
