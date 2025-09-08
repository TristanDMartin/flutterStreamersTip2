// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'recommended_content.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$RecommendedContentImpl _$$RecommendedContentImplFromJson(
        Map<String, dynamic> json) =>
    _$RecommendedContentImpl(
      id: json['id'] as String,
      title: json['title'] as String,
      creator: json['creator'] as String,
      description: json['description'] as String,
      thumbnailURL: json['thumbnailURL'] as String?,
      views: (json['views'] as num?)?.toInt() ?? 0,
      duration: json['duration'] as String? ?? '',
      url: json['url'] as String?,
    );

Map<String, dynamic> _$$RecommendedContentImplToJson(
        _$RecommendedContentImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'creator': instance.creator,
      'description': instance.description,
      'thumbnailURL': instance.thumbnailURL,
      'views': instance.views,
      'duration': instance.duration,
      'url': instance.url,
    };
