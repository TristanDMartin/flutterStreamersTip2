import 'package:flutter/material.dart';
import 'package:equatable/equatable.dart';

/// User Model - Complete implementation matching SwiftUI User class
/// 
/// This model represents a user in the network with all necessary properties
/// for the NetworkView functionality including social links, platforms, and status.
class User extends Equatable {
  final String id;
  final String username;
  final String displayName;
  final String? bio;
  final String? avatarURL;
  final List<Platform> platforms;
  final OnlineStatus onlineStatus;
  final List<String> hashtags;
  final String aiSelf;
  final List<SocialLink> socialLinks;
  final int postCount;
  final int followerCount;
  final int followingCount;
  final List<CalendarEvent> calendarEvents;

  const User({
    required this.id,
    required this.username,
    required this.displayName,
    this.bio,
    this.avatarURL,
    this.platforms = const [],
    this.onlineStatus = OnlineStatus.offline,
    this.hashtags = const [],
    this.aiSelf = '',
    this.socialLinks = const [],
    this.postCount = 0,
    this.followerCount = 0,
    this.followingCount = 0,
    this.calendarEvents = const [],
  });

  factory User.fromMap(Map<String, dynamic> data) {
    return User(
      id: data['id'] ?? '',
      username: data['username'] ?? '',
      displayName: data['displayName'] ?? '',
      bio: data['bio'],
      avatarURL: data['avatarURL'],
      platforms: (data['platforms'] as List<dynamic>?)
          ?.map((p) => Platform.fromMap(p as Map<String, dynamic>))
          .toList() ?? [],
      onlineStatus: OnlineStatus.values.firstWhere(
        (e) => e.value == data['onlineStatus'],
        orElse: () => OnlineStatus.offline,
      ),
      hashtags: List<String>.from(data['hashtags'] ?? []),
      aiSelf: data['aiSelf'] ?? '',
      socialLinks: (data['socialLinks'] as List<dynamic>?)
          ?.map((s) => SocialLink.fromMap(s as Map<String, dynamic>))
          .toList() ?? [],
      postCount: data['postCount'] ?? 0,
      followerCount: data['followerCount'] ?? 0,
      followingCount: data['followingCount'] ?? 0,
      calendarEvents: (data['calendarEvents'] as List<dynamic>?)
          ?.map((e) => CalendarEvent.fromMap(e as Map<String, dynamic>))
          .toList() ?? [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'username': username,
      'displayName': displayName,
      'bio': bio,
      'avatarURL': avatarURL,
      'platforms': platforms.map((p) => p.toMap()).toList(),
      'onlineStatus': onlineStatus.value,
      'hashtags': hashtags,
      'aiSelf': aiSelf,
      'socialLinks': socialLinks.map((s) => s.toMap()).toList(),
      'postCount': postCount,
      'followerCount': followerCount,
      'followingCount': followingCount,
      'calendarEvents': calendarEvents.map((e) => e.toMap()).toList(),
    };
  }

  User copyWith({
    String? id,
    String? username,
    String? displayName,
    String? bio,
    String? avatarURL,
    List<Platform>? platforms,
    OnlineStatus? onlineStatus,
    List<String>? hashtags,
    String? aiSelf,
    List<SocialLink>? socialLinks,
    int? postCount,
    int? followerCount,
    int? followingCount,
    List<CalendarEvent>? calendarEvents,
  }) {
    return User(
      id: id ?? this.id,
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      bio: bio ?? this.bio,
      avatarURL: avatarURL ?? this.avatarURL,
      platforms: platforms ?? this.platforms,
      onlineStatus: onlineStatus ?? this.onlineStatus,
      hashtags: hashtags ?? this.hashtags,
      aiSelf: aiSelf ?? this.aiSelf,
      socialLinks: socialLinks ?? this.socialLinks,
      postCount: postCount ?? this.postCount,
      followerCount: followerCount ?? this.followerCount,
      followingCount: followingCount ?? this.followingCount,
      calendarEvents: calendarEvents ?? this.calendarEvents,
    );
  }

  @override
  List<Object?> get props => [
        id,
        username,
        displayName,
        bio,
        avatarURL,
        platforms,
        onlineStatus,
        hashtags,
        aiSelf,
        socialLinks,
        postCount,
        followerCount,
        followingCount,
        calendarEvents,
      ];

  @override
  String toString() {
    return 'User(id: $id, username: $username, displayName: $displayName)';
  }
}

/// OnlineStatus Enum - Complete implementation matching SwiftUI
enum OnlineStatus {
  online('online', 'Online'),
  idle('idle', 'Idle'),
  doNotDisturb('doNotDisturb', 'Do Not Disturb'),
  invisible('invisible', 'Invisible'),
  offline('offline', 'Offline'),
  streaming('streaming', 'Streaming');

  const OnlineStatus(this.value, this.displayName);
  final String value;
  final String displayName;

  /// Get icon color for the status
  Color get iconColor {
    switch (this) {
      case OnlineStatus.online:
        return Colors.green;
      case OnlineStatus.idle:
        return Colors.yellow;
      case OnlineStatus.doNotDisturb:
        return Colors.red;
      case OnlineStatus.invisible:
        return Colors.grey;
      case OnlineStatus.offline:
        return Colors.grey.shade600;
      case OnlineStatus.streaming:
        return Colors.purple;
    }
  }

