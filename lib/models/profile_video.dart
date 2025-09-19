import 'package:freezed_annotation/freezed_annotation.dart';
import 'user.dart';

part 'profile_video.freezed.dart';

/// Model for videos in a user's profile/upload history
/// Used specifically for insights and profile video feeds
@freezed
class ProfileVideo with _$ProfileVideo {
  const factory ProfileVideo({
    required String id,
    required User creator,
    required String videoURL,
    String? thumbnailURL,
    @Default(0.0) double duration, // Duration in seconds
    @Default('') String caption,
    required DateTime createdAt, // When the video was posted
    @Default(0) int likes,
    @Default(0) int comments,
    @Default(0) int views,
    @Default(0) int shares,
    @Default(false) bool isLiked,
    @Default(false) bool isFavorited,
    @Default(false) bool isDraft,
    @Default(0.0) double mlScore,
    @Default('') String categoryId,
  }) = _ProfileVideo;
}
