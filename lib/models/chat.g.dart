// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Chat _$ChatFromJson(Map<String, dynamic> json) => _Chat(
      id: json['id'] as String?,
      participants: (json['participants'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      lastMessage: json['lastMessage'] as String?,
      lastTimestamp: const TimestampConverter().fromJson(json['lastTimestamp']),
      chatType: json['chatType'] as String?,
      groupName: json['groupName'] as String?,
      groupAvatarURL: json['groupAvatarURL'] as String?,
      mutedBy: (json['mutedBy'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      archivedBy: (json['archivedBy'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      metadata: json['metadata'] as Map<String, dynamic>?,
    );

Map<String, dynamic> _$ChatToJson(_Chat instance) => <String, dynamic>{
      'id': instance.id,
      'participants': instance.participants,
      'lastMessage': instance.lastMessage,
      'lastTimestamp':
          const TimestampConverter().toJson(instance.lastTimestamp),
      'chatType': instance.chatType,
      'groupName': instance.groupName,
      'groupAvatarURL': instance.groupAvatarURL,
      'mutedBy': instance.mutedBy,
      'archivedBy': instance.archivedBy,
      'metadata': instance.metadata,
    };
