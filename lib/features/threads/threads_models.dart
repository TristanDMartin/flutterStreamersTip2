import 'threads_contract.dart';

/// Canonical Thread DTO (Threads v2).
class ThreadDto {
  const ThreadDto({
    required this.id,
    required this.schemaVersion,
    required this.authorId,
    required this.type,
    required this.title,
    required this.body,
    required this.categoryId,
    required this.status,
    required this.momentumState,
    required this.visibility,
    required this.replyCount,
    required this.participantCount,
    required this.helpfulCount,
    required this.saveCount,
    required this.followCount,
    required this.lastActivityAt,
    required this.createdAt,
    required this.updatedAt,
    this.authorDisplayName,
    this.authorUsername,
    this.authorAvatarUrl,
    this.categoryLabel,
    this.platformTags = const <String>[],
    this.topicTags = const <String>[],
    this.payload = const <String, dynamic>{},
    this.sourceVideoId,
    this.sourceCommentId,
    this.sourceCommentText,
    this.legacyLikeCount = 0,
    this.legacyLikedBy = const <String>[],
    this.legacyBookmarkedBy = const <String>[],
    this.deleted = false,
    this.deletedReason,
    this.migratedFrom,
  });

  final String id;
  final int schemaVersion;
  final String authorId;
  final String type;
  final String title;
  final String body;
  final String categoryId;
  final String status;
  final String momentumState;
  final String visibility;
  final int replyCount;
  final int participantCount;
  final int helpfulCount;
  final int saveCount;
  final int followCount;
  final DateTime lastActivityAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? authorDisplayName;
  final String? authorUsername;
  final String? authorAvatarUrl;
  final String? categoryLabel;
  final List<String> platformTags;
  final List<String> topicTags;
  final Map<String, dynamic> payload;
  final String? sourceVideoId;
  final String? sourceCommentId;
  final String? sourceCommentText;
  final int legacyLikeCount;
  final List<String> legacyLikedBy;
  final List<String> legacyBookmarkedBy;
  final bool deleted;
  final String? deletedReason;
  final String? migratedFrom;

  String get typeLabel => threadTypeLabel(type);
  String get statusLabel => threadStatusLabel(status);
  String get momentumLabelText => momentumLabel(momentumState);
  String get resolvedCategoryLabel {
    if (categoryLabel != null && categoryLabel!.isNotEmpty) {
      return categoryLabel!;
    }
    return kCategoryLabels[categoryId] ?? categoryId;
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'schemaVersion': schemaVersion,
      'authorId': authorId,
      'type': type,
      'title': title,
      'body': body,
      'categoryId': categoryId,
      'status': status,
      'momentumState': momentumState,
      'visibility': visibility,
      'replyCount': replyCount,
      'participantCount': participantCount,
      'helpfulCount': helpfulCount,
      'saveCount': saveCount,
      'followCount': followCount,
      'lastActivityAt': lastActivityAt.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'authorDisplayName': authorDisplayName,
      'authorUsername': authorUsername,
      'authorAvatarUrl': authorAvatarUrl,
      'categoryLabel': resolvedCategoryLabel,
      'platformTags': platformTags,
      'topicTags': topicTags,
      'payload': payload,
      'sourceVideoId': sourceVideoId,
      'sourceCommentId': sourceCommentId,
      'sourceCommentText': sourceCommentText,
      'legacyLikeCount': legacyLikeCount,
      'deleted': deleted,
      'deletedReason': deletedReason,
      'migratedFrom': migratedFrom,
    };
  }
}

class ThreadFeedModuleDto {
  const ThreadFeedModuleDto({
    required this.moduleId,
    required this.title,
    required this.threads,
    this.subtitle,
  });

  final String moduleId;
  final String title;
  final String? subtitle;
  final List<ThreadDto> threads;
}

class TippySummaryDto {
  const TippySummaryDto({
    required this.text,
    required this.generatedAt,
    required this.sourceActivityAt,
    this.isAiGenerated = true,
  });

  final String text;
  final DateTime generatedAt;
  final DateTime sourceActivityAt;
  final bool isAiGenerated;
}

class CreateThreadRequest {
  const CreateThreadRequest({
    required this.type,
    required this.title,
    required this.body,
    required this.categoryId,
    required this.authorId,
    this.visibility = 'public',
    this.platformTags = const <String>[],
    this.topicTags = const <String>[],
    this.payload = const <String, dynamic>{},
    this.sourceVideoId,
    this.sourceCommentId,
    this.sourceComment,
    this.tippyStarterId,
  });

  final String type;
  final String title;
  final String body;
  final String categoryId;
  final String authorId;
  final String visibility;
  final List<String> platformTags;
  final List<String> topicTags;
  final Map<String, dynamic> payload;
  final String? sourceVideoId;
  final String? sourceCommentId;
  final Map<String, dynamic>? sourceComment;
  final String? tippyStarterId;
}

class ThreadResolutionDto {
  const ThreadResolutionDto({
    required this.selectedReplyIds,
    required this.resolvedAt,
    required this.resolvedBy,
    this.resolutionNote,
  });

  final List<String> selectedReplyIds;
  final String? resolutionNote;
  final DateTime resolvedAt;
  final String resolvedBy;
}

class WeeklyImpactDto {
  const WeeklyImpactDto({
    required this.creatorsHelped,
    required this.answersMarkedHelpful,
    required this.discussionsReached30,
  });

  final int creatorsHelped;
  final int answersMarkedHelpful;
  final int discussionsReached30;
}
