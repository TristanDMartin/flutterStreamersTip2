import 'calendar_event.dart';
import 'user_count_fields.dart';
import '../utils/data_parsing_utils.dart';

class User {
  final String id;
  final String username;
  final String displayName;
  final String? bio;
  final String? avatarURL;
  final String onlineStatus;
  final List<String> hashtags;
  final String aiSelf;
  final int postCount;
  final int followerCount;
  final int followingCount;
  final List<CalendarEvent> calendarEvents;
  final UserPrivacy privacy;
  final List<String> pinnedVideoIds;
  final String role;

  const User({
    required this.id,
    required this.username,
    required this.displayName,
    this.bio,
    this.avatarURL,
    this.onlineStatus = 'online',
    this.hashtags = const <String>[],
    this.aiSelf = '',
    this.postCount = 0,
    this.followerCount = 0,
    this.followingCount = 0,
    this.calendarEvents = const <CalendarEvent>[],
    this.privacy = const UserPrivacy(),
    this.pinnedVideoIds = const <String>[],
    this.role = 'user',
  });

  factory User.fromMap(Map<String, dynamic> data) {
    return User(
      id: data['id'] ?? data['uid'] ?? '',
      username: data['username'] ?? '',
      displayName: data['displayName'] ?? '',
      bio: data['bio'],
      avatarURL: data['avatarURL'],
      onlineStatus: data['onlineStatus'] ?? 'online',
      hashtags: parseStringList(data['hashtags']),
      aiSelf: data['aiSelf'] ?? '',
      postCount: parseInteger(data['postCount']),
      followerCount: UserCountFields.readFollowersCount(data),
      followingCount: UserCountFields.readFollowingCount(data),
      calendarEvents: (data['calendarEvents'] as List<dynamic>?)
              ?.map((e) => CalendarEvent.fromMap(e as Map<String, dynamic>))
              .toList() ??
          [],
      privacy:
          UserPrivacy.fromMap(data['privacy'] as Map<String, dynamic>? ?? {}),
      pinnedVideoIds: parseStringList(data['pinnedVideoIds']),
      role: data['role'] ?? 'user',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'uid': id, // Also store as uid for clarity
      'username': username,
      'displayName': displayName,
      'bio': bio,
      'avatarURL': avatarURL,
      'onlineStatus': onlineStatus,
      'hashtags': hashtags,
      'aiSelf': aiSelf,
      'postCount': postCount,
      ...UserCountFields.writeCanonicalCounts(
        followersCount: followerCount,
        followingCount: followingCount,
      ),
      'calendarEvents': calendarEvents.map((e) => e.toMap()).toList(),
      'privacy': privacy.toMap(),
      'pinnedVideoIds': pinnedVideoIds,
      'role': role,
    };
  }
}

extension UserSamples on User {
  static List<User> get samples => <User>[
        const User(
          id: 'u0',
          username: 'you',
          displayName: 'You',
          bio: 'Creator',
          avatarURL: null,
          onlineStatus: 'online',
          hashtags: <String>['creator'],
          postCount: 10,
          followerCount: 200,
          followingCount: 50,
        ),
        const User(
          id: 'u1',
          username: 'gamingpro',
          displayName: 'GamingPro',
          bio: 'Gaming streamer',
          avatarURL: null,
          onlineStatus: 'online',
          hashtags: <String>['gaming'],
          postCount: 120,
          followerCount: 150000,
          followingCount: 500,
        ),
      ];
}

/// User privacy settings
class UserPrivacy {
  final bool showFavoritesOnCard;

  const UserPrivacy({
    this.showFavoritesOnCard = false, // Default: hidden
  });

  factory UserPrivacy.fromMap(Map<String, dynamic> data) {
    return UserPrivacy(
      showFavoritesOnCard: data['showFavoritesOnCard'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'showFavoritesOnCard': showFavoritesOnCard,
    };
  }

  UserPrivacy copyWith({
    bool? showFavoritesOnCard,
  }) {
    return UserPrivacy(
      showFavoritesOnCard: showFavoritesOnCard ?? this.showFavoritesOnCard,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserPrivacy &&
        other.showFavoritesOnCard == showFavoritesOnCard;
  }

  @override
  int get hashCode => showFavoritesOnCard.hashCode;
}
