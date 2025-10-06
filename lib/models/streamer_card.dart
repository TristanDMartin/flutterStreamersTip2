import 'calendar_event.dart';
import 'user.dart';

class StreamerCard {
  final String id;
  final String username;
  final String displayName;
  final String bio;
  final String? avatarURL;
  final String? coverImageURL;
  final List<Platform> platforms;
  final List<String> hashtags;
  final List<SocialLink> socialLinks;
  final bool isConnected;
  final String onlineStatus;
  final List<CalendarEvent> calendarEvents;
  final bool isFollowing;
  final bool isFollowingYou;
  final UserPrivacy privacy;

  const StreamerCard({
    required this.id,
    required this.username,
    required this.displayName,
    required this.bio,
    this.avatarURL,
    this.coverImageURL,
    this.platforms = const [],
    this.hashtags = const [],
    this.socialLinks = const [],
    this.isConnected = false,
    this.onlineStatus = 'online',
    this.calendarEvents = const [],
    this.isFollowing = false,
    this.isFollowingYou = false,
    this.privacy = const UserPrivacy(),
  });

  factory StreamerCard.fromJson(Map<String, dynamic> json) {
    return StreamerCard(
      id: json['id'] as String,
      username: json['username'] as String,
      displayName: json['displayName'] as String,
      bio: json['bio'] as String,
      avatarURL: json['avatarURL'] as String?,
      coverImageURL: json['coverImageURL'] as String?,
      platforms: (json['platforms'] as List<dynamic>?)
              ?.map((p) => Platform.fromJson(p as Map<String, dynamic>))
              .toList() ??
          [],
      hashtags: (json['hashtags'] as List<dynamic>?)
              ?.map((h) => h as String)
              .toList() ??
          [],
      socialLinks: (json['socialLinks'] as List<dynamic>?)
              ?.map((s) => SocialLink.fromJson(s as Map<String, dynamic>))
              .toList() ??
          [],
      isConnected: json['isConnected'] as bool? ?? false,
      onlineStatus: json['onlineStatus'] as String? ?? 'online',
      calendarEvents: (json['calendarEvents'] as List<dynamic>?)
              ?.map((e) => CalendarEvent.fromMap(e as Map<String, dynamic>))
              .toList() ??
          [],
      isFollowing: json['isFollowing'] as bool? ?? false,
      isFollowingYou: json['isFollowingYou'] as bool? ?? false,
      privacy:
          UserPrivacy.fromMap(json['privacy'] as Map<String, dynamic>? ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'displayName': displayName,
      'bio': bio,
      'avatarURL': avatarURL,
      'coverImageURL': coverImageURL,
      'platforms': platforms.map((p) => p.toJson()).toList(),
      'hashtags': hashtags,
      'socialLinks': socialLinks.map((s) => s.toJson()).toList(),
      'isConnected': isConnected,
      'onlineStatus': onlineStatus,
      'calendarEvents': calendarEvents.map((e) => e.toMap()).toList(),
      'isFollowing': isFollowing,
      'isFollowingYou': isFollowingYou,
      'privacy': privacy.toMap(),
    };
  }
}

class Platform {
  final String id; // UUID as String in Dart
  final PlatformType type;
  final String username;
  final int followers;
  final String? url; // URL as String? in Dart

  const Platform({
    required this.id,
    required this.type,
    required this.username,
    required this.followers,
    this.url,
  });

  factory Platform.fromJson(Map<String, dynamic> json) {
    return Platform(
      id: json['id'] as String,
      type: PlatformType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => PlatformType.other,
      ),
      username: json['username'] as String,
      followers: json['followers'] as int,
      url: json['url'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'username': username,
      'followers': followers,
      'url': url,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Platform &&
        other.id == id &&
        other.type == type &&
        other.username == username &&
        other.followers == followers &&
        other.url == url;
  }

  @override
  int get hashCode {
    return Object.hash(id, type, username, followers, url);
  }
}

enum PlatformType {
  twitch,
  youtube,
  kick,
  tiktok,
  facebook,
  bluesky,
  twitter,
  instagram,
  reddit,
  other,
}

class SocialLink {
  final String id;
  final String platform;
  final String url;
  final String username;

  const SocialLink({
    required this.id,
    required this.platform,
    required this.url,
    required this.username,
  });

  factory SocialLink.fromJson(Map<String, dynamic> json) {
    return SocialLink(
      id: json['id'] as String,
      platform: json['platform'] as String,
      url: json['url'] as String,
      username: json['username'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'platform': platform,
      'url': url,
      'username': username,
    };
  }
}

extension PlatformTypeExtension on PlatformType {
  String get iconName {
    switch (this) {
      case PlatformType.twitch:
        return 'twitch';
      case PlatformType.youtube:
        return 'youtube';
      case PlatformType.kick:
        return 'kick';
      case PlatformType.tiktok:
        return 'tiktok';
      case PlatformType.facebook:
        return 'facebook';
      case PlatformType.bluesky:
        return 'bluesky';
      case PlatformType.twitter:
        return 'twitter';
      case PlatformType.instagram:
        return 'instagram';
      case PlatformType.reddit:
        return 'reddit';
      case PlatformType.other:
        return 'other';
    }
  }

  int get colorValue {
    switch (this) {
      case PlatformType.twitch:
        return 0xFF9146FF; // Purple
      case PlatformType.kick:
        return 0xFF00FF00; // Green
      case PlatformType.tiktok:
        return 0xFF000000; // Black
      case PlatformType.youtube:
        return 0xFFFF0000; // Red
      case PlatformType.facebook:
        return 0xFF1877F2; // Blue
      case PlatformType.bluesky:
        return 0xFF00FFFF; // Cyan
      case PlatformType.twitter:
        return 0xFF000000; // Black
      case PlatformType.instagram:
        return 0xFF9146FF; // Purple (matching Swift)
      case PlatformType.reddit:
        return 0xFFFF0000; // Red
      case PlatformType.other:
        return 0xFF808080; // Gray
    }
  }
}

extension StreamerCardExtension on StreamerCard {
  bool get isOnline => onlineStatus == 'online';

  bool get isMutuallyConnected => isFollowing && isFollowingYou;
}
