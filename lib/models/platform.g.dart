// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'platform.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$PlatformImpl _$$PlatformImplFromJson(Map<String, dynamic> json) =>
    _$PlatformImpl(
      id: json['id'] as String,
      type: $enumDecode(_$PlatformTypeEnumMap, json['type']),
      username: json['username'] as String,
      followers: (json['followers'] as num?)?.toInt() ?? 0,
      url: json['url'] as String?,
    );

Map<String, dynamic> _$$PlatformImplToJson(_$PlatformImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'type': _$PlatformTypeEnumMap[instance.type]!,
      'username': instance.username,
      'followers': instance.followers,
      'url': instance.url,
    };

const _$PlatformTypeEnumMap = {
  PlatformType.twitch: 'twitch',
  PlatformType.youtube: 'youtube',
  PlatformType.kick: 'kick',
  PlatformType.tiktok: 'tiktok',
  PlatformType.facebook: 'facebook',
  PlatformType.bluesky: 'bluesky',
  PlatformType.twitter: 'twitter',
  PlatformType.instagram: 'instagram',
  PlatformType.rednote: 'rednote',
  PlatformType.other: 'other',
};
