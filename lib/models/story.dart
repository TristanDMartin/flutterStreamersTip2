import 'package:flutter/foundation.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'story.freezed.dart';
part 'story.g.dart';

@freezed
class Story with _$Story {
  const factory Story({
    required String id,
    required String creatorId,
    required String creatorName,
    String? creatorAvatarURL,
    required String mediaURL,
    required MediaType mediaType,
    required DateTime timestamp,
    required double duration,
    @Default(false) bool isViewed,
  }) = _Story;

  factory Story.fromJson(Map<String, dynamic> json) => _$StoryFromJson(json);
}

enum MediaType {
  image,
  video;

  String get rawValue {
    switch (this) {
      case MediaType.image:
        return 'image';
      case MediaType.video:
        return 'video';
    }
  }

  static MediaType fromString(String value) {
    switch (value) {
      case 'image':
        return MediaType.image;
      case 'video':
        return MediaType.video;
      default:
        return MediaType.image; // Default fallback
    }
  }
}

// Extension for sample data
extension StoryExtension on Story {
  static List<Story> get samples => [
    Story(
      id: '1',
      creatorId: '1',
      creatorName: 'GamingPro',
      creatorAvatarURL: null,
      mediaURL: 'https://example.com/story1.jpg',
      mediaType: MediaType.image,
      timestamp: DateTime.now(),
      duration: 5.0,
      isViewed: false,
    ),
    Story(
      id: '2',
      creatorId: '2',
      creatorName: 'ArtStreamer',
      creatorAvatarURL: null,
      mediaURL: 'https://example.com/story2.jpg',
      mediaType: MediaType.image,
      timestamp: DateTime.now().subtract(const Duration(hours: 1)),
      duration: 3.0,
      isViewed: true,
    ),
    Story(
      id: '3',
      creatorId: '3',
      creatorName: 'MusicLive',
      creatorAvatarURL: null,
      mediaURL: 'https://example.com/story3.jpg',
      mediaType: MediaType.video,
      timestamp: DateTime.now().subtract(const Duration(hours: 2)),
      duration: 10.0,
      isViewed: false,
    ),
    Story(
      id: '4',
      creatorId: '4',
      creatorName: 'TechReview',
      creatorAvatarURL: null,
      mediaURL: 'https://example.com/story4.jpg',
      mediaType: MediaType.image,
      timestamp: DateTime.now().subtract(const Duration(hours: 3)),
      duration: 4.0,
      isViewed: false,
    ),
  ];
}
