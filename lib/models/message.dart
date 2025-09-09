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
    required String text,
    required String from,
    required String to,
    @TimestampConverter() required DateTime timestamp,
    @Default(false) bool isRead,
    @Default([]) List<String> recipients,
    @Default([]) List<String> readBy,
    String? gifUrl,
    @Default('text') String messageType,
    @Default(false) bool isDeviceGif,
  }) = _Message;

  factory Message.fromJson(Map<String, dynamic> json) => _$MessageFromJson(json);
}

// Extension for computed properties
extension MessageExtension on Message {
  String get senderId => from;
}
