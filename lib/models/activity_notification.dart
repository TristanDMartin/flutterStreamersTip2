import 'package:freezed_annotation/freezed_annotation.dart';
import 'user.dart';
import 'json_converters.dart';

part 'activity_notification.freezed.dart';
part 'activity_notification.g.dart';

enum ActivityNotificationType {
  like,
  follow,
  comment,
  tag,
  mention,
  commentReply,
  newVideo,
  milestone,
  liveStream,
  adminBroadcast,
}

@freezed
sealed class ActivityNotification with _$ActivityNotification {
  const factory ActivityNotification({
    required String id,
    required ActivityNotificationType type,
    @UserConverter() required User user,
    @TimestampConverter() required DateTime timestamp,
    String? postThumbnailUrl,
    String? commentText,
    @Default('pending') String status,
    String? videoId,
    String? chatId,
    String? milestoneType,
    int? milestoneValue,
    String? parentCommentId,
  }) = _ActivityNotification;

  factory ActivityNotification.fromJson(Map<String, dynamic> json) =>
      _$ActivityNotificationFromJson(json);
}

extension ActivityNotificationExtension on ActivityNotification {
  static List<ActivityNotification> get sampleData => [
        // Today
        ActivityNotification(
          id: '1',
          type: ActivityNotificationType.like,
          user: const User(
            id: '1',
            displayName: 'GamingPro',
            username: 'GamingPro',
            bio: 'Gaming streamer',
            avatarURL: null,
            onlineStatus: 'online',
            hashtags: ['gaming'],
            followerCount: 150000,
            followingCount: 500,
            postCount: 120,
          ),
          timestamp: DateTime.now(),
          postThumbnailUrl: 'https://example.com/post1.jpg',
          status: 'delivered',
          videoId: 'video1',
        ),
        ActivityNotification(
          id: '2',
          type: ActivityNotificationType.follow,
          user: const User(
            id: '2',
            displayName: 'ArtStreamer',
            username: 'ArtStreamer',
            bio: 'Digital artist',
            avatarURL: null,
            onlineStatus: 'offline',
            hashtags: ['art'],
            followerCount: 75000,
            followingCount: 200,
            postCount: 85,
          ),
          timestamp: DateTime.now().subtract(const Duration(hours: 2)),
          postThumbnailUrl: null,
          status: 'delivered',
        ),
        ActivityNotification(
          id: '3',
          type: ActivityNotificationType.tag,
          user: const User(
            id: '3',
            displayName: 'MusicLive',
            username: 'MusicLive',
            bio: 'Music creator',
            avatarURL: null,
            onlineStatus: 'online',
            hashtags: ['music'],
            followerCount: 200000,
            followingCount: 800,
            postCount: 300,
          ),
          timestamp: DateTime.now().subtract(const Duration(hours: 1)),
          postThumbnailUrl: 'https://example.com/tagged-video.jpg',
          status: 'delivered',
          videoId: 'video2',
        ),

        // Yesterday
        ActivityNotification(
          id: '4',
          type: ActivityNotificationType.comment,
          user: const User(
            id: '4',
            displayName: 'TechReview',
            username: 'TechReview',
            bio: 'Tech reviewer',
            avatarURL: null,
            onlineStatus: 'online',
            hashtags: ['tech'],
            followerCount: 120000,
            followingCount: 150,
            postCount: 95,
          ),
          timestamp: DateTime.now().subtract(const Duration(hours: 25)),
          postThumbnailUrl: 'https://example.com/post2.jpg',
          commentText: 'Great video! 🔥',
          status: 'delivered',
          videoId: 'video3',
        ),
        ActivityNotification(
          id: '5',
          type: ActivityNotificationType.tag,
          user: const User(
            id: '5',
            displayName: 'SportsFan',
            username: 'SportsFan',
            bio: 'Sports content creator',
            avatarURL: null,
            onlineStatus: 'online',
            hashtags: ['sports'],
            followerCount: 95000,
            followingCount: 300,
            postCount: 180,
          ),
          timestamp: DateTime.now().subtract(const Duration(hours: 26)),
          postThumbnailUrl: 'https://example.com/tagged-video2.jpg',
          status: 'delivered',
          videoId: 'video4',
        ),

        // Last 7 Days
        ActivityNotification(
          id: '6',
          type: ActivityNotificationType.like,
          user: const User(
            id: '5',
            displayName: 'SportsFan',
            username: 'SportsFan',
            bio: 'Sports content creator',
            avatarURL: null,
            onlineStatus: 'online',
            hashtags: ['sports'],
            followerCount: 95000,
            followingCount: 300,
            postCount: 180,
          ),
          timestamp: DateTime.now().subtract(const Duration(days: 3)),
          postThumbnailUrl: 'https://example.com/post3.jpg',
          status: 'delivered',
          videoId: 'video5',
        ),
        ActivityNotification(
          id: '7',
          type: ActivityNotificationType.follow,
          user: const User(
            id: '1',
            displayName: 'GamingPro',
            username: 'GamingPro',
            bio: 'Gaming streamer',
            avatarURL: null,
            onlineStatus: 'online',
            hashtags: ['gaming'],
            followerCount: 150000,
            followingCount: 500,
            postCount: 120,
          ),
          timestamp: DateTime.now().subtract(const Duration(days: 5)),
          postThumbnailUrl: null,
          status: 'delivered',
        ),

        // Processing example
        ActivityNotification(
          id: '8',
          type: ActivityNotificationType.mention,
          user: const User(
            id: '2',
            displayName: 'ArtStreamer',
            username: 'ArtStreamer',
            bio: 'Digital artist',
            avatarURL: null,
            onlineStatus: 'offline',
            hashtags: ['art'],
            followerCount: 75000,
            followingCount: 200,
            postCount: 85,
          ),
          timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
          postThumbnailUrl: 'https://example.com/mentioned-video.jpg',
          commentText: '@user mentioned you in a comment',
          status: 'processing',
          videoId: 'video6',
        ),
      ];
}
