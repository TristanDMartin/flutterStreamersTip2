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
    };

Json? _$JsonConverterToJson<Json, Value>(
  Value? value,
  Json? Function(Value value) toJson,
) =>
    value == null ? null : toJson(value);
