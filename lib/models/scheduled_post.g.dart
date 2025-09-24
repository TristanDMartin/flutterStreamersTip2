// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'scheduled_post.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ScheduledPostImpl _$$ScheduledPostImplFromJson(Map<String, dynamic> json) =>
    _$ScheduledPostImpl(
      id: json['id'] as String,
      authorId: json['authorId'] as String,
      status: $enumDecode(_$PostStatusEnumMap, json['status']),
      caption: json['caption'] as String,
      tags:
          (json['tags'] as List<dynamic>?)?.map((e) => e as String).toList() ??
              const [],
      visibility:
          $enumDecodeNullable(_$PostVisibilityEnumMap, json['visibility']) ??
              PostVisibility.public,
      media: (json['media'] as List<dynamic>?)
              ?.map((e) => PostMedia.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      platforms: (json['platforms'] as List<dynamic>?)
              ?.map((e) => PlatformConfig.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      schedule: PostSchedule.fromJson(json['schedule'] as Map<String, dynamic>),
      analyticsHints:
          json['analyticsHints'] as Map<String, dynamic>? ?? const {},
      idempotencyKey: json['idempotencyKey'] as String?,
      createdAtUtc: json['createdAtUtc'] == null
          ? null
          : DateTime.parse(json['createdAtUtc'] as String),
      updatedAtUtc: json['updatedAtUtc'] == null
          ? null
          : DateTime.parse(json['updatedAtUtc'] as String),
    );

Map<String, dynamic> _$$ScheduledPostImplToJson(_$ScheduledPostImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'authorId': instance.authorId,
      'status': _$PostStatusEnumMap[instance.status]!,
      'caption': instance.caption,
      'tags': instance.tags,
      'visibility': _$PostVisibilityEnumMap[instance.visibility]!,
      'media': instance.media,
      'platforms': instance.platforms,
      'schedule': instance.schedule,
      'analyticsHints': instance.analyticsHints,
      'idempotencyKey': instance.idempotencyKey,
      'createdAtUtc': instance.createdAtUtc?.toIso8601String(),
      'updatedAtUtc': instance.updatedAtUtc?.toIso8601String(),
    };

const _$PostStatusEnumMap = {
  PostStatus.draft: 'draft',
  PostStatus.scheduled: 'scheduled',
  PostStatus.publishing: 'publishing',
  PostStatus.published: 'published',
  PostStatus.failed: 'failed',
  PostStatus.canceled: 'canceled',
};

const _$PostVisibilityEnumMap = {
  PostVisibility.public: 'public',
  PostVisibility.private: 'private',
  PostVisibility.unlisted: 'unlisted',
};

_$PostMediaImpl _$$PostMediaImplFromJson(Map<String, dynamic> json) =>
    _$PostMediaImpl(
      id: json['id'] as String,
      type: $enumDecode(_$MediaTypeEnumMap, json['type']),
      src: json['src'] as String,
      aspectRatio: (json['aspectRatio'] as num).toDouble(),
      durationMs: (json['durationMs'] as num?)?.toInt(),
      variants: (json['variants'] as List<dynamic>?)
              ?.map((e) => MediaVariant.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );

Map<String, dynamic> _$$PostMediaImplToJson(_$PostMediaImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'type': _$MediaTypeEnumMap[instance.type]!,
      'src': instance.src,
      'aspectRatio': instance.aspectRatio,
      'durationMs': instance.durationMs,
      'variants': instance.variants,
    };

const _$MediaTypeEnumMap = {
  MediaType.image: 'image',
  MediaType.video: 'video',
  MediaType.gif: 'gif',
};

_$MediaVariantImpl _$$MediaVariantImplFromJson(Map<String, dynamic> json) =>
    _$MediaVariantImpl(
      platform: json['platform'] as String,
      src: json['src'] as String,
      aspectRatio: (json['aspectRatio'] as num).toDouble(),
      durationMs: (json['durationMs'] as num?)?.toInt(),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );

Map<String, dynamic> _$$MediaVariantImplToJson(_$MediaVariantImpl instance) =>
    <String, dynamic>{
      'platform': instance.platform,
      'src': instance.src,
      'aspectRatio': instance.aspectRatio,
      'durationMs': instance.durationMs,
      'metadata': instance.metadata,
    };

_$PlatformConfigImpl _$$PlatformConfigImplFromJson(Map<String, dynamic> json) =>
    _$PlatformConfigImpl(
      key: json['key'] as String,
      enabled: json['enabled'] as bool,
      payload: json['payload'] as Map<String, dynamic>?,
      status: $enumDecodeNullable(_$PlatformStatusEnumMap, json['status']),
      error: json['error'] as String?,
      scheduledAtUtc: json['scheduledAtUtc'] == null
          ? null
          : DateTime.parse(json['scheduledAtUtc'] as String),
    );

Map<String, dynamic> _$$PlatformConfigImplToJson(
        _$PlatformConfigImpl instance) =>
    <String, dynamic>{
      'key': instance.key,
      'enabled': instance.enabled,
      'payload': instance.payload,
      'status': _$PlatformStatusEnumMap[instance.status],
      'error': instance.error,
      'scheduledAtUtc': instance.scheduledAtUtc?.toIso8601String(),
    };

const _$PlatformStatusEnumMap = {
  PlatformStatus.pending: 'pending',
  PlatformStatus.publishing: 'publishing',
  PlatformStatus.published: 'published',
  PlatformStatus.failed: 'failed',
  PlatformStatus.needsReauth: 'needs_reauth',
  PlatformStatus.canceled: 'canceled',
};

_$PostScheduleImpl _$$PostScheduleImplFromJson(Map<String, dynamic> json) =>
    _$PostScheduleImpl(
      scheduledAtUtc: DateTime.parse(json['scheduledAtUtc'] as String),
      timezone: json['timezone'] as String,
      perPlatform: (json['perPlatform'] as Map<String, dynamic>?)?.map(
            (k, e) => MapEntry(
                k, PlatformSchedule.fromJson(e as Map<String, dynamic>)),
          ) ??
          const {},
      createdAtUtc: DateTime.parse(json['createdAtUtc'] as String),
      updatedAtUtc: DateTime.parse(json['updatedAtUtc'] as String),
    );

Map<String, dynamic> _$$PostScheduleImplToJson(_$PostScheduleImpl instance) =>
    <String, dynamic>{
      'scheduledAtUtc': instance.scheduledAtUtc.toIso8601String(),
      'timezone': instance.timezone,
      'perPlatform': instance.perPlatform,
      'createdAtUtc': instance.createdAtUtc.toIso8601String(),
      'updatedAtUtc': instance.updatedAtUtc.toIso8601String(),
    };

_$PlatformScheduleImpl _$$PlatformScheduleImplFromJson(
        Map<String, dynamic> json) =>
    _$PlatformScheduleImpl(
      scheduledAtUtc: DateTime.parse(json['scheduledAtUtc'] as String),
      timezone: json['timezone'] as String?,
    );

Map<String, dynamic> _$$PlatformScheduleImplToJson(
        _$PlatformScheduleImpl instance) =>
    <String, dynamic>{
      'scheduledAtUtc': instance.scheduledAtUtc.toIso8601String(),
      'timezone': instance.timezone,
    };
