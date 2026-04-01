// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'share_payload.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_SharePayload _$SharePayloadFromJson(Map<String, dynamic> json) =>
    _SharePayload(
      videoId: json['videoId'] as String,
      links: ShareLinks.fromJson(json['links'] as Map<String, dynamic>),
      permissions: SharePermissions.fromJson(
          json['permissions'] as Map<String, dynamic>),
      metadata:
          ShareMetadata.fromJson(json['metadata'] as Map<String, dynamic>),
      trackingToken: json['trackingToken'] as String?,
      platformUsageRanking:
          (json['platformUsageRanking'] as Map<String, dynamic>?)?.map(
                (k, e) => MapEntry(k, (e as num).toInt()),
              ) ??
              const {},
    );

Map<String, dynamic> _$SharePayloadToJson(_SharePayload instance) =>
    <String, dynamic>{
      'videoId': instance.videoId,
      'links': instance.links,
      'permissions': instance.permissions,
      'metadata': instance.metadata,
      'trackingToken': instance.trackingToken,
      'platformUsageRanking': instance.platformUsageRanking,
    };

_ShareLinks _$ShareLinksFromJson(Map<String, dynamic> json) => _ShareLinks(
      webShareUrl: json['webShareUrl'] as String,
      deepLink: json['deepLink'] as String?,
      downloadUrl: json['downloadUrl'] as String?,
      embedCode: json['embedCode'] as String?,
    );

Map<String, dynamic> _$ShareLinksToJson(_ShareLinks instance) =>
    <String, dynamic>{
      'webShareUrl': instance.webShareUrl,
      'deepLink': instance.deepLink,
      'downloadUrl': instance.downloadUrl,
      'embedCode': instance.embedCode,
    };

_SharePermissions _$SharePermissionsFromJson(Map<String, dynamic> json) =>
    _SharePermissions(
      canShare: json['canShare'] as bool? ?? true,
      canDownload: json['canDownload'] as bool? ?? true,
      canDuet: json['canDuet'] as bool? ?? true,
      canRemix: json['canRemix'] as bool? ?? true,
      canRepost: json['canRepost'] as bool? ?? true,
      restrictionReason: json['restrictionReason'] as String?,
    );

Map<String, dynamic> _$SharePermissionsToJson(_SharePermissions instance) =>
    <String, dynamic>{
      'canShare': instance.canShare,
      'canDownload': instance.canDownload,
      'canDuet': instance.canDuet,
      'canRemix': instance.canRemix,
      'canRepost': instance.canRepost,
      'restrictionReason': instance.restrictionReason,
    };

_ShareMetadata _$ShareMetadataFromJson(Map<String, dynamic> json) =>
    _ShareMetadata(
      creatorUsername: json['creatorUsername'] as String,
      creatorDisplayName: json['creatorDisplayName'] as String,
      caption: json['caption'] as String?,
      thumbnailUrl: json['thumbnailUrl'] as String?,
      hashtags: (json['hashtags'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.parse(json['createdAt'] as String),
    );

Map<String, dynamic> _$ShareMetadataToJson(_ShareMetadata instance) =>
    <String, dynamic>{
      'creatorUsername': instance.creatorUsername,
      'creatorDisplayName': instance.creatorDisplayName,
      'caption': instance.caption,
      'thumbnailUrl': instance.thumbnailUrl,
      'hashtags': instance.hashtags,
      'createdAt': instance.createdAt?.toIso8601String(),
    };
