import 'dart:async';
import 'dart:developer';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/home_video.dart';
import '../models/share_payload.dart';
import '../services/enhanced_share_service.dart';
import '../services/report_service.dart';
import '../constants/app_colors.dart';
import 'connections_row.dart';
import 'connections_search_overlay.dart';
import 'share_sheet_brand_icon.dart';
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
  late AnimationController _chipEntranceController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  SharePayload? _sharePayload;
  bool _isLoading = true;
  Timer? _toastTimer;
  String? _toastMessage;
  bool _toastIsError = false;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadShareData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      HapticFeedback.lightImpact();
    });
  }

  void _initializeAnimations() {
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 340),
      vsync: this,
    );
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 220),
      vsync: this,
    );
    _chipEntranceController = AnimationController(
      duration: const Duration(milliseconds: 520),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutQuart,
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
        try {
          EnhancedShareService().trackShareSheetOpen(widget.video.id);
        } catch (_) {}
        setState(() {
          _sharePayload = payload;
          _isLoading = false;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _chipEntranceController.forward(from: 0);
          }
        });
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
    _toastTimer?.cancel();
    _slideController.dispose();
    _fadeController.dispose();
    _chipEntranceController.dispose();
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
            alpha: 0.62 * _fadeAnimation.value,
          ),
          child: SlideTransition(
            position: _slideAnimation,
            child: ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                child: Container(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.62,
                  ),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(
                        color: Colors.white.withValues(alpha: 0.12),
                      ),
                    ),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        const Color(0xFF2C2C2E)
                            .withValues(alpha: 0.97),
                        const Color(0xFF121212)
                            .withValues(alpha: 0.98),
                      ],
                    ),
                  ),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned.fill(
                        child: _isLoading
                            ? _buildLoadingView()
                            : _buildShareContent(),
                      ),
                      if (_toastMessage != null) _buildToastBanner(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildToastBanner() {
    return Positioned(
      left: 16,
      right: 16,
      bottom: MediaQuery.of(context).padding.bottom + 12,
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: _toastIsError
                ? const Color(0xFF3D1518).withValues(alpha: 0.95)
                : const Color(0xFF1A2E1F).withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _toastIsError
                  ? AppColors.error.withValues(alpha: 0.45)
                  : AppColors.success.withValues(alpha: 0.35),
            ),
          ),
          child: Text(
            _toastMessage!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingView() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(height: 22),
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              height: 18,
              width: 120,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 86,
            child: Row(
              children: List<Widget>.generate(
                5,
                (int i) => Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: i < 4 ? 10 : 0),
                    child: Column(
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.08),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          height: 10,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
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
          const SizedBox(height: 20),
          _buildShareTargets(),
          const SizedBox(height: 10),
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
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: SelectableText.rich(
          TextSpan(
            children: <InlineSpan>[
              const WidgetSpan(
                child: Icon(
                  Icons.cloud_off_outlined,
                  color: AppColors.error,
                  size: 22,
                ),
              ),
              TextSpan(
                text: '  Could not load share options.\n',
                style: TextStyle(
                  color: AppColors.error.withValues(alpha: 0.95),
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              TextSpan(
                text: 'Check your connection and try again.',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildSwipeHandle() {
    return Container(
      width: 36,
      height: 5,
      margin: const EdgeInsets.only(top: 10, bottom: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 4, 8, 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Send to',
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.close,
              color: Colors.white.withValues(alpha: 0.92),
              size: 22,
            ),
            onPressed: _closeSheet,
          ),
        ],
      ),
    );
  }

  Widget _buildShareTargets() {
    final List<ShareTarget> targets =
        EnhancedShareService().getRankedTargets();
    return SizedBox(
      height: 92,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        physics: const BouncingScrollPhysics(),
        itemCount: targets.length,
        separatorBuilder: (_, __) => const SizedBox(width: 4),
        itemBuilder: (BuildContext context, int index) {
          return _buildShareTargetStaggered(
            targets[index],
            index,
            targets.length,
          );
        },
      ),
    );
  }

  Color _brandFillFor(ShareTarget target) {
    switch (target) {
      case ShareTarget.copyLink:
        return const Color(0xFF3A3A3C);
      case ShareTarget.instagramDirect:
        return AppColors.instagram;
      case ShareTarget.sms:
        return const Color(0xFF34C759);
      case ShareTarget.whatsapp:
        return const Color(0xFF25D366);
      case ShareTarget.repost:
        return AppColors.primary;
      case ShareTarget.facebook:
        return AppColors.facebook;
      case ShareTarget.twitter:
        return AppColors.twitter;
      case ShareTarget.telegram:
        return const Color(0xFF0088CC);
      case ShareTarget.email:
        return const Color(0xFF5E5CE6);
      case ShareTarget.more:
        return const Color(0xFF48484A);
    }
  }

  Widget _buildShareTargetStaggered(
    ShareTarget target,
    int index,
    int total,
  ) {
    final double start = index * (0.42 / math.max(total, 1));
    final double end = (start + 0.58).clamp(0.0, 1.0);
    final Animation<double> interval = CurvedAnimation(
      parent: _chipEntranceController,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );
    return FadeTransition(
      opacity: interval,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.14),
          end: Offset.zero,
        ).animate(interval),
        child: _buildShareTarget(target),
      ),
    );
  }

  Widget _buildShareTarget(ShareTarget target) {
    final Color fill = _brandFillFor(target);
    return Semantics(
      button: true,
      label: target.displayName,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _handleShareTarget(target),
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: 72,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: fill,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: ShareSheetBrandIcon(
                      target: target,
                      size: 26,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  target.displayName,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.92),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.1,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.14),
                ),
              ),
              child: Icon(
                icon,
                color: Colors.white.withValues(alpha: 0.95),
                size: 22,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.88),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 1,
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
      color: Colors.white.withValues(alpha: 0.1),
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
    HapticFeedback.selectionClick();
    _showSheetToast('Video sent');
    _closeSheet();
  }

  void _showSheetToast(String message, {bool isError = false}) {
    _toastTimer?.cancel();
    setState(() {
      _toastMessage = message;
      _toastIsError = isError;
    });
    _toastTimer = Timer(const Duration(milliseconds: 2200), () {
      if (mounted) {
        setState(() => _toastMessage = null);
      }
    });
  }

  Future<void> _handleShareTarget(ShareTarget target) async {
    if (_sharePayload == null) {
      return;
    }
    HapticFeedback.selectionClick();
    try {
      await EnhancedShareService().shareToTarget(target, _sharePayload!);
      if (!mounted) {
        return;
      }
      if (target == ShareTarget.copyLink ||
          target == ShareTarget.more) {
        _showSheetToast(
          target == ShareTarget.copyLink ? 'Link copied' : 'Share opened',
        );
        await Future<void>.delayed(const Duration(milliseconds: 240));
      }
      await _closeSheet();
    } catch (e) {
      log('❌ EnhancedShareSheet: Error sharing to ${target.displayName}: $e');
      _showSheetToast(
        'Could not share to ${target.displayName}',
        isError: true,
      );
    }
  }

  void _handleFavorite() {
    if (widget.onFavorite == null) {
      return;
    }
    HapticFeedback.selectionClick();
    widget.onFavorite?.call(widget.video.id, widget.video.creator.id);
    _showSheetToast('Saved to favorites');
  }

  void _handleQRCode() {
    HapticFeedback.lightImpact();
    if (_sharePayload == null) {
      return;
    }
    showDialog<void>(
      context: context,
      useRootNavigator: true,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (BuildContext context) => VideoQRCodeDialog(
        video: widget.video,
        shareUrl: _sharePayload?.links.webShareUrl,
      ),
    );
  }

  void _handleReport() async {
    try {
      final hasReported =
          await ReportService().hasUserReportedVideo(widget.video.id);
      if (hasReported) {
        _showSheetToast('You already reported this video', isError: true);
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

      await _closeSheet();

      // Call the report callback
      widget.onReport?.call(widget.video.id, widget.video.creator.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Report submitted: $reason'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      // Log the report for analytics
      debugPrint('📋 Report submitted for video ${widget.video.id}: $reason');
    } catch (e) {
      debugPrint('❌ Error submitting report: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: SelectableText.rich(
              TextSpan(
                text: 'Failed to submit report: $e',
                style: const TextStyle(color: Colors.white),
              ),
            ),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

}
