import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'platform_icon_view.dart';

class Platform {
  final PlatformType type;
  final String username;
  final int followers;
  final String? url;

  const Platform({
    required this.type,
    required this.username,
    required this.followers,
    this.url,
  });
}

class SocialIconsRow extends StatelessWidget {
  final List<Platform> platforms;

  const SocialIconsRow({
    super.key,
    required this.platforms,
  });

  // Adaptive sizing based on device and content size
  double _getIconSize(BuildContext context) {
    final textScaleFactor = MediaQuery.of(context).textScaleFactor;
    const baseSize = 20.0;
    
    if (textScaleFactor >= 1.8) return baseSize * 1.8;
    if (textScaleFactor >= 1.6) return baseSize * 1.6;
    if (textScaleFactor >= 1.4) return baseSize * 1.4;
    if (textScaleFactor >= 1.2) return baseSize * 1.2;
    return baseSize;
  }

  double _getIconSpacing(BuildContext context) {
    final textScaleFactor = MediaQuery.of(context).textScaleFactor;
    
    if (textScaleFactor >= 1.8) return 32;
    if (textScaleFactor >= 1.6) return 28;
    if (textScaleFactor >= 1.4) return 24;
    if (textScaleFactor >= 1.2) return 20;
    return 16;
  }

  Color _getIconColor() {
    return Colors.white.withOpacity(0.8);
  }

  @override
  Widget build(BuildContext context) {
    final iconSize = _getIconSize(context);
    final iconSpacing = _getIconSpacing(context);
    final iconColor = _getIconColor();

    return LayoutBuilder(
      builder: (context, constraints) {
        return SizedBox(
          height: iconSize + 8, // Add some vertical padding for touch targets
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Explicitly handle the seven platforms in order
              ...PlatformType.values.map((platformType) {
                final platform = platforms.firstWhere(
                  (p) => p.type == platformType,
                  orElse: () => const Platform(
                    type: PlatformType.other,
                    username: '',
                    followers: 0,
                  ),
                );

                if (platform.url != null && platform.url!.isNotEmpty) {
                  return Padding(
                    padding: EdgeInsets.only(right: iconSpacing),
                    child: GestureDetector(
                      onTap: () => _openURL(platform.url!),
                      child: SizedBox(
                        width: iconSize,
                        height: iconSize,
                        child: PlatformIconView(
                          platformType,
                          size: iconSize,
                        ),
                      ),
                    ),
                  );
                } else {
                  // Placeholder for missing platform
                  return Padding(
                    padding: EdgeInsets.only(right: iconSpacing),
                    child: Opacity(
                      opacity: 0.3,
                      child: SizedBox(
                        width: iconSize,
                        height: iconSize,
                        child: PlatformIconView(
                          platformType,
                          size: iconSize,
                        ),
                      ),
                    ),
                  );
                }
              }),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openURL(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

// Preview widget for testing
class SocialIconsRowPreview extends StatelessWidget {
  const SocialIconsRowPreview({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.all(20),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SocialIconsRow(
            platforms: [
              Platform(
                type: PlatformType.tiktok,
                username: "test",
                followers: 100,
                url: "https://tiktok.com/@test",
              ),
              Platform(
                type: PlatformType.youtube,
                username: "test",
                followers: 100,
                url: "https://youtube.com/test",
              ),
              Platform(
                type: PlatformType.instagram,
                username: "test",
                followers: 100,
                url: "https://instagram.com/test",
              ),
            ],
          ),
          
          SizedBox(height: 20),
          
          SocialIconsRow(
            platforms: [
              Platform(
                type: PlatformType.facebook,
                username: "test",
                followers: 100,
                url: "https://facebook.com/test",
              ),
              Platform(
                type: PlatformType.twitter,
                username: "test",
                followers: 100,
                url: "https://twitter.com/test",
              ),
            ],
          ),
        ],
      ),
    );
  }
}
