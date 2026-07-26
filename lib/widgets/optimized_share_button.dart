import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/home_video.dart';
import '../services/enhanced_share_service.dart';
import 'enhanced_share_sheet.dart';

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
  @override
  void initState() {
    super.initState();
    unawaited(EnhancedShareService().fetchSharePayload(widget.video));
  }

  void _handleShare() {
    // Immediate UI feedback
    HapticFeedback.lightImpact();

    // Show share sheet modal - video continues playing behind it
    showModalBottomSheet(
      context: context,
      routeSettings: const RouteSettings(name: '/share_sheet'),
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      builder: (context) => EnhancedShareSheet(
        video: widget.video,
        onClose: () {
          Navigator.of(context).maybePop();
          widget.onShareCompleted?.call();
        },
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
