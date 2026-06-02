import 'package:freezed_annotation/freezed_annotation.dart';

part 'scheduled_post.freezed.dart';
part 'scheduled_post.g.dart';

@freezed
sealed class ScheduledPost with _$ScheduledPost {
  const factory ScheduledPost({
    required String id,
    required String authorId,
    required PostStatus status,
    required String caption,
    @Default([]) List<String> tags,
    @Default(PostVisibility.public) PostVisibility visibility,
    @Default([]) List<PostMedia> media,
    @Default([]) List<PlatformConfig> platforms,
    PostSchedule? schedule,
    @Default({}) Map<String, dynamic> analyticsHints,
    String? idempotencyKey,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _ScheduledPost;

  factory ScheduledPost.fromJson(Map<String, dynamic> json) =>
      _$ScheduledPostFromJson(json);
}

@freezed
sealed class PostMedia with _$PostMedia {
  const factory PostMedia({
    required String id,
    required MediaType type,
    required String src,
    required double aspectRatio,
    int? durationMs,
    @Default([]) List<MediaVariant> variants,
  }) = _PostMedia;

  factory PostMedia.fromJson(Map<String, dynamic> json) =>
      _$PostMediaFromJson(json);
}

@freezed
sealed class MediaVariant with _$MediaVariant {
  const factory MediaVariant({
    required String platform,
    required String src,
    required double aspectRatio,
    int? durationMs,
    Map<String, dynamic>? metadata,
  }) = _MediaVariant;

  factory MediaVariant.fromJson(Map<String, dynamic> json) =>
      _$MediaVariantFromJson(json);
}

@freezed
sealed class PlatformConfig with _$PlatformConfig {
  const factory PlatformConfig({
    required String key,
    required bool enabled,
    Map<String, dynamic>? payload,
    PlatformStatus? status,
    String? error,
    DateTime? scheduledAtUtc,
  }) = _PlatformConfig;

  factory PlatformConfig.fromJson(Map<String, dynamic> json) =>
      _$PlatformConfigFromJson(json);
}

@freezed
sealed class PostSchedule with _$PostSchedule {
  const factory PostSchedule({
    required DateTime scheduledAtUtc,
    required String timezone,
    @Default({}) Map<String, PlatformSchedule> perPlatform,
    required DateTime createdAtUtc,
    required DateTime updatedAtUtc,
  }) = _PostSchedule;

  factory PostSchedule.fromJson(Map<String, dynamic> json) =>
      _$PostScheduleFromJson(json);
}

@freezed
sealed class PlatformSchedule with _$PlatformSchedule {
  const factory PlatformSchedule({
    required DateTime scheduledAtUtc,
    String? timezone,
  }) = _PlatformSchedule;

  factory PlatformSchedule.fromJson(Map<String, dynamic> json) =>
      _$PlatformScheduleFromJson(json);
}

enum PostStatus {
  @JsonValue('draft')
  draft,
  @JsonValue('scheduled')
  scheduled,
  @JsonValue('publishing')
  publishing,
  @JsonValue('published')
  published,
  @JsonValue('failed')
  failed,
  @JsonValue('canceled')
  canceled,
}

enum PostVisibility {
  @JsonValue('public')
  public,
  @JsonValue('private')
  private,
  @JsonValue('unlisted')
  unlisted,
}

enum MediaType {
  @JsonValue('image')
  image,
  @JsonValue('video')
  video,
  @JsonValue('gif')
  gif,
}

enum PlatformStatus {
  @JsonValue('pending')
  pending,
  @JsonValue('publishing')
  publishing,
  @JsonValue('published')
  published,
  @JsonValue('failed')
  failed,
  @JsonValue('needs_reauth')
  needsReauth,
  @JsonValue('canceled')
  canceled,
}

enum PlatformKey {
  @JsonValue('youtube')
  youtube,
  @JsonValue('tiktok')
  tiktok,
  @JsonValue('instagram')
  instagram,
  @JsonValue('x')
  x,
  @JsonValue('facebook')
  facebook,
  @JsonValue('linkedin')
  linkedin,
}

class TimezoneInfo {
  final String name;
  final String displayName;
  final int offsetMinutes;

  const TimezoneInfo({
    required this.name,
    required this.displayName,
    required this.offsetMinutes,
  });

  static const List<TimezoneInfo> commonTimezones = [
    TimezoneInfo(
        name: 'America/New_York',
        displayName: 'Eastern Time',
        offsetMinutes: -300),
    TimezoneInfo(
        name: 'America/Chicago',
        displayName: 'Central Time',
        offsetMinutes: -360),
    TimezoneInfo(
        name: 'America/Denver',
        displayName: 'Mountain Time',
        offsetMinutes: -420),
    TimezoneInfo(
        name: 'America/Los_Angeles',
        displayName: 'Pacific Time',
        offsetMinutes: -480),
    TimezoneInfo(
        name: 'Europe/London', displayName: 'London', offsetMinutes: 0),
    TimezoneInfo(name: 'Europe/Paris', displayName: 'Paris', offsetMinutes: 60),
    TimezoneInfo(name: 'Asia/Tokyo', displayName: 'Tokyo', offsetMinutes: 540),
    TimezoneInfo(
        name: 'Asia/Shanghai', displayName: 'Shanghai', offsetMinutes: 480),
    TimezoneInfo(
        name: 'Australia/Sydney', displayName: 'Sydney', offsetMinutes: 660),
  ];
}
