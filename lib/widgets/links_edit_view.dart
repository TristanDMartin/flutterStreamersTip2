import 'package:flutter/material.dart';
import 'brand_icons.dart';
import '../constants/app_colors.dart';
import '../core/theme/support_shell_style.dart';
import '../utils/platform_rules.dart';
import '../utils/playback_route_suppression.dart';

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
  final Map<String, TextEditingController> _usernameControllers =
      <String, TextEditingController>{};
  final Map<String, TextEditingController> _urlControllers =
      <String, TextEditingController>{};

  static const List<String> _allowedPlatforms =
      PlatformRules.editablePlatformTypes;

  @override
  void initState() {
    super.initState();
    PlaybackRouteSuppression.suppress(reason: 'edit_links');
    _setupInitialLinks();
  }

  @override
  void dispose() {
    for (final TextEditingController controller
        in _usernameControllers.values) {
      controller.dispose();
    }
    for (final TextEditingController controller in _urlControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _setupInitialLinks() {
    final Map<String, Map<String, dynamic>> existingPlatforms =
        <String, Map<String, dynamic>>{};
    for (final Map<String, dynamic> platform in widget.platforms) {
      final String type = PlatformRules.normalizePlatformType(
        platform['type'] as String? ?? '',
      );
      existingPlatforms[type] = platform;
    }
    _platformLinks = _allowedPlatforms.map((String type) {
      final Map<String, dynamic>? existing = existingPlatforms[type];
      final String username = existing?['username']?.toString() ?? '';
      final String url = existing?['url']?.toString() ?? '';
      _usernameControllers[type] = TextEditingController(text: username);
      _urlControllers[type] = TextEditingController(text: url);
      _usernameControllers[type]!.addListener(
        () => _onFieldChanged(type),
      );
      _urlControllers[type]!.addListener(
        () => _onFieldChanged(type),
      );
      return PlatformLink(
        type: type,
        username: username,
        url: url,
      );
    }).toList();
    _expandedPlatformTypes
      ..clear()
      ..addAll(
        _platformLinks.where((PlatformLink link) => !link.isLinked).map(
              (PlatformLink link) => link.type,
            ),
      );
  }

  void _onFieldChanged(String type) {
    final PlatformLink link =
        _platformLinks.firstWhere((PlatformLink l) => l.type == type);
    final bool wasLinked = link.isLinked;
    link.username = _usernameControllers[type]!.text;
    link.url = _urlControllers[type]!.text;
    if (wasLinked != link.isLinked) {
      setState(() {});
    }
  }

  void _saveLinks() {
    for (final PlatformLink link in _platformLinks) {
      link.username = _usernameControllers[link.type]!.text.trim();
      link.url = _urlControllers[link.type]!.text.trim();
    }
    final List<Map<String, dynamic>> draft = <Map<String, dynamic>>[];
    for (final PlatformLink link in _platformLinks) {
      if (link.username.isNotEmpty || link.url.isNotEmpty) {
        draft.add(<String, dynamic>{
          'id': DateTime.now().millisecondsSinceEpoch.toString(),
          'type': link.type,
          'username': link.username,
          'followers': 0,
          'url': link.url,
        });
      }
    }
    final String? validationError = PlatformRules.validatePlatformsList(draft);
    if (validationError != null) {
      _showError(validationError);
      return;
    }
    final List<Map<String, dynamic>> updatedPlatforms =
        PlatformRules.normalizePlatformsForSave(draft);
    widget.onPlatformsUpdated(updatedPlatforms);
    Navigator.pop(context);
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: shell.scaffold,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 8,
                      ),
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
                      _buildPlatformLinkRow(_platformLinks[i]),
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

  Widget _buildPlatformLinkRow(PlatformLink link) {
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    final bool isExpanded =
        !link.isLinked || _expandedPlatformTypes.contains(link.type);
    final TextEditingController usernameController =
        _usernameControllers[link.type]!;
    final TextEditingController urlController = _urlControllers[link.type]!;

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
                    child: BrandIcon(
                      platformType: link.type,
                      size: 24,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        PlatformRules.displayNameForType(link.type),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        link.isLinked
                            ? _linkedSubtitle(link)
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
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
                        controller: usernameController,
                        hintText: 'Enter username',
                        onClear: () {
                          usernameController.clear();
                          _onFieldChanged(link.type);
                        },
                      ),
                      const SizedBox(height: 12),
                      _buildInputField(
                        label: 'URL',
                        controller: urlController,
                        hintText: 'Enter URL',
                        keyboardType: TextInputType.url,
                        onClear: () {
                          urlController.clear();
                          _onFieldChanged(link.type);
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
    required TextEditingController controller,
    required String hintText,
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
              controller: controller,
              keyboardType: keyboardType,
              textCapitalization: TextCapitalization.none,
              autocorrect: false,
              enableSuggestions: false,
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
                isDense: true,
              ),
            ),
          ),
          AnimatedBuilder(
            animation: controller,
            builder: (BuildContext context, Widget? child) {
              if (controller.text.isEmpty) {
                return const SizedBox.shrink();
              }
              return GestureDetector(
                onTap: onClear,
                child: const Icon(
                  Icons.clear,
                  color: Colors.grey,
                  size: 20,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  String _linkedSubtitle(PlatformLink link) {
    if (PlatformRules.isAgeRestrictedType(link.type)) {
      return '18+ external link (URL hidden on profile)';
    }
    if (link.username.isNotEmpty) {
      return '@${link.username}';
    }
    return link.url;
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
