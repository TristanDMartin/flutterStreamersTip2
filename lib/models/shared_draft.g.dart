// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'shared_draft.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$SharedDraftImpl _$$SharedDraftImplFromJson(Map<String, dynamic> json) =>
    _$SharedDraftImpl(
      id: json['id'] as String,
      draftId: json['draftId'] as String,
      senderId: json['senderId'] as String,
      receiverId: json['receiverId'] as String,
      senderName: json['senderName'] as String,
      senderAvatar: json['senderAvatar'] as String,
      draftTitle: json['draftTitle'] as String,
      draftThumbnailUrl: json['draftThumbnailUrl'] as String,
      draftDuration: (json['draftDuration'] as num).toInt(),
      sharedAt: DateTime.parse(json['sharedAt'] as String),
      status: $enumDecode(_$SharedDraftStatusEnumMap, json['status']),
      message: json['message'] as String?,
      viewedAt: json['viewedAt'] == null
          ? null
          : DateTime.parse(json['viewedAt'] as String),
    );

Map<String, dynamic> _$$SharedDraftImplToJson(_$SharedDraftImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'draftId': instance.draftId,
      'senderId': instance.senderId,
      'receiverId': instance.receiverId,
      'senderName': instance.senderName,
      'senderAvatar': instance.senderAvatar,
      'draftTitle': instance.draftTitle,
      'draftThumbnailUrl': instance.draftThumbnailUrl,
      'draftDuration': instance.draftDuration,
      'sharedAt': instance.sharedAt.toIso8601String(),
      'status': _$SharedDraftStatusEnumMap[instance.status]!,
      'message': instance.message,
      'viewedAt': instance.viewedAt?.toIso8601String(),
    };

const _$SharedDraftStatusEnumMap = {
  SharedDraftStatus.pending: 'pending',
  SharedDraftStatus.delivered: 'delivered',
  SharedDraftStatus.viewed: 'viewed',
  SharedDraftStatus.declined: 'declined',
};
