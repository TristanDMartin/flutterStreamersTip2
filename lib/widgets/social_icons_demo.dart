import 'package:flutter/material.dart';
import 'social_platform_icon.dart';
import '../constants/social_icons.dart';

/// Demo page showcasing all social platform icon widgets
class SocialIconsDemo extends StatelessWidget {
  const SocialIconsDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Social Platform Icons Demo'),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('Basic Social Platform Icons'),
            _buildBasicIconsSection(context),
            
            const SizedBox(height: 32),
            _buildSectionTitle('Social Icons Row'),
            _buildIconsRowSection(context),
            
            const SizedBox(height: 32),
            _buildSectionTitle('Social Icons Grid'),
            _buildIconsGridSection(context),
            
            const SizedBox(height: 32),
            _buildSectionTitle('Icons with Labels'),
            _buildIconsWithLabelsSection(context),
            
            const SizedBox(height: 32),
            _buildSectionTitle('Social Platform Chips'),
            _buildPlatformChipsSection(context),
            
            const SizedBox(height: 32),
            _buildSectionTitle('Interactive Examples'),
            _buildInteractiveExamplesSection(context),
            
            const SizedBox(height: 32),
            _buildSectionTitle('Custom Styling'),
            _buildCustomStylingSection(context),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 20.0,
          fontWeight: FontWeight.bold,
          color: Colors.purple,
        ),
      ),
    );
  }

  Widget _buildBasicIconsSection(BuildContext context) {
    return Wrap(
      spacing: 16.0,
      runSpacing: 16.0,
      children: PlatformType.values.map((platform) {
        return Column(
          children: [
            SocialPlatformIcon(
              platform: platform,
              size: 48.0,
              onTap: () => _showPlatformInfo(context, platform),
            ),
            const SizedBox(height: 8.0),
            Text(
              platform.displayName,
              style: const TextStyle(fontSize: 12.0),
            ),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildIconsRowSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Horizontal Row:', style: TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 8.0),
        SocialPlatformIconsRow(
          platforms: PlatformType.values.take(5).toList(),
          iconSize: 40.0,
          spacing: 12.0,
          onPlatformTap: (platform) => () => _showPlatformInfo(context, platform),
        ),
        const SizedBox(height: 16.0),
        const Text('Centered Row:', style: TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 8.0),
        SocialPlatformIconsRow(
          platforms: PlatformType.values.take(3).toList(),
          iconSize: 36.0,
          spacing: 16.0,
          mainAxisAlignment: MainAxisAlignment.center,
          onPlatformTap: (platform) => () => _showPlatformInfo(context, platform),
        ),
      ],
    );
  }

  Widget _buildIconsGridSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('4x2 Grid:', style: TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 8.0),
        SizedBox(
          height: 120.0,
          child: SocialPlatformIconsGrid(
            platforms: PlatformType.values.take(8).toList(),
            iconSize: 40.0,
            spacing: 12.0,
            crossAxisCount: 4,
            onPlatformTap: (platform) => () => _showPlatformInfo(context, platform),
          ),
        ),
        const SizedBox(height: 16.0),
        const Text('3x3 Grid:', style: TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 8.0),
        SizedBox(
          height: 150.0,
          child: SocialPlatformIconsGrid(
            platforms: PlatformType.values.take(9).toList(),
            iconSize: 36.0,
            spacing: 16.0,
            crossAxisCount: 3,
            onPlatformTap: (platform) => () => _showPlatformInfo(context, platform),
          ),
        ),
      ],
    );
  }

  Widget _buildIconsWithLabelsSection(BuildContext context) {
    return Wrap(
      spacing: 24.0,
      runSpacing: 16.0,
      children: PlatformType.values.take(6).map((platform) {
        return SocialPlatformIconWithLabel(
          platform: platform,
          iconSize: 44.0,
          onTap: () => _showPlatformInfo(context, platform),
        );
      }).toList(),
    );
  }

  Widget _buildPlatformChipsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Basic Chips:', style: TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 8.0),
        Wrap(
          spacing: 8.0,
          runSpacing: 8.0,
          children: PlatformType.values.take(4).map((platform) {
            return SocialPlatformChip(
              platform: platform,
              height: 32.0,
              onTap: () => _showPlatformInfo(context, platform),
            );
          }).toList(),
        ),
        const SizedBox(height: 16.0),
        const Text('Deletable Chips:', style: TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 8.0),
        Wrap(
          spacing: 8.0,
          runSpacing: 8.0,
          children: PlatformType.values.take(3).map((platform) {
            return SocialPlatformChip(
              platform: platform,
              height: 36.0,
              onTap: () => _showPlatformInfo(context, platform),
              onDelete: () => _showDeleteMessage(context, platform),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildInteractiveExamplesSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Tap to Open Platform:', style: TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 8.0),
        SocialPlatformIconsRow(
          platforms: const [PlatformType.twitch, PlatformType.youtube, PlatformType.kick],
          iconSize: 48.0,
          spacing: 16.0,
          showBackground: true,
          onPlatformTap: (platform) => () => _openPlatform(context, platform),
        ),
        const SizedBox(height: 16.0),
        const Text('Custom Background Colors:', style: TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 8.0),
        Wrap(
          spacing: 12.0,
          runSpacing: 12.0,
          children: [
            SocialPlatformIcon(
              platform: PlatformType.twitch,
              size: 44.0,
              backgroundColor: Colors.purple.withValues(alpha:0.2),
              onTap: () => _showPlatformInfo(context, PlatformType.twitch),
            ),
            SocialPlatformIcon(
              platform: PlatformType.youtube,
              size: 44.0,
              backgroundColor: Colors.red.withValues(alpha:0.2),
              onTap: () => _showPlatformInfo(context, PlatformType.youtube),
            ),
            SocialPlatformIcon(
              platform: PlatformType.kick,
              size: 44.0,
              backgroundColor: Colors.green.withValues(alpha:0.2),
              onTap: () => _showPlatformInfo(context, PlatformType.kick),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCustomStylingSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Custom Borders:', style: TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 8.0),
        Wrap(
          spacing: 12.0,
          runSpacing: 12.0,
          children: [
            SocialPlatformIcon(
              platform: PlatformType.instagram,
              size: 44.0,
              border: Border.all(color: Colors.pink, width: 2.0),
              borderRadius: BorderRadius.circular(22.0),
              onTap: () => _showPlatformInfo(context, PlatformType.instagram),
            ),
            SocialPlatformIcon(
              platform: PlatformType.twitter,
              size: 44.0,
              border: Border.all(color: Colors.blue, width: 2.0),
              borderRadius: BorderRadius.circular(8.0),
              onTap: () => _showPlatformInfo(context, PlatformType.twitter),
            ),
            SocialPlatformIcon(
              platform: PlatformType.facebook,
              size: 44.0,
              border: Border.all(color: Colors.indigo, width: 2.0),
              borderRadius: BorderRadius.circular(12.0),
              onTap: () => _showPlatformInfo(context, PlatformType.facebook),
            ),
          ],
        ),
        const SizedBox(height: 16.0),
        const Text('No Background Icons:', style: TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 8.0),
        SocialPlatformIconsRow(
          platforms: PlatformType.values.take(5).toList(),
          iconSize: 40.0,
          spacing: 16.0,
          showBackground: false,
          onPlatformTap: (platform) => () => _showPlatformInfo(context, platform),
        ),
      ],
    );
  }

  void _showPlatformInfo(BuildContext context, PlatformType platform) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            SocialPlatformIcon(
              platform: platform,
              size: 32.0,
              showBackground: false,
            ),
            const SizedBox(width: 12.0),
            Text(platform.displayName),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Platform: ${platform.displayName}'),
            Text('Brand Color: ${platform.brandColor.toString()}'),
            Text('URL Scheme: ${platform.urlScheme}'),
            Text('Icon Path: ${platform.iconPath}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _openPlatform(context, platform);
            },
            child: const Text('Open Platform'),
          ),
        ],
      ),
    );
  }

  void _showDeleteMessage(BuildContext context, PlatformType platform) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${platform.displayName} platform removed!'),
        duration: const Duration(seconds: 2),
        backgroundColor: platform.brandColor,
      ),
    );
  }

  void _openPlatform(BuildContext context, PlatformType platform) {
    // In a real app, you would use url_launcher to open the platform URL
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Opening ${platform.displayName}...'),
        duration: const Duration(seconds: 2),
        backgroundColor: platform.brandColor,
      ),
    );
  }
}
