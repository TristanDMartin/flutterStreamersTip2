import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'qr_scanner_view.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../constants/app_colors.dart';
import '../components/onboarding/onboarding_mission_actions.dart';
import '../services/profile_link_service.dart';
import '../services/url_handler_service.dart';
// Removed qr_flutter to avoid missing dependency for now

class ShareProfileView extends StatefulWidget {
  final Map<String, dynamic> user;
  final VoidCallback dismiss;

  const ShareProfileView({
    super.key,
    required this.user,
    required this.dismiss,
  });

  @override
  State<ShareProfileView> createState() => _ShareProfileViewState();
}

class _ShareProfileViewState extends State<ShareProfileView> {
  String? _shareURL;
  bool _isLoadingQR = true;

  String _buildProfileUrl() {
    final String username = (widget.user['username'] ?? '').toString().trim();
    final String userId = (widget.user['id'] ?? '').toString().trim();
    return ProfileLinkService.publicProfileUrl(
      username: username,
      userId: userId,
    );
  }

  String _buildShareText() {
    final displayName = (widget.user['displayName'] ?? '').toString().trim();
    final username = (widget.user['username'] ?? '').toString().trim();
    final profileLabel = displayName.isNotEmpty
        ? displayName
        : username.isNotEmpty
            ? '@$username'
            : 'this creator';
    final link = _shareURL ?? _buildProfileUrl();
    return 'Check out $profileLabel on StreamersTip!\n$link';
  }

  @override
  void initState() {
    super.initState();
    _generateQRCode();
  }

  void _generateQRCode() {
    final profileURL = _buildProfileUrl();
    setState(() {
      _shareURL = profileURL;
      _isLoadingQR = false;
    });
  }

