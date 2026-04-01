import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/home_video.dart';
import '../models/share_payload.dart';
import '../services/enhanced_share_service.dart';
import '../services/report_service.dart';
import '../constants/app_colors.dart';
import 'connections_row.dart';
import 'connections_search_overlay.dart';
import 'video_qr_code_dialog.dart';

class EnhancedShareSheet extends StatefulWidget {
  final HomeVideo video;
  final VoidCallback? onClose;
  final Function(String videoId, String creatorId)? onReport;
  final Function(String videoId, String creatorId)? onBlock;
  final Function(String videoId, String creatorId)? onNotInterested;
  final Function(String videoId, String creatorId)? onFavorite;

  const EnhancedShareSheet({
    super.key,
    required this.video,
    this.onClose,
    this.onReport,
    this.onBlock,
    this.onNotInterested,
    this.onFavorite,
  });

  @override
  State<EnhancedShareSheet> createState() => _EnhancedShareSheetState();
}

class _EnhancedShareSheetState extends State<EnhancedShareSheet>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late AnimationController _fadeController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  SharePayload? _sharePayload;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadShareData();
  }

  void _initializeAnimations() {
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    ));

    _slideController.forward();
    _fadeController.forward();
  }

  Future<void> _loadShareData() async {
    try {
      // Load share payload
      final payload =
          await EnhancedShareService().fetchSharePayload(widget.video);

      if (mounted) {
        setState(() {
          _sharePayload = payload;
          _isLoading = false;
        });

        // Connection avatars will be loaded by ConnectionsRow
      }
    } catch (e) {
      log('❌ EnhancedShareSheet: Error loading share data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _slideController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _closeSheet() async {
    await Future.wait([
      _slideController.reverse(),
      _fadeController.reverse(),
    ]);
    if (mounted) {
      widget.onClose?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _fadeAnimation,
      builder: (context, child) {
        return Container(
          color: Colors.black.withValues(
            alpha: 0.5 * _fadeAnimation.value,
          ),
          child: SlideTransition(
            position: _slideAnimation,
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.6,
              ),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    AppColors.primary, // #9248D2 Purple
                    AppColors.secondary, // #7768DF Purple variant
                    AppColors.tertiary, // #1670DE Blue
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: _isLoading ? _buildLoadingView() : _buildShareContent(),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLoadingView() {
    return const SizedBox(
      height: 200,
      child: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  Widget _buildShareContent() {
    if (_sharePayload == null) {
      return _buildErrorView();
    }

    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildSwipeHandle(),
          _buildHeader(),
          _buildConnectionsRow(),
          const SizedBox(height: 30),
          _buildShareTargets(),
          const SizedBox(height: 12),
          _buildDivider(),
          const SizedBox(height: 8),
          _buildActionButtons(),
          const SizedBox(height: 12),
          _buildBottomPadding(),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return const SizedBox(
      height: 200,
      child: Center(
        child: Text('Failed to load share options'),
      ),
    );
  }

  Widget _buildSwipeHandle() {
    return Container(
      width: 40,
      height: 4,
      margin: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Send to',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: _closeSheet,
          ),
        ],
      ),
    );
  }

  Widget _buildShareTargets() {
    final targets = EnhancedShareService().getRankedTargets();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: targets.map((target) => _buildShareTarget(target)).toList(),
      ),
    );
  }

  Widget _buildShareTarget(ShareTarget target) {
    return GestureDetector(
      onTap: () => _handleShareTarget(target),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Icon(
              _getTargetIcon(target),
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            target.displayName,
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
    );
  }

  Widget _buildConnectionsRow() {
    return ConnectionsRow(
      videoId: widget.video.id,
      shareToken: _sharePayload?.trackingToken ?? '',
      onSearchTap: _openConnectionsSearch,
      onConnectionTap: _onConnectionTapped,
    );
  }

  Widget _buildActionButtons() {
    final actionButtons = <Widget>[
      _buildActionButton(
        icon: Icons.qr_code,
        label: 'QR Code',
        onTap: _handleQRCode,
      ),
      _buildActionButton(
        icon: Icons.report_outlined,
        label: 'Report',
        onTap: _handleReport,
      ),
    ];

    if (widget.onFavorite != null) {
      actionButtons.insert(
        1,
        _buildActionButton(
          icon: Icons.favorite_border,
          label: 'Favorite',
          onTap: _handleFavorite,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: actionButtons,
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 55,
            height: 55,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(27.5),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 1,
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      color: Colors.white.withValues(alpha: 0.2),
    );
  }

  Widget _buildBottomPadding() {
    return SizedBox(
      height: MediaQuery.of(context).padding.bottom + 4,
    );
  }

  void _openConnectionsSearch() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ConnectionsSearchOverlay(
          videoId: widget.video.id,
          shareToken: _sharePayload?.metadata.creatorUsername ?? '',
          onConnectionSelected: _onConnectionTapped,
        ),
        fullscreenDialog: true,
      ),
    );
  }

  void _onConnectionTapped(String recipientId) {
    log('📤 EnhancedShareSheet: Sending to connection $recipientId');
    _showSuccessSnackBar('Video sent!');
    _closeSheet(); // Close the share sheet after sending
  }

  void _handleShareTarget(ShareTarget target) async {
    if (_sharePayload == null) return;

    try {
      await EnhancedShareService().shareToTarget(target, _sharePayload!);
      await _closeSheet();
    } catch (e) {
      log('❌ EnhancedShareSheet: Error sharing to ${target.displayName}: $e');
      _showErrorSnackBar('Failed to share to ${target.displayName}');
    }
  }

  void _handleFavorite() {
    if (widget.onFavorite == null) return;
    widget.onFavorite?.call(widget.video.id, widget.video.creator.id);
    _showSuccessSnackBar('Added to favorites');
  }

  void _handleQRCode() {
    HapticFeedback.lightImpact();
    // ✅ FIX: Show QR code dialog
    Navigator.pop(context); // Close share sheet first
    showDialog<void>(
      context: context,
      builder: (context) => VideoQRCodeDialog(
        video: widget.video,
        shareUrl: _sharePayload?.links.webShareUrl,
      ),
    );
  }

  void _handleReport() async {
    // ✅ FIX: Check if user has already reported this video before showing dialog
    try {
      final hasReported = await ReportService().hasUserReportedVideo(widget.video.id);
      if (hasReported) {
        _showErrorSnackBar('You have already reported this video');
        return;
      }
    } catch (e) {
      debugPrint('❌ Error checking report status: $e');
      // Continue anyway - let user try to report
    }
    
    _showReportDialog();
  }

  void _showReportDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _buildReportSheet(),
    );
  }

  Widget _buildReportSheet() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Title
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Text(
              'Why are you reporting this video?',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          // Report options
          _buildReportOptions(),

          // Cancel button
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(20),
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                  color: Colors.white.withValues(alpha: 0.2),
                ),
                ),
              ),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportOptions() {
    final reportReasons = [
      'Spam',
      'Nudity or sexual activity',
      'Violence or dangerous acts',
      'Hate speech or harassment',
      'Dangerous goods or services',
      'Bullying or harassment',
      'Intellectual property violation',
      'False information',
      'Self-harm or suicide',
      'Terrorism',
      'Other',
    ];

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: reportReasons.length,
      itemBuilder: (context, index) {
        final reason = reportReasons[index];
        return ListTile(
          title: Text(
            reason,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w400,
            ),
          ),
          onTap: () => _handleReportReason(reason),
          trailing: const Icon(
            Icons.arrow_forward_ios,
            color: Colors.white54,
            size: 16,
          ),
        );
      },
    );
  }

  void _handleReportReason(String reason) async {
    try {
      // Close the report dialog
      Navigator.pop(context);

      // Submit the report to the service
      await ReportService().reportVideo(
        videoId: widget.video.id,
        creatorId: widget.video.creator.id,
        reason: reason,
      );

      // Close the share sheet
      _closeSheet();

      // Call the report callback
      widget.onReport?.call(widget.video.id, widget.video.creator.id);

      // Show confirmation
      _showSuccessSnackBar('Report submitted: $reason');

      // Log the report for analytics
      debugPrint('📋 Report submitted for video ${widget.video.id}: $reason');
    } catch (e) {
      debugPrint('❌ Error submitting report: $e');
      _showErrorSnackBar('Failed to submit report: ${e.toString()}');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  IconData _getTargetIcon(ShareTarget target) {
    switch (target) {
      case ShareTarget.copyLink:
        return Icons.link;
      case ShareTarget.instagramDirect:
        return Icons.camera_alt;
      case ShareTarget.sms:
        return Icons.message;
      case ShareTarget.whatsapp:
        return Icons.chat;
      case ShareTarget.repost:
        return Icons.repeat;
      case ShareTarget.facebook:
        return Icons.facebook;
      case ShareTarget.twitter:
        return Icons.flutter_dash;
      case ShareTarget.telegram:
        return Icons.send;
      case ShareTarget.email:
        return Icons.email;
      case ShareTarget.more:
        return Icons.more_horiz;
    }
  }
}
