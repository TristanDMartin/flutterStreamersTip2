import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:json_annotation/json_annotation.dart';
import 'user.dart' as app;

class TimestampConverter implements JsonConverter<DateTime, Object?> {
  const TimestampConverter();
  @override
  DateTime fromJson(Object? json) {
    if (json is Timestamp) return json.toDate();
    if (json is String) return DateTime.tryParse(json) ?? DateTime.now();
    return DateTime.now();
  }

  @override
  Object toJson(DateTime object) => Timestamp.fromDate(object);
}

class ColorConverter implements JsonConverter<Color, int> {
  const ColorConverter();
  @override
  Color fromJson(int json) => Color(json);
  @override
  int toJson(Color object) => object.toARGB32();
}

class UserConverter implements JsonConverter<app.User, Map<String, dynamic>> {
  const UserConverter();
  @override
  app.User fromJson(Map<String, dynamic> json) => app.User(
        id: (json['id'] ?? '').toString(),
        username: (json['username'] ?? '').toString(),
        displayName: (json['displayName'] ?? '').toString(),
        bio: json['bio'] as String?,
        // Handle both avatarURL and avatarUrl, and null/empty values
        avatarURL: _extractAvatarUrl(json),
        onlineStatus: (json['onlineStatus'] ?? 'online').toString(),
        hashtags:
            List<String>.from((json['hashtags'] as List?) ?? const <String>[]),
        postCount: (json['postCount'] ?? 0) as int,
        followerCount: (json['followerCount'] ?? 0) as int,
        followingCount: (json['followingCount'] ?? 0) as int,
      );

  /// Extract avatar URL handling all possible field names and null/empty values
  String? _extractAvatarUrl(Map<String, dynamic> json) {
    // Try avatarURL first (uppercase)
    final url1 = json['avatarURL'] as String?;
    if (url1 != null && url1.isNotEmpty && url1 != 'null') {
      return url1;
    }

    // Try avatarUrl (lowercase)
    final url2 = json['avatarUrl'] as String?;
    if (url2 != null && url2.isNotEmpty && url2 != 'null') {
      return url2;
    }

    // Return null if no valid URL found
    return null;
  }

  @override
  Map<String, dynamic> toJson(app.User user) => {
        'id': user.id,
        'username': user.username,
        'displayName': user.displayName,
        'bio': user.bio,
        'avatarURL': user.avatarURL,
        'onlineStatus': user.onlineStatus,
        'hashtags': user.hashtags,
        'postCount': user.postCount,
        'followerCount': user.followerCount,
        'followingCount': user.followingCount,
      };
}
