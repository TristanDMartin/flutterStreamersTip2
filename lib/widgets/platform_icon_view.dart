import 'package:flutter/material.dart';
import 'brand_icons.dart';

enum PlatformType {
  twitch,
  youtube,
  kick,
  tiktok,
  facebook,
  bluesky,
  twitter,
  discord,
  instagram,
  reddit,
  other,
}

class PlatformIconView extends StatelessWidget {
  final PlatformType platformType;
  final double size;

  const PlatformIconView(
    this.platformType, {
    super.key,
    this.size = 20,
  });

  @override
  Widget build(BuildContext context) {
    return BrandIcon(
      platformType: _getPlatformString(platformType),
      size: size,
    );
  }

  String _getPlatformString(PlatformType platformType) {
    switch (platformType) {
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
      case PlatformType.discord:
        return 'discord';
      case PlatformType.instagram:
        return 'instagram';
      case PlatformType.reddit:
        return 'reddit';
      case PlatformType.other:
        return 'other';
    }
  }
}


// Preview widget for testing
class PlatformIconViewPreview extends StatelessWidget {
  const PlatformIconViewPreview({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.all(20),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // First row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              PlatformIconView(PlatformType.twitch, size: 30),
              SizedBox(width: 15),
              PlatformIconView(PlatformType.youtube, size: 30),
              SizedBox(width: 15),
              PlatformIconView(PlatformType.kick, size: 30),
              SizedBox(width: 15),
              PlatformIconView(PlatformType.tiktok, size: 30),
            ],
          ),
          
          SizedBox(height: 20),
          
          // Second row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              PlatformIconView(PlatformType.facebook, size: 30),
              SizedBox(width: 15),
              PlatformIconView(PlatformType.bluesky, size: 30),
              SizedBox(width: 15),
              PlatformIconView(PlatformType.twitter, size: 30),
              SizedBox(width: 15),
              PlatformIconView(PlatformType.discord, size: 30),
            ],
          ),
          
          SizedBox(height: 20),
          
          // Third row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              PlatformIconView(PlatformType.instagram, size: 30),
              SizedBox(width: 15),
              PlatformIconView(PlatformType.reddit, size: 30),
              SizedBox(width: 15),
              PlatformIconView(PlatformType.other, size: 30),
            ],
          ),
        ],
      ),
    );
  }
}
