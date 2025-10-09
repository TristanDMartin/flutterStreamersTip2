import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'qr_scanner_view.dart';
import 'package:qr_flutter/qr_flutter.dart';
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

  @override
  void initState() {
    super.initState();
    _generateQRCode();
  }

  void _generateQRCode() {
    // Generate profile URL
    // cspell:ignore streamerstip streamercard
    final profileURL = "streamerstip://streamercard/${widget.user['id']}";
    setState(() {
      _shareURL = profileURL;
      _isLoadingQR = false;
    });
  }

  void _handleScannedCode(String code) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Scanned: $code')),
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

  void _showShareOptions() {
    if (_shareURL != null) {
      final String shareText =
          'Check out ${widget.user['displayName']} (@${widget.user['username']}) on StreamersTip!';

      // Simple share options without using ShareSheetView (which is for videos)
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (context) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Share Profile',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 20),
                ListTile(
                  leading: const Icon(Icons.link),
                  title: const Text('Copy Link'),
                  onTap: () {
                    _copyProfileLink();
                    Navigator.of(context).pop();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.share),
                  title: const Text('Share'),
                  onTap: () {
                    // Use system share
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ),
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF6137EB), // Purple
              Color(0xFF1C135D), // Dark purple
            ],
          ),
        ),
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
            width: 250,
            height: 250,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
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
          )
        else if (_shareURL != null)
          Container(
            width: 300,
            height: 300,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: QrImageView(
                data: _shareURL!,
                version: QrVersions.auto,
                backgroundColor: Colors.white,
                gapless: false,
              ),
            ),
          ),
        const SizedBox(height: 20),
        Text(
          'Share this QR code with others to connect',
          style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 16,
              fontWeight: FontWeight.w600),
          textAlign: TextAlign.center,
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
              height: 48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: const LinearGradient(
                  colors: [Color(0x66FFFFFF), Color(0x33FFFFFF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.link, color: Colors.white, size: 20),
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
              height: 48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: const LinearGradient(
                  colors: [Color(0x66FFFFFF), Color(0x33FFFFFF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.share, color: Colors.white, size: 20),
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