  void _handleScannedCode(String code) {
    final normalized = ProfileLinkService.normalizeIncomingProfileLink(code);
    if (!normalized.startsWith(ProfileLinkService.appScheme)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('That QR code is not a StreamersTip profile link.')),
      );
      return;
    }

    URLHandlerService.shared.handleURL(normalized);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Opening profile...')),
    );
  }

  void _copyProfileLink() {
    if (_shareURL != null) {
      Clipboard.setData(ClipboardData(text: _shareURL!));
      OnboardingMissionActions.complete('share_creator_card');
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile link copied to clipboard!')),
      );
    }
  }

  Future<void> _shareProfile() async {
    final shareURL = _shareURL;
    if (shareURL == null) return;

    try {
      await SharePlus.instance.share(
        ShareParams(
          text: _buildShareText(),
          subject: 'StreamersTip profile',
        ),
      );
      await OnboardingMissionActions.complete('share_creator_card');
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Could not open the share sheet right now.')),
      );
    }
  }

  void _showShareOptions() {
    if (_shareURL != null) {
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (BuildContext sheetContext) {
          final ColorScheme cs = Theme.of(sheetContext).colorScheme;
          return Container(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
            decoration: BoxDecoration(
              color: cs.surface.withValues(alpha: 0.98),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(28)),
              border: Border.all(
                color: cs.outline.withValues(alpha: 0.45),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: cs.shadow.withValues(alpha: 0.22),
                  blurRadius: 28,
                  offset: const Offset(0, -10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cs.onSurface.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 18),
                Column(
                  children: [
                    Text(
                      'Share Profile',
                      style: TextStyle(
                        color: cs.onSurface,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Choose how you want to send this profile.',
                      style: TextStyle(
                        color: cs.onSurface.withValues(alpha: 0.68),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                _buildShareOptionTile(
                  sheetContext,
                  icon: Icons.link_rounded,
                  title: 'Copy Link',
                  subtitle: 'Grab the profile URL for messages or posts',
                  onTap: () {
                    _copyProfileLink();
                    Navigator.of(sheetContext).pop();
                  },
                ),
                const SizedBox(height: 12),
                _buildShareOptionTile(
                  sheetContext,
                  icon: Icons.share_rounded,
                  title: 'Share Link',
                  subtitle: 'Open the native share sheet',
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _shareProfile();
                  },
                ),
              ],
            ),
          );
        },
      );
    }
  }

  Widget _buildShareOptionTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        decoration: BoxDecoration(
          color: cs.onSurface.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: cs.outline.withValues(alpha: 0.35),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: AppColors.supportAccentGradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: cs.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: cs.onSurface.withValues(alpha: 0.66),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: cs.onSurface.withValues(alpha: 0.5),
              size: 15,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: Theme.of(context).colorScheme.surface,
        child: SafeArea(
          child: Column(
            children: [
              // Top navigation bar
              _buildTopNavigation(context),

              // Main content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      const SizedBox(height: 20),

                      // Profile section
                      _buildProfileSection(context),

                      const SizedBox(height: 30),

                      // QR Code section
                      _buildQRCodeSection(context),

                      const SizedBox(height: 30),

                      // Action buttons
                      _buildActionButtonsSection(context),

                      const SizedBox(height: 40),

                      // Bottom text
                      _buildBottomText(context),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopNavigation(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          IconButton(
            onPressed: widget.dismiss,
            icon: Icon(
              Icons.arrow_back,
              color: cs.onSurface,
              size: 24,
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => QRScannerView(
                    onCodeScanned: _handleScannedCode,
                  ),
                ),
              );
            },
            icon: Icon(
              Icons.qr_code_scanner,
              color: cs.onSurface,
              size: 24,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileSection(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        // Avatar with gradient border
        Container(
          width: 120,
          height: 120,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [
                Color(0xFF25E5D2),
                Color(0xFF8B5CF6),
                Color(0xFFEC4899),
                Color(0xFF25E5D2),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Container(
            margin: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: cs.surfaceContainerHighest,
            ),
            child: widget.user['avatarURL'] != null
                ? ClipOval(
                    child: Image.network(
                      widget.user['avatarURL'],
                      width: 110,
                      height: 110,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Icon(
                        Icons.person,
                        color: cs.onSurface.withValues(alpha: 0.45),
                        size: 48,
                      ),
                    ),
                  )
                : Icon(
                    Icons.person,
                    color: cs.onSurface.withValues(alpha: 0.45),
                    size: 48,
                  ),
          ),
        ),

        const SizedBox(height: 16),

        Column(
          children: [
            Text(
              widget.user['displayName'] ?? '',
              style: TextStyle(
                color: cs.onSurface,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '@${widget.user['username'] ?? ''}',
              style: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.72),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQRCodeSection(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        if (_isLoadingQR)
          Container(
            width: 320,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cs.onSurface.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: cs.outline.withValues(alpha: 0.35),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: cs.shadow.withValues(alpha: 0.14),
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: AspectRatio(
              aspectRatio: 1,
              child: Center(
                child: Container(
                  width: 248,
                  height: 248,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                          color: cs.primary,
                          strokeWidth: 3,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Loading QR Code...',
                          style: TextStyle(
                            color: cs.onSurface.withValues(alpha: 0.55),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          )
        else if (_shareURL != null)
          Container(
            width: 320,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: cs.onSurface.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: cs.outline.withValues(alpha: 0.35),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: cs.shadow.withValues(alpha: 0.14),
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              children: [
                Center(
                  child: Container(
                    width: 248,
                    height: 248,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: QrImageView(
                        data: _shareURL!,
                        version: QrVersions.auto,
                        backgroundColor: Colors.white,
                        gapless: false,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Scan to open this profile',
                  style: TextStyle(
                    color: cs.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Share it in person or drop the link below.',
                  style: TextStyle(
                    color: cs.onSurface.withValues(alpha: 0.68),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(
            color: cs.onSurface.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: cs.outline.withValues(alpha: 0.35),
              width: 1,
            ),
          ),
          child: Text(
            'Share this QR code with others to connect',
            style: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.72),
                fontSize: 15,
                fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtonsSection(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: _copyProfileLink,
            child: Container(
              height: 52,
              decoration: BoxDecoration(
                color: cs.onSurface.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: cs.outline.withValues(alpha: 0.35),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.link_rounded, color: cs.onSurface, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Copy link',
                    style: TextStyle(
                      color: cs.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: GestureDetector(
            onTap: _showShareOptions,
            child: Container(
              height: 52,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: const LinearGradient(
                  colors: AppColors.supportAccentGradient,
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.35),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.supportAccent.withValues(alpha: 0.22),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.share_rounded, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Share link',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomText(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.only(bottom: 40),
      child: Text(
        'Connect with like minded friends on StreamersTip',
        style: TextStyle(
          color: cs.onSurface.withValues(alpha: 0.72),
          fontSize: 12,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
