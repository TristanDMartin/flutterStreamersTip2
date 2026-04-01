// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'connection.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Connection _$ConnectionFromJson(Map<String, dynamic> json) => _Connection(
      id: json['id'] as String,
      displayName: json['displayName'] as String,
      username: json['username'] as String,
      avatarUrl: json['avatarUrl'] as String,
      isOnline: json['isOnline'] as bool,
      lastSeen: DateTime.parse(json['lastSeen'] as String),
    );

Map<String, dynamic> _$ConnectionToJson(_Connection instance) =>
    <String, dynamic>{
      'id': instance.id,
      'displayName': instance.displayName,
      'username': instance.username,
      'avatarUrl': instance.avatarUrl,
      'isOnline': instance.isOnline,
      'lastSeen': instance.lastSeen.toIso8601String(),
    };
