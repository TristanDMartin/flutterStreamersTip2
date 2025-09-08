import 'package:flutter/material.dart';

enum PlatformType {
  twitch,
  youtube,
  kick,
  tiktok,
  facebook,
  bluesky,
  twitter,
  instagram,
  rednote,
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
    Widget icon;
    
    switch (platformType) {
      case PlatformType.twitch:
        icon = TwitchIcon(size: size);
      case PlatformType.youtube:
        icon = YouTubeIcon(size: size);
      case PlatformType.kick:
        icon = KickIcon(size: size);
      case PlatformType.tiktok:
        icon = TikTokIcon(size: size);
      case PlatformType.facebook:
        icon = FacebookIcon(size: size);
      case PlatformType.bluesky:
        icon = BlueSkyIcon(size: size);
      case PlatformType.twitter:
        icon = TwitterIcon(size: size);
      case PlatformType.instagram:
        icon = InstagramIcon(size: size);
      case PlatformType.rednote:
        icon = RednoteIcon(size: size);
      case PlatformType.other:
        icon = WebsiteIcon(size: size);
    }

    return SizedBox(
      width: size,
      height: size,
      child: icon,
    );
  }
}

// MARK: - Individual Platform Icons

class TwitchIcon extends StatelessWidget {
  final double size;

  const TwitchIcon({
    super.key,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    // Placeholder for Twitch icon - replace with actual asset
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFF9146FF), // Twitch purple
        borderRadius: BorderRadius.circular(size / 2),
      ),
      child: const Icon(
        Icons.tv,
        color: Colors.white,
        size: 16,
      ),
    );
  }
}

class YouTubeIcon extends StatelessWidget {
  final double size;

  const YouTubeIcon({
    super.key,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Red background
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Colors.red,
            borderRadius: BorderRadius.circular(size * 0.15),
          ),
        ),
        
        // White play button (triangle)
        Positioned(
          left: size * 0.05,
          top: size * 0.35,
          child: CustomPaint(
            size: Size(size * 0.3, size * 0.3),
            painter: TrianglePainter(),
          ),
        ),
      ],
    );
  }
}

class KickIcon extends StatelessWidget {
  final double size;

  const KickIcon({
    super.key,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: Colors.green,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          "K",
          style: TextStyle(
            color: Colors.white,
            fontSize: size * 0.6,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class TikTokIcon extends StatelessWidget {
  final double size;

  const TikTokIcon({
    super.key,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(size * 0.2),
      ),
      child: Icon(
        Icons.music_note,
        color: Colors.white,
        size: size * 0.6,
      ),
    );
  }
}

class FacebookIcon extends StatelessWidget {
  final double size;

  const FacebookIcon({
    super.key,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    // Placeholder for Facebook icon - replace with actual asset
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: Color(0xFF1877F2), // Facebook blue
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.facebook,
        color: Colors.white,
        size: 16,
      ),
    );
  }
}

class BlueSkyIcon extends StatelessWidget {
  final double size;

  const BlueSkyIcon({
    super.key,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: Colors.cyan,
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.cloud,
        color: Colors.white,
        size: size * 0.6,
      ),
    );
  }
}

class TwitterIcon extends StatelessWidget {
  final double size;

  const TwitterIcon({
    super.key,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(size * 0.2),
      ),
      child: Center(
        child: Text(
          "X",
          style: TextStyle(
            color: Colors.white,
            fontSize: size * 0.6,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class InstagramIcon extends StatelessWidget {
  final double size;

  const InstagramIcon({
    super.key,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    // Placeholder for Instagram icon - replace with actual asset
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: Color(0xFFE4405F), // Instagram pink
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.camera_alt,
        color: Colors.white,
        size: 16,
      ),
    );
  }
}

class RednoteIcon extends StatelessWidget {
  final double size;

  const RednoteIcon({
    super.key,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.red,
        borderRadius: BorderRadius.circular(size * 0.2),
      ),
      child: Icon(
        Icons.note,
        color: Colors.white,
        size: size * 0.6,
      ),
    );
  }
}

class WebsiteIcon extends StatelessWidget {
  final double size;

  const WebsiteIcon({
    super.key,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: Colors.grey,
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.language,
        color: Colors.white,
        size: size * 0.6,
      ),
    );
  }
}

// MARK: - Helper Views

class TrianglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(0, 0);
    path.lineTo(size.width, size.height / 2);
    path.lineTo(0, size.height);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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
              PlatformIconView(PlatformType.instagram, size: 30),
            ],
          ),
          
          SizedBox(height: 20),
          
          // Third row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              PlatformIconView(PlatformType.rednote, size: 30),
              SizedBox(width: 15),
              PlatformIconView(PlatformType.other, size: 30),
            ],
          ),
        ],
      ),
    );
  }
}
