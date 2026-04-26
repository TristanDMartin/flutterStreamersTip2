import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'qr_scanner_view.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../constants/app_colors.dart';
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
    final userId = (widget.user['id'] ?? '').toString().trim();
    if (userId.isNotEmpty) {
      return ProfileLinkService.webProfileUrlById(userId);
    }

    final username = (widget.user['username'] ?? '').toString().trim();
    if (username.isNotEmpty) {
      return ProfileLinkService.webProfileUrlByUsername(username);
    }

    return ProfileLinkService.webBaseUrl;
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
        const SnackBar(content: Text('That QR code is not a StreamersTip profile link.')),
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
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the share sheet right now.')),
      );
    }
  }

  void _showShareOptions() {
    if (_shareURL != null) {
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (context) {
          return Container(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
            decoration: BoxDecoration(
              color: AppColors.profileViewBackground.withValues(alpha: 0.98),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(28)),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.12),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.24),
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
                    color: Colors.white.withValues(alpha: 0.24),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 18),
                Column(
                  children: [
                    const Text(
                      'Share Profile',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Choose how you want to send this profile.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.68),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                _buildShareOptionTile(
                  icon: Icons.link_rounded,
                  title: 'Copy Link',
                  subtitle: 'Grab the profile URL for messages or posts',
                  onTap: () {
                    _copyProfileLink();
                    Navigator.of(context).pop();
                  },
                ),
                const SizedBox(height: 12),
                _buildShareOptionTile(
                  icon: Icons.share_rounded,
                  title: 'Share Link',
                  subtitle: 'Open the native share sheet',
                  onTap: () {
                    Navigator.of(context).pop();
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

  Widget _buildShareOptionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.12),
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
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.66),
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
              color: Colors.white.withValues(alpha: 0.72),
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
        color: AppColors.profileViewBackground,
        child: SafeArea(
          child: Column(
            children: [
              // Top navigation bar
              _buildTopNavigation(),

              // Main content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      const SizedBox(height: 20),

                      // Profile section
                      _buildProfileSection(),

                      const SizedBox(height: 30),

                      // QR Code section
                      _buildQRCodeSection(),

                      const SizedBox(height: 30),

                      // Action buttons
                      _buildActionButtonsSection(),

                      const SizedBox(height: 40),

                      // Bottom text
                      _buildBottomText(),
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

  Widget _buildTopNavigation() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          IconButton(
            onPressed: widget.dismiss,
            icon: const Icon(
              Icons.arrow_back,
              color: Colors.white,
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
            icon: const Icon(
              Icons.qr_code_scanner,
              color: Colors.white,
              size: 24,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileSection() {
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
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black,
            ),
            child: widget.user['avatarURL'] != null
                ? ClipOval(
                    child: Image.network(
                      widget.user['avatarURL'],
                      width: 110,
                      height: 110,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.person,
                        color: Colors.grey,
                        size: 48,
                      ),
                    ),
                  )
                : const Icon(
                    Icons.person,
                    color: Colors.grey,
                    size: 48,
                  ),
          ),
        ),

        const SizedBox(height: 16),

        Column(
          children: [
            Text(
              widget.user['displayName'] ?? '',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '@${widget.user['username'] ?? ''}',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQRCodeSection() {
    return Column(
      children: [
        if (_isLoadingQR)
          Container(
            width: 320,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.12),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
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
                  child: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                          color: Colors.grey,
                          strokeWidth: 3,
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Loading QR Code...',
                          style: TextStyle(
                            color: Colors.grey,
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
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.12),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
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
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Share it in person or drop the link below.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.68),
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
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.12),
              width: 1,
            ),
          ),
          child: Text(
            'Share this QR code with others to connect',
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.76),
                fontSize: 15,
                fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtonsSection() {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: _copyProfileLink,
            child: Container(
              height: 52,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.12),
                  width: 1,
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.link_rounded, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text('Copy link',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700)),
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
                  color: Colors.white24,
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
                  Text('Share link',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomText() {
    return Container(
      padding: const EdgeInsets.only(bottom: 40),
      child: Text(
        'Connect with like minded friends on StreamersTip',
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.8),
          fontSize: 12,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
