import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/home_video.dart';
import '../models/share_payload.dart';
import '../services/share_service_optimized.dart';
import 'share_sheet_view.dart';

class OptimizedShareButton extends StatefulWidget {
  final HomeVideo video;
  final VoidCallback? onShareCompleted;
  final double? size;
  final Color? color;

  const OptimizedShareButton({
    super.key,
    required this.video,
    this.onShareCompleted,
    this.size,
    this.color,
  });

  @override
  State<OptimizedShareButton> createState() => _OptimizedShareButtonState();
}

class _OptimizedShareButtonState extends State<OptimizedShareButton> {
  SharePayload? _cachedPayload;

  @override
  void initState() {
    super.initState();
    // Prefetch share data for instant modal display
    _prefetchShareData();
  }

  Future<void> _prefetchShareData() async {
    try {
      final payload =
          await ShareServiceOptimized().fetchSharePayload(widget.video);
      if (mounted) {
        setState(() {
          _cachedPayload = payload;
        });
      }
    } catch (e) {
      // Silent fail - modal will fetch on demand
    }
  }

  void _handleShare() {
    // Immediate UI feedback
    HapticFeedback.lightImpact();

    // Show share sheet modal - video continues playing behind it
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      builder: (context) => ShareSheetView(
        video: widget.video,
        payload: _cachedPayload, // Use prefetched data for instant display
        onDismiss: () {
          widget.onShareCompleted?.call();
        },
        onAction: (action) {
          // Handle contextual actions
          _handleShareAction(action);
        },
      ),
    );
  }

  void _handleShareAction(ShareAction action) {
    switch (action) {
      case ShareAction.report:
        // Show report dialog
        _showReportDialog();
        break;
      case ShareAction.block:
        // Show block confirmation
        _showBlockDialog();
        break;
      case ShareAction.sendMessage:
        // Navigate to DM view
        // TODO: Implement DM navigation
        break;
      case ShareAction.notInterested:
        // Hide similar content
        break;
      case ShareAction.favorite:
        // Add to favorites
        break;
    }
  }

  void _showReportDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A4D),
        title:
            const Text('Report Video', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Why are you reporting this video?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Report submitted')),
              );
            },
            child: const Text('Submit', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showBlockDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A4D),
        title: const Text('Block User', style: TextStyle(color: Colors.white)),
        content: Text(
          'Block @${widget.video.creator.username}? You won\'t see their content anymore.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text('@${widget.video.creator.username} blocked')),
              );
            },
            child: const Text('Block', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size ?? 24.0;
    final color = widget.color ?? Colors.white.withValues(alpha: 0.85);

    return GestureDetector(
      onTap: _handleShare,
      child: Container(
        padding: const EdgeInsets.all(8),
        child: Icon(
          Icons.share,
          color: color,
          size: size,
        ),
      ),
    );
  }
}
