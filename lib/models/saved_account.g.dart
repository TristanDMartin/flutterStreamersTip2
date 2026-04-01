// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'saved_account.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_SavedAccount _$SavedAccountFromJson(Map<String, dynamic> json) =>
    _SavedAccount(
      id: json['id'] as String,
      userId: json['userId'] as String,
      username: json['username'] as String,
      displayName: json['displayName'] as String,
      email: json['email'] as String?,
      avatarURL: json['avatarURL'] as String?,
      lastLoginDate: DateTime.parse(json['lastLoginDate'] as String),
    );

Map<String, dynamic> _$SavedAccountToJson(_SavedAccount instance) =>
    <String, dynamic>{
      'id': instance.id,
      'userId': instance.userId,
      'username': instance.username,
      'displayName': instance.displayName,
      'email': instance.email,
      'avatarURL': instance.avatarURL,
      'lastLoginDate': instance.lastLoginDate.toIso8601String(),
    };
