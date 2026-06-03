// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'platform.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Platform _$PlatformFromJson(Map<String, dynamic> json) => _Platform(
      id: json['id'] as String,
      type: platformTypeFromJson(json['type']),
      username: json['username'] as String,
      followers: (json['followers'] as num?)?.toInt() ?? 0,
      url: json['url'] as String?,
    );

Map<String, dynamic> _$PlatformToJson(_Platform instance) => <String, dynamic>{
      'id': instance.id,
      'type': platformTypeToJson(instance.type),
      'username': instance.username,
      'followers': instance.followers,
      'url': instance.url,
    };
