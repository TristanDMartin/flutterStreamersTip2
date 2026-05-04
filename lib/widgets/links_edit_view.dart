import 'package:flutter/material.dart';
import 'brand_icons.dart';
import '../constants/app_colors.dart';
import '../core/theme/support_shell_style.dart';

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
  final Set<String> _expandedPlatformTypes = <String>{};

  // Allowed platform types matching your design system
  static const List<String> _allowedPlatforms = [
    'twitch',
    'youtube',
    'kick',
    'tiktok',
    'instagram',
    'twitter',
    'discord',
    'bluesky',
    'reddit',
    'facebook',
    'other'
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

    _expandedPlatformTypes
      ..clear()
      ..addAll(
        _platformLinks.where((link) => !link.isLinked).map((link) => link.type),
      );
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
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    return Scaffold(
      backgroundColor: shell.scaffold,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 8),
                      child: Text(
                        'Connect your platforms',
                        style: TextStyle(
                          color: shell.muted,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    for (int i = 0; i < _platformLinks.length; i++) ...[
                      _buildPlatformLinkRow(_platformLinks[i], i),
                      if (i < _platformLinks.length - 1)
                        const SizedBox(height: 12),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: shell.surfaceCard,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: shell.surfaceCardBorder,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            IconButton(
              onPressed: widget.onBack ?? () => Navigator.pop(context),
              icon: Icon(Icons.arrow_back, color: shell.onChrome, size: 22),
            ),
            Expanded(
              child: Text(
                'Edit links',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: shell.onChrome,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            TextButton(
              onPressed: _saveLinks,
              child: const Text(
                'Save',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlatformLinkRow(PlatformLink link, int index) {
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    final isExpanded =
        !link.isLinked || _expandedPlatformTypes.contains(link.type);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: shell.surfaceCard,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: shell.surfaceCardBorder,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: link.isLinked
                ? () {
                    setState(() {
                      if (isExpanded) {
                        _expandedPlatformTypes.remove(link.type);
                      } else {
                        _expandedPlatformTypes.add(link.type);
                      }
                    });
                  }
                : null,
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: shell.skeletonFill,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: _buildPlatformIcon(link.type),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getPlatformDisplayName(link.type),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        link.isLinked
                            ? (link.username.isNotEmpty
                                ? '@${link.username}'
                                : link.url)
                            : 'Add a username and direct profile link',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.62),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (link.isLinked) ...[
                  const SizedBox(width: 10),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: AppColors.supportAccentGradient,
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'Linked',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: Colors.white.withValues(alpha: 0.72),
                  ),
                ],
              ],
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOutCubic,
            child: isExpanded
                ? Column(
                    children: [
                      const SizedBox(height: 16),
                      _buildInputField(
                        label: 'Username',
                        value: link.username,
                        hintText: 'Enter username',
                        onChanged: (value) {
                          setState(() {
                            link.username = value;
                            if (link.isLinked) {
                              _expandedPlatformTypes.add(link.type);
                            }
                          });
                        },
                        onClear: () {
                          setState(() {
                            link.username = '';
                            if (!link.isLinked) {
                              _expandedPlatformTypes.add(link.type);
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      _buildInputField(
                        label: 'URL',
                        value: link.url,
                        hintText: 'Enter URL',
                        keyboardType: TextInputType.url,
                        onChanged: (value) {
                          setState(() {
                            link.url = value;
                            if (link.isLinked) {
                              _expandedPlatformTypes.add(link.type);
                            }
                          });
                        },
                        onClear: () {
                          setState(() {
                            link.url = '';
                            if (!link.isLinked) {
                              _expandedPlatformTypes.add(link.type);
                            }
                          });
                        },
                      ),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.10),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.64),
              fontSize: 14,
              fontWeight: FontWeight.w600,
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
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.35),
                ),
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
    return BrandIcon(
      platformType: platformType,
      size: 24.0,
    );
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
        return 'X';
      case 'discord':
        return 'Discord';
      case 'instagram':
        return 'Instagram';
      case 'reddit':
        return 'Reddit';
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

  bool get isLinked => username.trim().isNotEmpty || url.trim().isNotEmpty;
}
