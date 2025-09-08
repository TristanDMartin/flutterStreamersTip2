// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'message.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$MessageImpl _$$MessageImplFromJson(Map<String, dynamic> json) =>
    _$MessageImpl(
      id: json['id'] as String?,
      chatId: json['chatId'] as String?,
      text: json['text'] as String,
      from: json['from'] as String,
      to: json['to'] as String,
      timestamp: const TimestampConverter().fromJson(json['timestamp']),
      isRead: json['isRead'] as bool? ?? false,
      recipients: (json['recipients'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      readBy: (json['readBy'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      gifUrl: json['gifUrl'] as String?,
      messageType: json['messageType'] as String? ?? 'text',
    );

Map<String, dynamic> _$$MessageImplToJson(_$MessageImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'chatId': instance.chatId,
      'text': instance.text,
      'from': instance.from,
      'to': instance.to,
      'timestamp': const TimestampConverter().toJson(instance.timestamp),
      'isRead': instance.isRead,
      'recipients': instance.recipients,
      'readBy': instance.readBy,
      'gifUrl': instance.gifUrl,
      'messageType': instance.messageType,
    };
