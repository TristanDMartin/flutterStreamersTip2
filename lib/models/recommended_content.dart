import 'package:freezed_annotation/freezed_annotation.dart';

part 'recommended_content.freezed.dart';
part 'recommended_content.g.dart';

@freezed
class RecommendedContent with _$RecommendedContent {
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
      id: 'live-events',
      title: 'Live Events',
      creator: 'StreamersTip',
      description: 'Find upcoming tournaments, community nights, and collabs.',
      thumbnailURL: null,
      views: 0,
      duration: '',
      url: 'https://streamerstip.com/live-events',
    ),
  ];
}
