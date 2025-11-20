// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'inbox_notification.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$InboxNotificationImpl _$$InboxNotificationImplFromJson(
        Map<String, dynamic> json) =>
    _$InboxNotificationImpl(
      id: json['id'] as String,
      text: json['text'] as String,
      timestamp: json['timestamp'] as String,
      type: $enumDecode(_$NotificationTypeEnumMap, json['type']),
    );

Map<String, dynamic> _$$InboxNotificationImplToJson(
        _$InboxNotificationImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'text': instance.text,
      'timestamp': instance.timestamp,
      'type': _$NotificationTypeEnumMap[instance.type]!,
    };

const _$NotificationTypeEnumMap = {
  NotificationType.like: 'like',
  NotificationType.comment: 'comment',
  NotificationType.follow: 'follow',
  NotificationType.scan: 'scan',
};
