import 'package:freezed_annotation/freezed_annotation.dart';
import 'streamer_card.dart';
import 'user.dart';

part 'trending_creator.freezed.dart';

@freezed
class TrendingCreator with _$TrendingCreator {
  const factory TrendingCreator({
    required String id,
    required String username,
    String? displayName,
    String? avatarURL,
    @Default(0) int followerCount,
    @Default(false) bool isActive,
  }) = _TrendingCreator;

  static const List<TrendingCreator> samples = [
    TrendingCreator(
        id: "1",
        username: "GamingPro",
        displayName: "Gaming Pro",
        avatarURL: null,
        followerCount: 150000,
        isActive: true),
    TrendingCreator(
        id: "2",
        username: "ArtStreamer",
        displayName: "Art Streamer",
        avatarURL: null,
        followerCount: 75000,
        isActive: true),
    TrendingCreator(
        id: "3",
        username: "MusicLive",
        displayName: "Music Live",
        avatarURL: null,
        followerCount: 200000,
        isActive: true),
    TrendingCreator(
        id: "4",
        username: "TechReview",
        displayName: "Tech Review",
        avatarURL: null,
        followerCount: 120000,
        isActive: true),
    TrendingCreator(
        id: "5",
        username: "SportsFan",
        displayName: "Sports Fan",
        avatarURL: null,
        followerCount: 180000,
        isActive: true),
    TrendingCreator(
        id: "6",
        username: "Foodie",
        displayName: "Foodie",
        avatarURL: null,
        followerCount: 95000,
        isActive: true),
  ];
}

extension TrendingCreatorExtension on TrendingCreator {
  // Convert TrendingCreator to StreamerCard for navigation
  StreamerCard toStreamerCard() {
    return StreamerCard(
      id: id,
      username: username,
      displayName: displayName ?? username,
      bio:
          "Trending creator with ${_formatFollowerCount(followerCount)} followers",
      avatarURL: avatarURL,
      coverImageURL: null,
      platforms: [],
      hashtags: ["trending", "creator"],
      socialLinks: [],
      isConnected: false,
      onlineStatus: isActive ? 'online' : 'invisible',
    );
  }

  // Convert TrendingCreator to User for navigation
  User toUser() {
    return User(
      id: id,
      username: username,
      displayName: displayName ?? username,
      bio:
          "Trending creator with ${_formatFollowerCount(followerCount)} followers",
      avatarURL: avatarURL,
      onlineStatus: isActive ? 'online' : 'invisible',
      hashtags: [],
      aiSelf: "",
      postCount: 0,
      followerCount: followerCount,
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
