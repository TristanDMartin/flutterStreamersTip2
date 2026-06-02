import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/feature_flags.dart';
import '../models/home_video.dart';
import '../services/share_service_optimized.dart';
import 'video_qr_code_dialog.dart';

class ShareSheetOptimized extends StatefulWidget {
  final HomeVideo video;
  final VoidCallback? onDismiss;

  const ShareSheetOptimized({
    super.key,
    required this.video,
    this.onDismiss,
  });

  @override
  State<ShareSheetOptimized> createState() => _ShareSheetOptimizedState();
}

class _ShareSheetOptimizedState extends State<ShareSheetOptimized> {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: const BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Drag indicator bar
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[600],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          _buildHeader(),

          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                children: [
                  // Quick Actions
                  _buildQuickActions(),

                  const SizedBox(height: 24),

                  // Social Platforms
                  _buildSocialPlatforms(),

                  const SizedBox(height: 24),

                  // More Options
                  _buildMoreOptions(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          TextButton(
            onPressed: widget.onDismiss,
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
          const Expanded(
            child: Text(
              'Share Video',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 60), // Balance the cancel button
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildActionButton(
                icon: Icons.share,
                label: 'Share',
                onTap: _shareVideo,
                color: const Color(0xFF9248D2),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildActionButton(
                icon: Icons.link,
                label: 'Copy Link',
                onTap: _copyLink,
                color: Colors.blue,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSocialPlatforms() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Social Platforms',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1,
          ),
          itemCount: SharePlatform.values.length,
          itemBuilder: (context, index) {
            final platform = SharePlatform.values[index];
            return _buildPlatformButton(platform);
          },
        ),
      ],
    );
  }

  Widget _buildMoreOptions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'More Options',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        if (FeatureFlags.videoDownload) ...[
          _buildActionButton(
            icon: Icons.download,
            label: 'Download Video',
            onTap: _downloadVideo,
            color: Colors.green,
          ),
          const SizedBox(height: 12),
        ],
        _buildActionButton(
          icon: Icons.qr_code,
          label: 'Generate QR Code',
          onTap: _generateQRCode,
          color: Colors.orange,
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color color,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[800]!),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlatformButton(SharePlatform platform) {
    return GestureDetector(
      onTap: () => _shareToPlatform(platform),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[800]!),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              platform.icon,
              color: platform.color,
              size: 28,
            ),
            const SizedBox(height: 8),
            Text(
              platform.displayName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // Action handlers
  Future<void> _shareVideo() async {
    HapticFeedback.lightImpact();

    try {
      await ShareServiceOptimized().shareVideo(widget.video);
      widget.onDismiss?.call();
    } catch (e) {
      // appLog('Error sharing video: $e');
    }
  }

  Future<void> _copyLink() async {
    HapticFeedback.lightImpact();
    final shareUrl = 'https://streamerstip.com/video/${widget.video.id}';
    await ShareServiceOptimized().copyLink(widget.video.id, shareUrl);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Link copied to clipboard'),
          backgroundColor: Color(0xFF9248D2),
          duration: Duration(seconds: 2),
        ),
      );
    }

    widget.onDismiss?.call();
  }

  Future<void> _shareToPlatform(SharePlatform platform) async {
    HapticFeedback.lightImpact();

    try {
      await ShareServiceOptimized().shareToPlatform(widget.video, platform);
      widget.onDismiss?.call();
    } catch (e) {
      // appLog('Error sharing to platform: $e');
    }
  }

  void _downloadVideo() {
    HapticFeedback.lightImpact();
    widget.onDismiss?.call();
  }

  void _generateQRCode() {
    HapticFeedback.lightImpact();
    // ✅ FIX: Show QR code dialog
    showDialog<void>(
      context: context,
      builder: (context) => VideoQRCodeDialog(
        video: widget.video,
      ),
    );
    widget.onDismiss?.call();
  }
}
