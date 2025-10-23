import 'package:flutter/foundation.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'json_converters.dart';

part 'message.freezed.dart';
part 'message.g.dart';

@freezed
class Message with _$Message {
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
  }) = _Message;

  factory Message.fromJson(Map<String, dynamic> json) =>
      _$MessageFromJson(json);
}

// Extension for computed properties
extension MessageExtension on Message {
  String get senderId => from;
}
