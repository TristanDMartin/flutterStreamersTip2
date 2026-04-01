// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'comment.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Comment _$CommentFromJson(Map<String, dynamic> json) => _Comment(
      id: json['id'] as String,
      user:
          const UserConverter().fromJson(json['user'] as Map<String, dynamic>),
      text: json['text'] as String,
      timestamp: const TimestampConverter().fromJson(json['timestamp']),
      likeCount: (json['likeCount'] as num?)?.toInt() ?? 0,
      isLiked: json['isLiked'] as bool? ?? false,
      replies: (json['replies'] as List<dynamic>?)
          ?.map((e) => Comment.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$CommentToJson(_Comment instance) => <String, dynamic>{
      'id': instance.id,
      'user': const UserConverter().toJson(instance.user),
      'text': instance.text,
      'timestamp': const TimestampConverter().toJson(instance.timestamp),
      'likeCount': instance.likeCount,
      'isLiked': instance.isLiked,
      'replies': instance.replies,
    };
