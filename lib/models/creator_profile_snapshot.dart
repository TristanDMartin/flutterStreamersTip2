import '../utils/avatar_url_resolver.dart';
import '../utils/data_parsing_utils.dart';
import 'forum_author.dart';
import 'home_video.dart';
import 'streamer_card.dart';
import 'trending_creator.dart';
import 'user.dart';
import 'user_count_fields.dart';
import 'user_model.dart' as network_user;

/// Lightweight creator profile used to open [StreamerCardView] instantly.
class CreatorProfileSnapshot {
  const CreatorProfileSnapshot({
    required this.creatorId,
    required this.displayName,
    required this.username,
    this.avatarUrl,
    this.creatorScore,
    this.level,
    this.followersCount = 0,
    this.followingCount = 0,
    this.postCount = 0,
    this.bio,
    this.onlineStatus,
    this.recentVideos = const <Map<String, dynamic>>[],
  });

  final String creatorId;
  final String displayName;
  final String username;
  final String? avatarUrl;
  final double? creatorScore;
  final int? level;
  final int followersCount;
  final int followingCount;
  final int postCount;
  final String? bio;
  final String? onlineStatus;
  final List<Map<String, dynamic>> recentVideos;

  bool get hasDisplayIdentity =>
      creatorId.isNotEmpty &&
      (displayName.isNotEmpty || username.isNotEmpty);

  Map<String, dynamic> toUserDataMap() {
    final Map<String, dynamic> map = <String, dynamic>{
      'id': creatorId,
      'uid': creatorId,
      'displayName': displayName,
      'username': username,
      'avatarURL': avatarUrl,
      'bio': bio ?? '',
      'onlineStatus': onlineStatus ?? 'online',
      'postCount': postCount,
      ..._writeCounts(),
    };
    if (creatorScore != null) {
      map['creatorScore'] = creatorScore;
      map['creator_score'] = creatorScore;
    }
    if (level != null && level! > 0) {
      map['creatorLevel'] = level;
      map['level'] = level;
    }
    if (recentVideos.isNotEmpty) {
      map['recentVideos'] = recentVideos;
    }
    return map;
  }

  Map<String, dynamic> _writeCounts() {
    return <String, dynamic>{
      'followerCount': followersCount,
      'followingCount': followingCount,
      'followersCount': followersCount,
      'stats': <String, dynamic>{
        'followersCount': followersCount,
        'followingCount': followingCount,
        'postCount': postCount,
      },
    };
  }

  CreatorProfileSnapshot mergeUserData(Map<String, dynamic> fresh) {
    return CreatorProfileSnapshot(
      creatorId: creatorId,
      displayName: fresh['displayName'] as String? ?? displayName,
      username: fresh['username'] as String? ?? username,
      avatarUrl: resolveAvatarUrl(fresh) ?? avatarUrl,
      creatorScore: _readScore(fresh) ?? creatorScore,
      level: _readLevel(fresh) ?? level,
      followersCount: _readFollowers(fresh),
      followingCount: _readFollowing(fresh),
      postCount: _readPosts(fresh),
      bio: fresh['bio'] as String? ?? bio,
      onlineStatus: fresh['onlineStatus'] as String? ?? onlineStatus,
      recentVideos: recentVideos,
    );
  }

  static CreatorProfileSnapshot fromUser(User user) {
    return CreatorProfileSnapshot(
      creatorId: user.id,
      displayName: user.displayName,
      username: user.username,
      avatarUrl: user.avatarURL,
      followersCount: user.followerCount,
      followingCount: user.followingCount,
      postCount: user.postCount,
      bio: user.bio,
      onlineStatus: user.onlineStatus,
    );
  }

  static CreatorProfileSnapshot fromNetworkUser(network_user.User user) {
    return CreatorProfileSnapshot(
      creatorId: user.id,
      displayName: user.displayName,
      username: user.username,
      avatarUrl: user.avatarURL,
      followersCount: user.followerCount,
      followingCount: user.followingCount,
      postCount: user.postCount,
      bio: user.bio,
      onlineStatus: user.onlineStatus.value,
    );
  }

  static CreatorProfileSnapshot fromStreamerCard(StreamerCard card) {
    return CreatorProfileSnapshot(
      creatorId: card.id,
      displayName: card.displayName,
      username: card.username,
      avatarUrl: card.avatarURL,
      bio: card.bio,
      onlineStatus: card.onlineStatus,
    );
  }

  static CreatorProfileSnapshot fromTrendingCreator(TrendingCreator creator) {
    return CreatorProfileSnapshot(
      creatorId: creator.id,
      displayName: creator.displayName ?? creator.username,
      username: creator.username,
      avatarUrl: creator.avatarURL,
      level: creator.creatorLevel > 0 ? creator.creatorLevel : null,
      followersCount: creator.followerCount,
      onlineStatus: creator.isActive ? 'online' : 'invisible',
    );
  }

  static CreatorProfileSnapshot fromHomeVideoCreator(User creator) {
    return fromUser(creator);
  }

  static CreatorProfileSnapshot fromForumAuthor(ForumAuthor author) {
    return CreatorProfileSnapshot(
      creatorId: author.uid,
      displayName: author.displayName,
      username: author.username,
      avatarUrl: author.avatarUrl,
    );
  }

  static CreatorProfileSnapshot fromUserDataMap(
    String userId,
    Map<String, dynamic> data,
  ) {
    return CreatorProfileSnapshot(
      creatorId: userId,
      displayName: data['displayName'] as String? ?? '',
      username: data['username'] as String? ?? '',
      avatarUrl: resolveAvatarUrl(data),
      creatorScore: _readScore(data),
      level: _readLevel(data),
      followersCount: _readFollowers(data),
      followingCount: _readFollowing(data),
      postCount: _readPosts(data),
      bio: data['bio'] as String?,
      onlineStatus: data['onlineStatus'] as String?,
    );
  }

  static double? _readScore(Map<String, dynamic> data) {
    final Object? raw = data['creatorScore'] ?? data['creator_score'];
    if (raw is num) {
      return raw.toDouble();
    }
    return null;
  }

  static int? _readLevel(Map<String, dynamic> data) {
    final Object? raw = data['creatorLevel'] ?? data['level'];
    if (raw is int) {
      return raw;
    }
    if (raw is num) {
      return raw.toInt();
    }
    return null;
  }

  static int _readFollowers(Map<String, dynamic> data) {
    return UserCountFields.readFollowersCount(data);
  }

  static int _readFollowing(Map<String, dynamic> data) {
    return UserCountFields.readFollowingCount(data);
  }

  static int _readPosts(Map<String, dynamic> data) {
    final Object? raw =
        data['postCount'] ?? (data['stats'] as Map?)?['postCount'];
    return parseInteger(raw);
  }
}

extension HomeVideoCreatorSnapshot on HomeVideo {
  CreatorProfileSnapshot get creatorSnapshot =>
      CreatorProfileSnapshot.fromHomeVideoCreator(creator);
}
