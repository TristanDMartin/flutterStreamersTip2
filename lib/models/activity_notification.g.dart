// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'activity_notification.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ActivityNotificationImpl _$$ActivityNotificationImplFromJson(
        Map<String, dynamic> json) =>
    _$ActivityNotificationImpl(
      id: json['id'] as String,
      type: $enumDecode(_$ActivityNotificationTypeEnumMap, json['type']),
      user:
          const UserConverter().fromJson(json['user'] as Map<String, dynamic>),
      timestamp: const TimestampConverter().fromJson(json['timestamp']),
      postThumbnailUrl: json['postThumbnailUrl'] as String?,
      commentText: json['commentText'] as String?,
      status: json['status'] as String? ?? 'pending',
      videoId: json['videoId'] as String?,
    );

Map<String, dynamic> _$$ActivityNotificationImplToJson(
        _$ActivityNotificationImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'type': _$ActivityNotificationTypeEnumMap[instance.type]!,
      'user': const UserConverter().toJson(instance.user),
      'timestamp': const TimestampConverter().toJson(instance.timestamp),
      'postThumbnailUrl': instance.postThumbnailUrl,
      'commentText': instance.commentText,
      'status': instance.status,
      'videoId': instance.videoId,
    };

const _$ActivityNotificationTypeEnumMap = {
  ActivityNotificationType.like: 'like',
  ActivityNotificationType.follow: 'follow',
  ActivityNotificationType.comment: 'comment',
  ActivityNotificationType.tag: 'tag',
  ActivityNotificationType.mention: 'mention',
};
