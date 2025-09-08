import 'package:freezed_annotation/freezed_annotation.dart';
import 'streamer_card.dart';
import 'user.dart';

part 'trending_creator.freezed.dart';

@freezed
class TrendingCreator with _$TrendingCreator {
  const factory TrendingCreator({
    required String id,
    required String username,
    String? avatarURL,
    @Default(0) int followers,
    @Default(false) bool isOnline,
  }) = _TrendingCreator;

  static const List<TrendingCreator> samples = [
    TrendingCreator(id: "1", username: "GamingPro", avatarURL: null, followers: 150000, isOnline: true),
    TrendingCreator(id: "2", username: "ArtStreamer", avatarURL: null, followers: 75000, isOnline: false),
    TrendingCreator(id: "3", username: "MusicLive", avatarURL: null, followers: 200000, isOnline: true),
    TrendingCreator(id: "4", username: "TechReview", avatarURL: null, followers: 120000, isOnline: true),
  ];
}

extension TrendingCreatorExtension on TrendingCreator {
  // Convert TrendingCreator to StreamerCard for navigation
  StreamerCard toStreamerCard() {
    return StreamerCard(
      id: id,
      username: username,
      displayName: username,
      bio: "Trending creator with ${_formatFollowerCount(followers)} followers",
      avatarURL: avatarURL,
      coverImageURL: null,
      platforms: [],
      hashtags: ["trending", "creator"],
      socialLinks: [],
      isConnected: false,
      onlineStatus: isOnline ? 'online' : 'invisible',
    );
  }

  // Convert TrendingCreator to User for navigation
  User toUser() {
    return User(
      id: id,
      username: username,
      displayName: username,
      bio: "Trending creator with ${_formatFollowerCount(followers)} followers",
      avatarURL: avatarURL,
      onlineStatus: isOnline ? 'online' : 'invisible',
      hashtags: [],
      aiSelf: "",
      postCount: 0,
      followerCount: followers,
      followingCount: 0,
    );
  }

  String _formatFollowerCount(int count) {
    if (count >= 1000000) {
      return "${(count / 1000000).toStringAsFixed(1)}M";
    } else if (count >= 1000) {
      return "${(count / 1000).toStringAsFixed(1)}K";
    } else {
      return count.toString();
    }
  }
}
