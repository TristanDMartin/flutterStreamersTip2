// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'saved_account.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$SavedAccountImpl _$$SavedAccountImplFromJson(Map<String, dynamic> json) =>
    _$SavedAccountImpl(
      id: json['id'] as String,
      userId: json['userId'] as String,
      username: json['username'] as String,
      displayName: json['displayName'] as String,
      email: json['email'] as String?,
      avatarURL: json['avatarURL'] as String?,
      lastLoginDate: DateTime.parse(json['lastLoginDate'] as String),
    );

Map<String, dynamic> _$$SavedAccountImplToJson(_$SavedAccountImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'userId': instance.userId,
      'username': instance.username,
      'displayName': instance.displayName,
      'email': instance.email,
      'avatarURL': instance.avatarURL,
      'lastLoginDate': instance.lastLoginDate.toIso8601String(),
    };
