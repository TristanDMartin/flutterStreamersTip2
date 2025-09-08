import 'package:freezed_annotation/freezed_annotation.dart';

part 'shared_draft.freezed.dart';
part 'shared_draft.g.dart';

@freezed
class SharedDraft with _$SharedDraft {
  const factory SharedDraft({
    required String id,
    required String draftId,
    required String senderId,
    required String receiverId,
    required String senderName,
    required String senderAvatar,
    required String draftTitle,
    required String draftThumbnailUrl,
    required int draftDuration,
    required DateTime sharedAt,
    required SharedDraftStatus status,
    String? message,
    DateTime? viewedAt,
  }) = _SharedDraft;

  factory SharedDraft.fromJson(Map<String, dynamic> json) =>
      _$SharedDraftFromJson(json);
}

enum SharedDraftStatus {
  pending,
  delivered,
  viewed,
  declined,
}

