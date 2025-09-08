import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'platform.freezed.dart';
part 'platform.g.dart';

@freezed
class Platform with _$Platform {
  const factory Platform({
    required String id,
    required PlatformType type,
    required String username,
    @Default(0) int followers,
    String? url,
  }) = _Platform;

  factory Platform.fromJson(Map<String, dynamic> json) => _$PlatformFromJson(json);
}

enum PlatformType {
  twitch,
  youtube,
  kick,
  tiktok,
  facebook,
  bluesky,
  twitter,
  instagram,
  rednote,
  other;

  String get displayName {
    switch (this) {
      case PlatformType.twitch:
        return "Twitch";
      case PlatformType.kick:
        return "Kick";
      case PlatformType.tiktok:
        return "TikTok";
      case PlatformType.youtube:
        return "YouTube";
      case PlatformType.facebook:
        return "Facebook";
      case PlatformType.bluesky:
        return "BlueSky";
      case PlatformType.twitter:
        return "X";
      case PlatformType.instagram:
        return "Instagram";
      case PlatformType.rednote:
        return "Rednote";
      case PlatformType.other:
        return "Website";
    }
  }

  Color get color {
    switch (this) {
      case PlatformType.twitch:
        return Colors.purple;
      case PlatformType.kick:
        return Colors.green;
      case PlatformType.tiktok:
        return Colors.black;
      case PlatformType.youtube:
        return Colors.red;
      case PlatformType.facebook:
        return Colors.blue;
      case PlatformType.bluesky:
        return Colors.cyan;
      case PlatformType.twitter:
        return Colors.black;
      case PlatformType.instagram:
        return Colors.purple;
      case PlatformType.rednote:
        return Colors.red;
      case PlatformType.other:
        return Colors.grey;
    }
  }
}
