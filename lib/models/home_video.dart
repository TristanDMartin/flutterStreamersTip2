import 'package:freezed_annotation/freezed_annotation.dart';
import 'user.dart';

part 'home_video.freezed.dart';

@freezed
class HomeVideo with _$HomeVideo {
  const factory HomeVideo({
    required String id,
    required User creator,
    required String videoURL,
    String? thumbnailURL,
    @Default(0) int likes,
    @Default(0) int comments,
    @Default(0) int views,
    @Default('') String caption,
    @Default(false) bool isLiked,
    @Default(false) bool isFavorited,
    @Default(false) bool isDraft,
    @Default(0.0) double mlScore,
    @Default('') String categoryId,
  }) = _HomeVideo;
}
