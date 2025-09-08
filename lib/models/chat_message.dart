import 'package:flutter/foundation.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'user.dart';
import 'json_converters.dart';

part 'chat_message.freezed.dart';
part 'chat_message.g.dart';

@freezed
class ChatMessage with _$ChatMessage {
  const factory ChatMessage({
    required String id,
    @UserConverter() required User sender,
    required MessageContent content,
    @TimestampConverter() required DateTime timestamp,
    @Default(false) bool isFromCurrentUser,
    @Default(false) bool isRead,
  }) = _ChatMessage;

  factory ChatMessage.fromJson(Map<String, dynamic> json) => _$ChatMessageFromJson(json);
}

@freezed
class MessageContent with _$MessageContent {
  const factory MessageContent.text(String text) = TextMessage;
  const factory MessageContent.video(VideoMessage video) = VideoMessageContent;
  const factory MessageContent.reaction(String emoji) = ReactionMessage;

  factory MessageContent.fromJson(Map<String, dynamic> json) => _$MessageContentFromJson(json);
}

@freezed
class VideoMessage with _$VideoMessage {
  const factory VideoMessage({
    required String videoURL,
    String? thumbnailURL,
    String? caption,
    required double duration,
  }) = _VideoMessage;

  factory VideoMessage.fromJson(Map<String, dynamic> json) => _$VideoMessageFromJson(json);
}

// Extension for sample data
extension ChatMessageExtension on ChatMessage {
  static List<ChatMessage> get samples => [
    ChatMessage(
      id: '1',
      sender: UserSamples.samples[1],
      content: const MessageContent.text("Hey! How's it going?"),
      timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
      isFromCurrentUser: false,
      isRead: true,
    ),
    ChatMessage(
      id: '2',
      sender: UserSamples.samples[0],
      content: const MessageContent.text("Hi! I'm doing great, thanks for asking!"),
      timestamp: DateTime.now().subtract(const Duration(minutes: 4)),
      isFromCurrentUser: true,
      isRead: true,
    ),
    ChatMessage(
      id: '3',
      sender: UserSamples.samples[1],
      content: const MessageContent.text("That's awesome! Are you streaming tonight?"),
      timestamp: DateTime.now().subtract(const Duration(minutes: 3)),
      isFromCurrentUser: false,
      isRead: true,
    ),
    ChatMessage(
      id: '4',
      sender: UserSamples.samples[0],
      content: const MessageContent.text("Yes! I'll be live at 8 PM. You should join!"),
      timestamp: DateTime.now().subtract(const Duration(minutes: 2)),
      isFromCurrentUser: true,
      isRead: false,
    ),
    ChatMessage(
      id: '5',
      sender: UserSamples.samples[1],
      content: const MessageContent.reaction("👍"),
      timestamp: DateTime.now().subtract(const Duration(minutes: 1)),
      isFromCurrentUser: false,
      isRead: false,
    ),
    ChatMessage(
      id: '6',
      sender: UserSamples.samples[1],
      content: const MessageContent.video(
        VideoMessage(
          videoURL: "https://example.com/video1.mp4",
          thumbnailURL: "https://example.com/thumbnail1.jpg",
          caption: "Check out this amazing play!",
          duration: 15.0,
        ),
      ),
      timestamp: DateTime.now(),
      isFromCurrentUser: false,
      isRead: false,
    ),
  ];
}
