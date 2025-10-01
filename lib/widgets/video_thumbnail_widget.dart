import 'package:flutter/material.dart';
import 'dart:typed_data';
import '../services/video_thumbnail_service.dart';

class VideoThumbnailWidget extends StatefulWidget {
  final String videoUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;
  final BorderRadius? borderRadius;

  const VideoThumbnailWidget({
    super.key,
    required this.videoUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
    this.borderRadius,
  });

  @override
  State<VideoThumbnailWidget> createState() => _VideoThumbnailWidgetState();
}

class _VideoThumbnailWidgetState extends State<VideoThumbnailWidget> {
  Uint8List? _thumbnailData;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _generateThumbnail();
  }

  @override
  void didUpdateWidget(VideoThumbnailWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoUrl != widget.videoUrl) {
      _generateThumbnail();
    }
  }

  Future<void> _generateThumbnail() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    
    try {
      // Use TikTok-quality thumbnail generation with smaller dimensions to prevent buffer overflow
      final thumbnailData = await VideoThumbnailService.generateCustomThumbnail(
        widget.videoUrl,
        maxWidth: widget.width?.toInt() ?? 160, // Smaller dimensions to prevent overflow
        maxHeight: widget.height?.toInt() ?? 240, // Smaller dimensions to prevent overflow
        quality: 90, // High quality but not maximum to prevent memory issues
      );
      
      if (mounted) {
        setState(() {
          _thumbnailData = thumbnailData;
          _isLoading = false;
          _hasError = thumbnailData == null;
        });
      }
    } catch (e) {
      debugPrint('Error generating thumbnail: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        borderRadius: widget.borderRadius,
        color: Colors.grey[900],
      ),
      child: ClipRRect(
        borderRadius: widget.borderRadius ?? BorderRadius.zero,
        child: _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return widget.placeholder ?? _buildDefaultPlaceholder();
    }

    if (_hasError || _thumbnailData == null) {
      return widget.errorWidget ?? _buildDefaultErrorWidget();
    }

    return Image.memory(
      _thumbnailData!,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
    );
  }

  Widget _buildDefaultPlaceholder() {
    return Container(
      color: Colors.grey[900],
      child: const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF9248D2)),
          strokeWidth: 2,
        ),
      ),
    );
  }

  Widget _buildDefaultErrorWidget() {
    return Container(
      color: Colors.grey[900],
      child: const Center(
        child: Icon(
          Icons.videocam_off,
          color: Colors.grey,
          size: 32,
        ),
      ),
    );
  }
}

/// A specialized thumbnail widget for video cards with play button overlay
class VideoCardThumbnail extends StatelessWidget {
  final String videoUrl;
  final double? width;
  final double? height;
  final VoidCallback? onTap;
  final Widget? playButton;

  const VideoCardThumbnail({
    super.key,
    required this.videoUrl,
    this.width,
    this.height,
    this.onTap,
    this.playButton,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          VideoThumbnailWidget(
            videoUrl: videoUrl,
            width: width,
            height: height,
            borderRadius: BorderRadius.circular(12),
          ),
          if (playButton != null)
            Positioned.fill(
              child: Center(
                child: playButton!,
              ),
            ),
        ],
      ),
    );
  }
}

/// A loading thumbnail widget with shimmer effect
class LoadingThumbnailWidget extends StatefulWidget {
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;

  const LoadingThumbnailWidget({
    super.key,
    this.width,
    this.height,
    this.borderRadius,
  });

  @override
  State<LoadingThumbnailWidget> createState() => _LoadingThumbnailWidgetState();
}

class _LoadingThumbnailWidgetState extends State<LoadingThumbnailWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _animation = Tween<double>(
      begin: 0.3,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    _animationController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        borderRadius: widget.borderRadius,
        color: Colors.grey[900],
      ),
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          return Opacity(
            opacity: _animation.value,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: widget.borderRadius,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.grey[800]!,
                    Colors.grey[700]!,
                    Colors.grey[800]!,
                  ],
                ),
              ),
              child: const Center(
                child: Icon(
                  Icons.videocam,
                  color: Colors.grey,
                  size: 24,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
