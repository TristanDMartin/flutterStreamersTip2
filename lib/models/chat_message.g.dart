// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_message.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ChatMessageImpl _$$ChatMessageImplFromJson(Map<String, dynamic> json) =>
    _$ChatMessageImpl(
      id: json['id'] as String,
      sender: const UserConverter()
          .fromJson(json['sender'] as Map<String, dynamic>),
      content: MessageContent.fromJson(json['content'] as Map<String, dynamic>),
      timestamp: const TimestampConverter().fromJson(json['timestamp']),
      isFromCurrentUser: json['isFromCurrentUser'] as bool? ?? false,
      isRead: json['isRead'] as bool? ?? false,
    );

Map<String, dynamic> _$$ChatMessageImplToJson(_$ChatMessageImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'sender': const UserConverter().toJson(instance.sender),
      'content': instance.content,
      'timestamp': const TimestampConverter().toJson(instance.timestamp),
      'isFromCurrentUser': instance.isFromCurrentUser,
      'isRead': instance.isRead,
    };

_$TextMessageImpl _$$TextMessageImplFromJson(Map<String, dynamic> json) =>
    _$TextMessageImpl(
      json['text'] as String,
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$$TextMessageImplToJson(_$TextMessageImpl instance) =>
    <String, dynamic>{
      'text': instance.text,
      'runtimeType': instance.$type,
    };

_$VideoMessageContentImpl _$$VideoMessageContentImplFromJson(
        Map<String, dynamic> json) =>
    _$VideoMessageContentImpl(
      VideoMessage.fromJson(json['video'] as Map<String, dynamic>),
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$$VideoMessageContentImplToJson(
        _$VideoMessageContentImpl instance) =>
    <String, dynamic>{
      'video': instance.video,
      'runtimeType': instance.$type,
    };

_$ReactionMessageImpl _$$ReactionMessageImplFromJson(
        Map<String, dynamic> json) =>
    _$ReactionMessageImpl(
      json['emoji'] as String,
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$$ReactionMessageImplToJson(
        _$ReactionMessageImpl instance) =>
    <String, dynamic>{
      'emoji': instance.emoji,
      'runtimeType': instance.$type,
    };

_$VideoMessageImpl _$$VideoMessageImplFromJson(Map<String, dynamic> json) =>
    _$VideoMessageImpl(
      videoURL: json['videoURL'] as String,
      thumbnailURL: json['thumbnailURL'] as String?,
      caption: json['caption'] as String?,
      duration: (json['duration'] as num).toDouble(),
    );

Map<String, dynamic> _$$VideoMessageImplToJson(_$VideoMessageImpl instance) =>
    <String, dynamic>{
      'videoURL': instance.videoURL,
      'thumbnailURL': instance.thumbnailURL,
      'caption': instance.caption,
      'duration': instance.duration,
    };
