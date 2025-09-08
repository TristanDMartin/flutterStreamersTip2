import 'package:flutter/material.dart';

class LinksEditView extends StatefulWidget {
  final List<Map<String, dynamic>> platforms;
  final Function(List<Map<String, dynamic>>) onPlatformsUpdated;
  final VoidCallback? onBack;

  const LinksEditView({
    super.key,
    required this.platforms,
    required this.onPlatformsUpdated,
    this.onBack,
  });

  @override
  State<LinksEditView> createState() => _LinksEditViewState();
}

class _LinksEditViewState extends State<LinksEditView> {
  late List<PlatformLink> _platformLinks;
  
  // Allowed platform types matching your design system
  static const List<String> _allowedPlatforms = [
    'twitch', 'youtube', 'kick', 'tiktok', 'instagram', 
    'twitter', 'bluesky', 'rednote', 'facebook', 'other'
  ];

  @override
  void initState() {
    super.initState();
    _setupInitialLinks();
  }

  void _setupInitialLinks() {
    // Create a map of existing platforms for quick lookup
    final existingPlatforms = <String, Map<String, dynamic>>{};
    for (final platform in widget.platforms) {
      final type = platform['type'] as String? ?? '';
      existingPlatforms[type] = platform;
    }

    // Create platform links for all allowed platforms
    _platformLinks = _allowedPlatforms.map((type) {
      final existing = existingPlatforms[type];
      return PlatformLink(
        type: type,
        username: existing?['username'] ?? '',
        url: existing?['url'] ?? '',
      );
    }).toList();
  }

  void _saveLinks() {
    final updatedPlatforms = <Map<String, dynamic>>[];
    
    for (final link in _platformLinks) {
      if (link.username.isNotEmpty || link.url.isNotEmpty) {
        // Ensure URL has proper protocol
        String urlString = link.url.trim();
        if (urlString.isNotEmpty && 
            !urlString.startsWith('http://') && 
            !urlString.startsWith('https://')) {
          urlString = 'https://$urlString';
        }

        updatedPlatforms.add({
          'id': DateTime.now().millisecondsSinceEpoch.toString(),
          'type': link.type,
          'username': link.username,
          'followers': 0, // Placeholder
          'url': urlString.isEmpty ? null : urlString,
        });
      }
    }

    widget.onPlatformsUpdated(updatedPlatforms);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          onPressed: widget.onBack ?? () => Navigator.pop(context),
          icon: const Icon(Icons.chevron_left, color: Colors.white),
        ),
        title: const Text(
          'Edit links',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _saveLinks,
            child: const Text(
              'Save',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1E),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  for (int i = 0; i < _platformLinks.length; i++)
                    _buildPlatformLinkRow(_platformLinks[i], i),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlatformLinkRow(PlatformLink link, int index) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Platform header
              Row(
                children: [
                  _buildPlatformIcon(link.type),
                  const SizedBox(width: 12),
                  Text(
                    _getPlatformDisplayName(link.type),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              // Username field
              _buildInputField(
                label: 'Username:',
                value: link.username,
                hintText: 'Enter username',
                onChanged: (value) {
                  setState(() {
                    link.username = value;
                  });
                },
                onClear: () {
                  setState(() {
                    link.username = '';
                  });
                },
              ),
              
              const SizedBox(height: 12),
              
              // URL field
              _buildInputField(
                label: 'URL:',
                value: link.url,
                hintText: 'Enter URL',
                keyboardType: TextInputType.url,
                onChanged: (value) {
                  setState(() {
                    link.url = value;
                  });
                },
                onClear: () {
                  setState(() {
                    link.url = '';
                  });
                },
              ),
            ],
          ),
        ),
        
        // Divider (except for last item)
        if (index < _platformLinks.length - 1)
          Container(
            height: 1,
            color: const Color(0xFF2C2C2E),
            margin: const EdgeInsets.only(left: 52),
          ),
      ],
    );
  }

  Widget _buildInputField({
    required String label,
    required String value,
    required String hintText,
    required Function(String) onChanged,
    required VoidCallback onClear,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF121212),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 14,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: TextEditingController(text: value)
                ..selection = TextSelection.collapsed(offset: value.length),
              onChanged: onChanged,
              keyboardType: keyboardType,
              textCapitalization: TextCapitalization.none,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: const TextStyle(color: Colors.grey),
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          if (value.isNotEmpty)
            GestureDetector(
              onTap: onClear,
              child: const Icon(
                Icons.clear,
                color: Colors.grey,
                size: 20,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPlatformIcon(String platformType) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _getPlatformColor(platformType),
      ),
      child: Icon(
        _getPlatformIcon(platformType),
        color: Colors.white,
        size: 16,
      ),
    );
  }

  Color _getPlatformColor(String platformType) {
    switch (platformType.toLowerCase()) {
      case 'twitch':
        return const Color(0xFF9146FF);
      case 'youtube':
        return const Color(0xFFFF0000);
      case 'kick':
        return const Color(0xFF53FC18);
      case 'tiktok':
        return const Color(0xFF000000);
      case 'facebook':
        return const Color(0xFF1877F2);
      case 'bluesky':
        return const Color(0xFF0085FF);
      case 'twitter':
        return const Color(0xFF1DA1F2);
      case 'instagram':
        return const Color(0xFFE4405F);
      case 'rednote':
        return const Color(0xFFFF4500);
      default:
        return Colors.grey;
    }
  }

  IconData _getPlatformIcon(String platformType) {
    switch (platformType.toLowerCase()) {
      case 'twitch':
        return Icons.tv;
      case 'youtube':
        return Icons.play_circle;
      case 'kick':
        return Icons.sports_esports;
      case 'tiktok':
        return Icons.music_note;
      case 'facebook':
        return Icons.facebook;
      case 'bluesky':
        return Icons.cloud;
      case 'twitter':
        return Icons.flutter_dash;
      case 'instagram':
        return Icons.camera_alt;
      case 'rednote':
        return Icons.note;
      default:
        return Icons.link;
    }
  }

  String _getPlatformDisplayName(String platformType) {
    switch (platformType.toLowerCase()) {
      case 'twitch':
        return 'Twitch';
      case 'youtube':
        return 'YouTube';
      case 'kick':
        return 'Kick';
      case 'tiktok':
        return 'TikTok';
      case 'facebook':
        return 'Facebook';
      case 'bluesky':
        return 'Bluesky';
      case 'twitter':
        return 'Twitter';
      case 'instagram':
        return 'Instagram';
      case 'rednote':
        return 'RedNote';
      default:
        return platformType;
    }
  }
}

class PlatformLink {
  final String type;
  String username;
  String url;

  PlatformLink({
    required this.type,
    required this.username,
    required this.url,
  });
}