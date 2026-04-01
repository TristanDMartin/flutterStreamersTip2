// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'connection_lite.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ConnectionLite _$ConnectionLiteFromJson(Map<String, dynamic> json) =>
    _ConnectionLite(
      userId: json['userId'] as String,
      handle: json['handle'] as String,
      displayName: json['displayName'] as String,
      avatarUrl: json['avatarUrl'] as String,
      isOnline: json['isOnline'] as bool? ?? false,
      lastInteractedAt: (json['lastInteractedAt'] as num?)?.toInt(),
      canDM: json['canDM'] as bool? ?? true,
      rankingScore: (json['rankingScore'] as num?)?.toDouble() ?? 0.0,
    );

Map<String, dynamic> _$ConnectionLiteToJson(_ConnectionLite instance) =>
    <String, dynamic>{
      'userId': instance.userId,
      'handle': instance.handle,
      'displayName': instance.displayName,
      'avatarUrl': instance.avatarUrl,
      'isOnline': instance.isOnline,
      'lastInteractedAt': instance.lastInteractedAt,
      'canDM': instance.canDM,
      'rankingScore': instance.rankingScore,
    };
