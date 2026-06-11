import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'platform.freezed.dart';
part 'platform.g.dart';

PlatformType platformTypeFromJson(Object? json) {
  final String raw = json?.toString() ?? 'other';
  if (raw == 'twitter') {
    return PlatformType.x;
  }
  return PlatformType.values.firstWhere(
    (PlatformType e) => e.name == raw,
    orElse: () => PlatformType.other,
  );
}

String platformTypeToJson(PlatformType type) => type.name;

@freezed
sealed class Platform with _$Platform {
  const factory Platform({
    required String id,
    // ignore: invalid_annotation_target
    @JsonKey(fromJson: platformTypeFromJson, toJson: platformTypeToJson)
    required PlatformType type,
    required String username,
    @Default(0) int followers,
    String? url,
  }) = _Platform;

  factory Platform.fromJson(Map<String, dynamic> json) =>
      _$PlatformFromJson(json);
}

enum PlatformType {
  twitch,
  youtube,
  kick,
  tiktok,
  instagram,
  x,
  discord,
  patreon,
  onlyfans,
  other;

  String get displayName {
    switch (this) {
      case PlatformType.twitch:
        return 'Twitch';
      case PlatformType.kick:
        return 'Kick';
      case PlatformType.tiktok:
        return 'TikTok';
      case PlatformType.youtube:
        return 'YouTube';
      case PlatformType.instagram:
        return 'Instagram';
      case PlatformType.x:
        return 'X';
      case PlatformType.discord:
        return 'Discord';
      case PlatformType.patreon:
        return 'Patreon';
      case PlatformType.onlyfans:
        return 'OnlyFans';
      case PlatformType.other:
        return 'Other';
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
      case PlatformType.instagram:
        return Colors.purple;
      case PlatformType.x:
        return Colors.black;
      case PlatformType.discord:
        return const Color(0xFF5865F2);
      case PlatformType.patreon:
        return const Color(0xFFFF424D);
      case PlatformType.onlyfans:
        return const Color(0xFF00AFF0);
      case PlatformType.other:
        return Colors.grey;
    }
  }
}
