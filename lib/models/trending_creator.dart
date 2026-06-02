import 'package:freezed_annotation/freezed_annotation.dart';
import 'streamer_card.dart';
import 'user.dart';

part 'trending_creator.freezed.dart';

@freezed
sealed class TrendingCreator with _$TrendingCreator {
  const factory TrendingCreator({
    required String id,
    required String username,
    String? displayName,
    String? avatarURL,
    @Default(0) int followerCount,
    @Default(false) bool isActive,
    @Default(0) int creatorLevel,
    String? tierStatusLabel,
    @Default(false) bool isFollowing,
  }) = _TrendingCreator;
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
      isConnected: isFollowing,
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

  /// Line under @username (Live Now, tier, level, or Rising Creator).
  String get trendingStatusLine {
    if (isActive) {
      return 'Live Now';
    }
    final String? tier = tierStatusLabel?.trim();
    if (tier != null && tier.isNotEmpty) {
      return tier;
    }
    if (creatorLevel > 0) {
      return 'Level $creatorLevel';
    }
    return 'Rising Creator';
  }
}
