import 'package:freezed_annotation/freezed_annotation.dart';

part 'recommended_content.freezed.dart';
part 'recommended_content.g.dart';

@freezed
sealed class RecommendedContent with _$RecommendedContent {
  const factory RecommendedContent({
    required String id,
    required String title,
    required String creator,
    required String description,
    String? thumbnailURL,
    @Default(0) int views,
    @Default('') String duration,
    String? url,
  }) = _RecommendedContent;

  factory RecommendedContent.fromJson(Map<String, dynamic> json) => _$RecommendedContentFromJson(json);
}

extension RecommendedContentExtension on RecommendedContent {
  static List<RecommendedContent> get samples => [
    const RecommendedContent(
      id: 'creator-tools',
      title: 'Creator Tools',
      creator: 'StreamersTip',
      description: 'Discover widgets, overlays, and software to upgrade your stream.',
      thumbnailURL: null,
      views: 0,
      duration: '',
      url: 'https://streamerstip.com/creator-tools',
    ),
    const RecommendedContent(
      id: 'academy',
      title: 'Academy',
      creator: 'StreamersTip',
      description: 'Learn how to grow your audience with step-by-step tutorials.',
      thumbnailURL: null,
      views: 0,
      duration: '',
      url: 'https://streamerstip.com/academy',
    ),
    const RecommendedContent(
      id: 'peripherals',
      title: 'Peripherals',
      creator: 'StreamersTip',
      description:
          'Cameras, mics, lighting, capture cards, and gear to level up your setup.',
      thumbnailURL: null,
      views: 0,
      duration: '',
      url: 'https://www.streamerstip.com/peripherals',
    ),
  ];
}