  /// Get status icon
  IconData get icon {
    switch (this) {
      case OnlineStatus.online:
        return Icons.circle;
      case OnlineStatus.idle:
        return Icons.schedule;
      case OnlineStatus.doNotDisturb:
        return Icons.block;
      case OnlineStatus.invisible:
        return Icons.visibility_off;
      case OnlineStatus.offline:
        return Icons.circle_outlined;
      case OnlineStatus.streaming:
        return Icons.live_tv;
    }
  }
}

/// Platform Model - Complete implementation matching SwiftUI Platform struct
class Platform extends Equatable {
  final String id;
  final PlatformType type;
  final String username;
  final int followers;
  final String? url;

  const Platform({
    required this.id,
    required this.type,
    required this.username,
    required this.followers,
    this.url,
  });

  factory Platform.fromMap(Map<String, dynamic> data) {
    return Platform(
      id: data['id'] ?? '',
      type: PlatformType.values.firstWhere(
        (e) => e.value == data['type'],
        orElse: () => PlatformType.other,
      ),
      username: data['username'] ?? '',
      followers: data['followers'] ?? 0,
      url: data['url'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.value,
      'username': username,
      'followers': followers,
      'url': url,
    };
  }

  @override
  List<Object?> get props => [id, type, username, followers, url];
}

/// PlatformType Enum - Complete implementation matching SwiftUI
enum PlatformType {
  twitch('twitch', 'Twitch'),
  youtube('youtube', 'YouTube'),
  kick('kick', 'Kick'),
  tiktok('tiktok', 'TikTok'),
  facebook('facebook', 'Facebook'),
  bluesky('bluesky', 'Bluesky'),
  twitter('twitter', 'Twitter'),
  instagram('instagram', 'Instagram'),
  reddit('reddit', 'Reddit'),
  other('other', 'Other');

  const PlatformType(this.value, this.displayName);
  final String value;
  final String displayName;

  /// Get platform icon
  IconData get icon {
    switch (this) {
      case PlatformType.twitch:
        return Icons.live_tv;
      case PlatformType.youtube:
        return Icons.play_circle;
      case PlatformType.kick:
        return Icons.sports_esports;
      case PlatformType.tiktok:
        return Icons.music_note;
      case PlatformType.facebook:
        return Icons.facebook;
      case PlatformType.bluesky:
        return Icons.cloud;
      case PlatformType.twitter:
        return Icons.alternate_email;
      case PlatformType.instagram:
        return Icons.camera_alt;
      case PlatformType.reddit:
        return Icons.note;
      case PlatformType.other:
        return Icons.link;
    }
  }

  /// Get platform color
  Color get color {
    switch (this) {
      case PlatformType.twitch:
        return const Color(0xFF9146FF);
      case PlatformType.youtube:
        return const Color(0xFFFF0000);
      case PlatformType.kick:
        return const Color(0xFF53FC18);
      case PlatformType.tiktok:
        return const Color(0xFF000000);
      case PlatformType.facebook:
        return const Color(0xFF1877F2);
      case PlatformType.bluesky:
        return const Color(0xFF00A2FF);
      case PlatformType.twitter:
        return const Color(0xFF1DA1F2);
      case PlatformType.instagram:
        return const Color(0xFFE4405F);
      case PlatformType.reddit:
        return const Color(0xFFFF6B6B);
      case PlatformType.other:
        return Colors.grey;
    }
  }
}

/// SocialLink Model for user social links
class SocialLink extends Equatable {
  final String id;
  final String platform;
  final String url;
  final String? username;
  final bool isVerified;
  final DateTime createdAt;

  const SocialLink({
    required this.id,
    required this.platform,
    required this.url,
    this.username,
    this.isVerified = false,
    required this.createdAt,
  });

  factory SocialLink.fromMap(Map<String, dynamic> data) {
    return SocialLink(
      id: data['id'] ?? '',
      platform: data['platform'] ?? '',
      url: data['url'] ?? '',
      username: data['username'],
      isVerified: data['isVerified'] ?? false,
      createdAt: DateTime.tryParse(data['createdAt'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'platform': platform,
      'url': url,
      'username': username,
      'isVerified': isVerified,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [id, platform, url, username, isVerified, createdAt];
}

/// CalendarEvent Model for user calendar events
class CalendarEvent extends Equatable {
  final String id;
  final String title;
  final String? description;
  final DateTime startTime;
  final DateTime endTime;
  final String? location;
  final bool isAllDay;
  final String? color;
  final DateTime createdAt;

  const CalendarEvent({
    required this.id,
    required this.title,
    this.description,
    required this.startTime,
    required this.endTime,
    this.location,
    this.isAllDay = false,
    this.color,
    required this.createdAt,
  });

  factory CalendarEvent.fromMap(Map<String, dynamic> data) {
    return CalendarEvent(
      id: data['id'] ?? '',
      title: data['title'] ?? '',
      description: data['description'],
      startTime: DateTime.tryParse(data['startTime'] ?? '') ?? DateTime.now(),
      endTime: DateTime.tryParse(data['endTime'] ?? '') ?? DateTime.now(),
      location: data['location'],
      isAllDay: data['isAllDay'] ?? false,
      color: data['color'],
      createdAt: DateTime.tryParse(data['createdAt'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'location': location,
      'isAllDay': isAllDay,
      'color': color,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [
        id,
        title,
        description,
        startTime,
        endTime,
        location,
        isAllDay,
        color,
        createdAt,
      ];
}
