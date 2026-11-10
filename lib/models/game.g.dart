// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'game.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Game _$GameFromJson(Map<String, dynamic> json) => _Game(
      id: json['id'] as String,
      title: json['title'] as String,
      artworkUrl: json['artworkUrl'] as String,
      provider: json['provider'] as String,
      providerGameId: json['providerGameId'] as String,
      slug: json['slug'] as String,
      clipCount: (json['clipCount'] as num?)?.toInt() ?? 0,
      followerCount: (json['followerCount'] as num?)?.toInt() ?? 0,
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.parse(json['updatedAt'] as String),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );

Map<String, dynamic> _$GameToJson(_Game instance) => <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'artworkUrl': instance.artworkUrl,
      'provider': instance.provider,
      'providerGameId': instance.providerGameId,
      'slug': instance.slug,
      'clipCount': instance.clipCount,
      'followerCount': instance.followerCount,
      'updatedAt': instance.updatedAt?.toIso8601String(),
      'metadata': instance.metadata,
    };
