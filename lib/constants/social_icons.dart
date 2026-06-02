import 'package:flutter/material.dart';

/// Social platform icon configuration for StreamersTip app
class SocialIcons {
  // Asset paths for social platform icons
  static const String _basePath = 'assets/images/social_icons';

  // Platform icon assets
  static const String twitch = '$_basePath/twitch_4138153.png';
  static const String youtube = '$_basePath/youtube.png';
  static const String kick = '$_basePath/kick.png';
  static const String tiktok = '$_basePath/tiktok.png';
  static const String facebook = '$_basePath/facebook.png';
  static const String bluesky = '$_basePath/bluesky.png';
  static const String twitter = '$_basePath/twitter.png';
  static const String instagram = '$_basePath/instagram.png';
  static const String reddit = '$_basePath/reddit.png';
  static const String website = '$_basePath/website.png';

  // Default fallback icon
  static const String defaultIcon = '$_basePath/default_platform.png';

  // Get icon asset path by platform name
  static String getIconPath(String platformName) {
    switch (platformName.toLowerCase()) {
      case 'twitch':
        return twitch;
      case 'youtube':
        return youtube;
      case 'kick':
        return kick;
      case 'tiktok':
        return tiktok;
      case 'facebook':
        return facebook;
      case 'bluesky':
        return bluesky;
      case 'twitter':
        return twitter;
      case 'instagram':
        return instagram;
      case 'reddit':
        return reddit;
      case 'website':
        return website;
      default:
        return defaultIcon;
    }
  }

  // Get icon asset path by platform type
  static String getIconPathByType(PlatformType type) {
    switch (type) {
      case PlatformType.twitch:
        return twitch;
      case PlatformType.youtube:
        return youtube;
      case PlatformType.kick:
        return kick;
      case PlatformType.tiktok:
        return tiktok;
      case PlatformType.facebook:
        return facebook;
      case PlatformType.bluesky:
        return bluesky;
      case PlatformType.twitter:
        return twitter;
      case PlatformType.instagram:
        return instagram;
      case PlatformType.reddit:
        return reddit;
      case PlatformType.website:
        return website;
    }
  }

  // List of all available platform icons
  static const List<String> allIcons = [
    twitch,
    youtube,
    kick,
    tiktok,
    facebook,
    bluesky,
    twitter,
    instagram,
    reddit,
    website,
  ];

  // Platform display names
  static const Map<String, String> platformDisplayNames = {
    'twitch': 'Twitch',
    'youtube': 'YouTube',
    'kick': 'Kick',
    'tiktok': 'TikTok',
    'facebook': 'Facebook',
    'bluesky': 'BlueSky',
    'twitter': 'Twitter',
    'instagram': 'Instagram',
    'reddit': 'Reddit',
    'website': 'Website',
  };
}

/// Platform types enum
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
  website,
}

/// Platform type extensions
extension PlatformTypeExtension on PlatformType {
  String get displayName {
    switch (this) {
      case PlatformType.twitch:
        return 'Twitch';
      case PlatformType.youtube:
        return 'YouTube';
      case PlatformType.kick:
        return 'Kick';
      case PlatformType.tiktok:
        return 'TikTok';
      case PlatformType.facebook:
        return 'Facebook';
      case PlatformType.bluesky:
        return 'BlueSky';
      case PlatformType.twitter:
        return 'Twitter';
      case PlatformType.instagram:
        return 'Instagram';
      case PlatformType.reddit:
        return 'RedNote';
      case PlatformType.website:
        return 'Website';
    }
  }

  String get iconPath => SocialIcons.getIconPathByType(this);

  Color get brandColor {
    switch (this) {
      case PlatformType.twitch:
        return const Color(0xFF9146FF); // Twitch purple
      case PlatformType.youtube:
        return const Color(0xFFFF0000); // YouTube red
      case PlatformType.kick:
        return const Color(0xFF53FC18); // Kick green
      case PlatformType.tiktok:
        return const Color(0xFF000000); // TikTok black
      case PlatformType.facebook:
        return const Color(0xFF1877F2); // Facebook blue
      case PlatformType.bluesky:
        return const Color(0xFF0085FF); // BlueSky blue
      case PlatformType.twitter:
        return const Color(0xFF1DA1F2); // Twitter blue
      case PlatformType.instagram:
        return const Color(0xFFE4405F); // Instagram pink
      case PlatformType.reddit:
        return const Color(0xFFFF4500); // RedNote orange
      case PlatformType.website:
        return const Color(0xFF6C757D); // Website gray
    }
  }

  String get urlScheme {
    switch (this) {
      case PlatformType.twitch:
        return 'https://twitch.tv/';
      case PlatformType.youtube:
        return 'https://youtube.com/@';
      case PlatformType.kick:
        return 'https://kick.com/';
      case PlatformType.tiktok:
        return 'https://tiktok.com/@';
      case PlatformType.facebook:
        return 'https://facebook.com/';
      case PlatformType.bluesky:
        return 'https://bsky.app/profile/';
      case PlatformType.twitter:
        return 'https://twitter.com/';
      case PlatformType.instagram:
        return 'https://instagram.com/';
      case PlatformType.reddit:
        return 'https://reddit.com/';
      case PlatformType.website:
        return 'https://';
    }
  }
}
