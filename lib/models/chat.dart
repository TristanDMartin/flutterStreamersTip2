import 'package:freezed_annotation/freezed_annotation.dart';
// ignore_for_file: unused_import
import 'package:cloud_firestore/cloud_firestore.dart';
import 'json_converters.dart';

part 'chat.freezed.dart';
part 'chat.g.dart';

@freezed
sealed class Chat with _$Chat {
  const factory Chat({
    String? id,
    required List<String> participants,
    String? lastMessage,
    @TimestampConverter() required DateTime lastTimestamp,
    String? chatType, // 'direct' or 'group'
    String? groupName,
    String? groupAvatarURL,
    @Default([]) List<String> mutedBy,
    @Default([]) List<String> archivedBy,
    Map<String, dynamic>? metadata,
  }) = _Chat;

  factory Chat.fromJson(Map<String, dynamic> json) => _$ChatFromJson(json);
}

extension ChatSerialization on Chat {
  Map<String, dynamic> toMap() => {
        'id': id,
        'participants': participants,
        'lastMessage': lastMessage,
        'lastTimestamp': const TimestampConverter().toJson(lastTimestamp),
        'chatType': chatType,
        'groupName': groupName,
        'groupAvatarURL': groupAvatarURL,
        'mutedBy': mutedBy,
        'archivedBy': archivedBy,
        'metadata': metadata,
      };
}
