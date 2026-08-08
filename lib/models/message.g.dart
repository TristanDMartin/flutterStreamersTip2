// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'message.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Message _$MessageFromJson(Map<String, dynamic> json) => _Message(
      id: json['id'] as String?,
      chatId: json['chatId'] as String?,
      text: json['text'] as String? ?? '',
      from: json['from'] as String? ?? '',
      to: json['to'] as String? ?? '',
      timestamp: const TimestampConverter().fromJson(json['timestamp']),
      isRead: json['isRead'] as bool? ?? false,
      recipients: (json['recipients'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      readBy: (json['readBy'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      gifUrl: json['gifUrl'] as String?,
      messageType: json['messageType'] as String? ?? 'text',
      isDeviceGif: json['isDeviceGif'] as bool? ?? false,
      videoId: json['videoId'] as String?,
      shareToken: json['shareToken'] as String?,
      videoThumbnailUrl: json['videoThumbnailUrl'] as String?,
      videoTitle: json['videoTitle'] as String?,
      replyToMessageId: json['replyToMessageId'] as String?,
      replyToSenderId: json['replyToSenderId'] as String?,
      replyToSenderName: json['replyToSenderName'] as String?,
      replyToType: json['replyToType'] as String?,
      replyPreviewText: json['replyPreviewText'] as String?,
      replyThumbnailUrl: json['replyThumbnailUrl'] as String?,
      replyVideoId: json['replyVideoId'] as String?,
      deletedForEveryone: json['deletedForEveryone'] as bool? ?? false,
      reactions: json['reactions'] as Map<String, dynamic>? ??
          const <String, dynamic>{},
      edited: json['edited'] as bool? ?? false,
      editedAt: const TimestampConverter().fromJson(json['editedAt']),
    );

Map<String, dynamic> _$MessageToJson(_Message instance) => <String, dynamic>{
      'id': instance.id,
      'chatId': instance.chatId,
      'text': instance.text,
      'from': instance.from,
      'to': instance.to,
      'timestamp': _$JsonConverterToJson<Object?, DateTime>(
          instance.timestamp, const TimestampConverter().toJson),
      'isRead': instance.isRead,
      'recipients': instance.recipients,
      'readBy': instance.readBy,
      'gifUrl': instance.gifUrl,
      'messageType': instance.messageType,
      'isDeviceGif': instance.isDeviceGif,
      'videoId': instance.videoId,
      'shareToken': instance.shareToken,
      'videoThumbnailUrl': instance.videoThumbnailUrl,
      'videoTitle': instance.videoTitle,
      'replyToMessageId': instance.replyToMessageId,
      'replyToSenderId': instance.replyToSenderId,
      'replyToSenderName': instance.replyToSenderName,
      'replyToType': instance.replyToType,
      'replyPreviewText': instance.replyPreviewText,
      'replyThumbnailUrl': instance.replyThumbnailUrl,
      'replyVideoId': instance.replyVideoId,
      'deletedForEveryone': instance.deletedForEveryone,
      'reactions': instance.reactions,
      'edited': instance.edited,
      'editedAt': _$JsonConverterToJson<Object?, DateTime>(
          instance.editedAt, const TimestampConverter().toJson),
    };

Json? _$JsonConverterToJson<Json, Value>(
  Value? value,
  Json? Function(Value value) toJson,
) =>
    value == null ? null : toJson(value);
