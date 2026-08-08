import 'package:flutter/foundation.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'json_converters.dart';

part 'message.freezed.dart';
part 'message.g.dart';

@freezed
sealed class Message with _$Message {
  const factory Message({
    String? id,
    String? chatId,
    @Default('') String text,
    @Default('') String from,
    @Default('') String to,
    @TimestampConverter() DateTime? timestamp,
    @Default(false) bool isRead,
    @Default([]) List<String> recipients,
    @Default([]) List<String> readBy,
    String? gifUrl,
    @Default('text') String messageType,
    @Default(false) bool isDeviceGif,
    // Video share fields
    String? videoId,
    String? shareToken,
    String? videoThumbnailUrl,
    String? videoTitle,
    String? replyToMessageId,
    String? replyToSenderId,
    String? replyToSenderName,
    String? replyToType,
    String? replyPreviewText,
    String? replyThumbnailUrl,
    String? replyVideoId,
    @Default(false) bool deletedForEveryone,
    /// Map of uid → { userId, reaction, timestamp } (web/Flutter shared schema).
    @Default(<String, dynamic>{}) Map<String, dynamic> reactions,
    @Default(false) bool edited,
    @TimestampConverter() DateTime? editedAt,
  }) = _Message;

  factory Message.fromJson(Map<String, dynamic> json) =>
      _$MessageFromJson(json);
}

// Extension for computed properties
extension MessageExtension on Message {
  String get senderId => from;

  /// Aggregate reactions.{uid} into emoji → userId[] for chips.
  Map<String, List<String>> get reactionsByEmoji {
    if (reactions.isEmpty) return const <String, List<String>>{};
    final Map<String, List<String>> byEmoji = <String, List<String>>{};
    for (final MapEntry<String, dynamic> entry in reactions.entries) {
      final dynamic value = entry.value;
      if (value is String && value.isNotEmpty) {
        byEmoji.putIfAbsent(value, () => <String>[]).add(entry.key);
        continue;
      }
      if (value is Map) {
        final String? emoji = value['reaction'] as String?;
        if (emoji == null || emoji.isEmpty) continue;
        byEmoji.putIfAbsent(emoji, () => <String>[]).add(entry.key);
        continue;
      }
      if (value is List) {
        final List<String> userIds =
            value.whereType<String>().toList(growable: false);
        if (userIds.isNotEmpty) {
          byEmoji[entry.key] = userIds;
        }
      }
    }
    return byEmoji;
  }
}
