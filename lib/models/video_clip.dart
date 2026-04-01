import 'package:freezed_annotation/freezed_annotation.dart';

part 'video_clip.freezed.dart';

@freezed
sealed class VideoClip with _$VideoClip {
  const factory VideoClip({
    required String id,
    required String title,
    required String videoURL,
    String? thumbnailURL,
    @Default(0) int views,
    @Default(0) int likes,
    @Default(0) int comments,
    @Default('') String categoryId,
    @Default('') String description,
    required String creator,
    @Default(0.0) double duration,
    @Default([]) List<String> tags,
    @Default(0.0) double score,
  }) = _VideoClip;
}
