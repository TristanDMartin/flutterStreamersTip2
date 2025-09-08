import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/home_video.dart';
import '../services/share_service_optimized.dart';

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
  bool _isSharing = false;

  Future<void> _handleShare() async {
    if (_isSharing) return;

    // Immediate UI feedback
    HapticFeedback.lightImpact();
    setState(() {
      _isSharing = true;
    });

    try {
      await ShareServiceOptimized().shareVideo(widget.video);
      widget.onShareCompleted?.call();
    } catch (e) {
      print('Error sharing video: $e');
    } finally {
      setState(() {
        _isSharing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size ?? 24.0;
    final color = widget.color ?? Colors.white.withOpacity(0.85);

    return GestureDetector(
      onTap: _handleShare,
      child: Container(
        padding: const EdgeInsets.all(8),
        child: Stack(
          children: [
            Icon(
              Icons.share,
              color: color,
              size: size,
            ),
            if (_isSharing)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(size / 2),
                  ),
                  child: Center(
                    child: SizedBox(
                      width: size * 0.6,
                      height: size * 0.6,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
