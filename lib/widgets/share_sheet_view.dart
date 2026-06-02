import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/home_video.dart';
import '../models/share_payload.dart';
import '../routing/app_navigator.dart';
import '../services/chat_service.dart';
import '../services/share_service_optimized.dart';
import '../services/video_actions_service.dart';
import 'connections_row.dart';
import 'connections_search_overlay.dart';

/// ShareSheetView - TikTok-Style Share Bottom Sheet
///
/// Features:
/// - Video continues playing in background with slight blur
/// - Prefetched SharePayload for instant display
/// - Dynamic platform ranking based on usage
/// - Contextual actions (Report, Block, Message)
/// - Analytics tracking for all interactions
/// - Fast 200ms slide animation
/// - Swipe-down or tap outside to dismiss
class ShareSheetView extends ConsumerStatefulWidget {
  final HomeVideo video;
  final SharePayload? payload;
  final VoidCallback? onDismiss;
  final Function(ShareAction)? onAction;

  const ShareSheetView({
    super.key,
    required this.video,
    this.payload,
    this.onDismiss,
    this.onAction,
  });

  @override
  ConsumerState<ShareSheetView> createState() => _ShareSheetViewState();
}

class _ShareSheetViewState extends ConsumerState<ShareSheetView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;
  late final Animation<double> _animation;
  SharePayload? _payload;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration:
          const Duration(milliseconds: 200), // Fast TikTok-style animation
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );

    _payload = widget.payload;
    _loadPayload();
    _animationController.forward();

    // Track sheet open
    ShareServiceOptimized().trackShareSheetOpen(widget.video.id);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadPayload() async {
    if (_payload != null) return;

    setState(() => _isLoading = true);

    try {
      final payload =
          await ShareServiceOptimized().fetchSharePayload(widget.video);
      if (mounted) {
        setState(() {
          _payload = payload;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _handleDismiss() {
    ShareServiceOptimized().trackShareCancel(widget.video.id);
    _animationController.reverse().then((_) {
      widget.onDismiss?.call();
      Navigator.of(context).pop();
    });
  }

  void _openConnectionsSearch() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ConnectionsSearchOverlay(
          videoId: widget.video.id,
          shareToken: _payload?.metadata.creatorUsername ?? '',
          onConnectionSelected: _onConnectionTapped,
        ),
        fullscreenDialog: true,
      ),
    );
  }

  void _onConnectionTapped(String recipientId) {
    // Analytics tracking for connection tap
    ShareServiceOptimized().trackShareEvent(
      'share_connection_tap',
      widget.video.id,
      'connection_dm',
    );
  }

  Future<void> _handleShareTarget(ShareTarget target) async {
    HapticFeedback.lightImpact();

    if (_payload == null) return;

    // Special handling for copyLink
    if (target == ShareTarget.copyLink) {
      await ShareServiceOptimized().shareToTarget(target, _payload!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Link copied to clipboard'),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.green.shade700,
          ),
        );
      }
      // Don't close sheet for copy link
      return;
    }

    // For other targets, share and close
    await ShareServiceOptimized().shareToTarget(target, _payload!);
    _handleDismiss();
  }

  Future<void> _handleAction(ShareAction action) async {
    HapticFeedback.lightImpact();
    final String videoId = widget.video.id;
    final String creatorId = widget.video.creator.id;
    await ShareServiceOptimized().handleAction(action, videoId, creatorId);
    try {
      switch (action) {
        case ShareAction.sendMessage:
          final chat = await ChatService.shared.fetchOrCreateChat(creatorId);
          if (!mounted) {
            return;
          }
          if (chat == null) {
            _showBriefMessage('Could not open conversation', isError: true);
            return;
          }
          _handleDismiss();
          AppNavigator.openChat(
            context,
            chat: chat,
            otherUserId: creatorId,
            otherUserName: widget.video.creator.displayName.isNotEmpty
                ? widget.video.creator.displayName
                : widget.video.creator.username,
            otherUserAvatarUrl: widget.video.creator.avatarURL,
            otherUserIsOnline: false,
          );
          return;
        case ShareAction.notInterested:
          await ref.read(videoActionsServiceProvider).markNotInterested(
                videoId: videoId,
                creatorId: creatorId,
              );
          if (mounted) {
            _showBriefMessage('Noted. Adjusting recommendations...');
          }
          break;
        case ShareAction.favorite:
          await ref.read(videoActionsServiceProvider).addToFavorites(videoId);
          if (mounted) {
            _showBriefMessage('Added to collection');
          }
          break;
        case ShareAction.report:
        case ShareAction.block:
          break;
      }
    } catch (e) {
      if (mounted) {
        _showBriefMessage('Action failed: $e', isError: true);
      }
    }
    widget.onAction?.call(action);
    if (action != ShareAction.sendMessage) {
      _handleDismiss();
    }
  }

  void _showBriefMessage(String text, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        behavior: SnackBarBehavior.floating,
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    debugPrint(
        '📱 ShareSheetView: build() called - payload: ${_payload != null}, isLoading: $_isLoading');
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Stack(
          children: [
            // A. Background Layer - Video with slight blur + tap to dismiss
            GestureDetector(
              onTap: _handleDismiss,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
                child: Container(
                  color: Colors.black.withValues(alpha: 0.3),
                ),
              ),
            ),

            // B. Middle Layer - Share Bottom Sheet
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 1),
                  end: Offset.zero,
                ).animate(_animation),
                child: _buildShareSheet(),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildShareSheet() {
    final screenHeight = MediaQuery.of(context).size.height;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      height: screenHeight *
          0.70, // 70% of screen height (increased for connections row)
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF6633CC), // Purple top
            Color(0xFF1A1A4D), // Dark purple bottom
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: GestureDetector(
        onTap: () {}, // Prevent tap from propagating to dismiss
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // C. Swipe Handle
              _buildSwipeHandle(),

              // Header
              _buildHeader(),

              // Connections Row (new - top priority)
              ConnectionsRow(
                videoId: widget.video.id,
                shareToken: _payload?.metadata.creatorUsername ?? '',
                onSearchTap: _openConnectionsSearch,
                onConnectionTap: _onConnectionTapped,
              ),

              const SizedBox(height: 16),

              // Top Row: Primary Share Targets (dynamically ranked)
              _buildPrimaryShareRow(),

              const SizedBox(height: 24),

              // Divider
              Divider(color: Colors.white.withValues(alpha: 0.2), height: 1),

              const SizedBox(height: 16),

              // Bottom Row: Contextual Actions
              _buildContextualActions(),

              SizedBox(height: bottomPadding + 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSwipeHandle() {
    return Container(
      width: 40,
      height: 4,
      margin: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey[600],
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
            onPressed: _handleDismiss,
          ),
        ],
      ),
    );
  }

  Widget _buildPrimaryShareRow() {
    if (_isLoading || _payload == null) {
      return _buildLoadingTargets();
    }

    // Get dynamically ranked targets
    final rankedTargets = ShareServiceOptimized().getRankedTargets();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Wrap(
        spacing: 8,
        runSpacing: 12,
        alignment: WrapAlignment.spaceEvenly,
        children: rankedTargets.map((target) {
          return _buildShareTargetButton(target);
        }).toList(),
      ),
    );
  }

  Widget _buildLoadingTargets() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(
          5,
          (index) => Column(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.grey[700],
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: 50,
                height: 10,
                decoration: BoxDecoration(
                  color: Colors.grey[700],
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShareTargetButton(ShareTarget target) {
    return SizedBox(
      width: 70,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () => _handleShareTarget(target),
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.3),
                  width: 1.5,
                ),
              ),
              child: Center(
                child: Icon(
                  _getIconForTarget(target),
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            target.displayName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildContextualActions() {
    final actions = <ShareAction>[
      ShareAction.sendMessage,
      ShareAction.favorite,
      ShareAction.notInterested,
      ShareAction.report,
      ShareAction.block,
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: actions.map((action) {
          return _buildActionRow(action);
        }).toList(),
      ),
    );
  }

  Widget _buildActionRow(ShareAction action) {
    return InkWell(
      onTap: () {
        unawaited(_handleAction(action));
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Icon(
              _getIconForAction(action),
              color: action == ShareAction.block || action == ShareAction.report
                  ? Colors.red.shade400
                  : Colors.white,
              size: 24,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                action.displayName,
                style: TextStyle(
                  color: action == ShareAction.block ||
                          action == ShareAction.report
                      ? Colors.red.shade400
                      : Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: Colors.white.withValues(alpha: 0.5),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  IconData _getIconForTarget(ShareTarget target) {
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

  IconData _getIconForAction(ShareAction action) {
    switch (action) {
      case ShareAction.report:
        return Icons.flag;
      case ShareAction.block:
        return Icons.block;
      case ShareAction.sendMessage:
        return Icons.chat_bubble;
      case ShareAction.notInterested:
        return Icons.not_interested;
      case ShareAction.favorite:
        return Icons.favorite_border;
    }
  }
}
