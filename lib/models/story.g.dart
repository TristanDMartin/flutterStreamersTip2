// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'story.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Story _$StoryFromJson(Map<String, dynamic> json) => _Story(
      id: json['id'] as String,
      creatorId: json['creatorId'] as String,
      creatorName: json['creatorName'] as String,
      creatorAvatarURL: json['creatorAvatarURL'] as String?,
      mediaURL: json['mediaURL'] as String,
      mediaType: $enumDecode(_$MediaTypeEnumMap, json['mediaType']),
      timestamp: DateTime.parse(json['timestamp'] as String),
      duration: (json['duration'] as num).toDouble(),
      isViewed: json['isViewed'] as bool? ?? false,
    );

Map<String, dynamic> _$StoryToJson(_Story instance) => <String, dynamic>{
      'id': instance.id,
      'creatorId': instance.creatorId,
      'creatorName': instance.creatorName,
      'creatorAvatarURL': instance.creatorAvatarURL,
      'mediaURL': instance.mediaURL,
      'mediaType': _$MediaTypeEnumMap[instance.mediaType]!,
      'timestamp': instance.timestamp.toIso8601String(),
      'duration': instance.duration,
      'isViewed': instance.isViewed,
    };

const _$MediaTypeEnumMap = {
  MediaType.image: 'image',
  MediaType.video: 'video',
};
