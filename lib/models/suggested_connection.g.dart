// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'suggested_connection.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_SuggestedConnection _$SuggestedConnectionFromJson(Map<String, dynamic> json) =>
    _SuggestedConnection(
      id: json['id'] as String,
      username: json['username'] as String,
      avatarName: json['avatarName'] as String,
    );

Map<String, dynamic> _$SuggestedConnectionToJson(
        _SuggestedConnection instance) =>
    <String, dynamic>{
      'id': instance.id,
      'username': instance.username,
      'avatarName': instance.avatarName,
    };
