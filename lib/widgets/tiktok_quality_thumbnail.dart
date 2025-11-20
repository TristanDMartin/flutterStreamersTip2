import 'package:flutter/material.dart';
import 'dart:typed_data';
import '../services/video_thumbnail_service.dart';

/// High-quality thumbnail widget with crisp, high-resolution thumbnails
class TikTokQualityThumbnail extends StatefulWidget {
  final String videoUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;
  final BorderRadius? borderRadius;
  final Duration thumbnailTime;

  const TikTokQualityThumbnail({
    super.key,
    required this.videoUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
    this.borderRadius,
    this.thumbnailTime = const Duration(seconds: 1),
  });

  @override
  State<TikTokQualityThumbnail> createState() => _TikTokQualityThumbnailState();
}

class _TikTokQualityThumbnailState extends State<TikTokQualityThumbnail> {
  Uint8List? _thumbnailData;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _generateThumbnail();
  }

  @override
  void didUpdateWidget(TikTokQualityThumbnail oldWidget) {
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
      // Use high-quality thumbnail generation
      final thumbnailData =
          await VideoThumbnailService.generateHighQualityThumbnail(
        widget.videoUrl,
        maxWidth: widget.width?.toInt() ?? 720,
        maxHeight: widget.height?.toInt() ?? 1280,
        timeMs: widget.thumbnailTime.inMilliseconds,
      );

      if (mounted) {
        setState(() {
          _thumbnailData = thumbnailData;
          _isLoading = false;
          _hasError = thumbnailData == null;
        });
      }
    } catch (e) {
      debugPrint('Error generating high-quality thumbnail: $e');
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
      ),
      child: ClipRRect(
        borderRadius: widget.borderRadius ?? BorderRadius.zero,
        child: _buildThumbnailContent(),
      ),
    );
  }

  Widget _buildThumbnailContent() {
    if (_isLoading) {
      return widget.placeholder ?? _buildDefaultPlaceholder();
    }

    if (_hasError || _thumbnailData == null) {
      return widget.errorWidget ?? _buildDefaultErrorWidget();
    }

    return Image.memory(
      _thumbnailData!,
      fit: widget.fit,
      width: widget.width,
      height: widget.height,
      filterQuality: FilterQuality.high, // High quality filtering
    );
  }

  Widget _buildDefaultPlaceholder() {
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: Colors.grey[900], // Simple solid color - no gradients
      ),
      child: const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          strokeWidth: 2,
        ),
      ),
    );
  }

  Widget _buildDefaultErrorWidget() {
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: Colors.grey[900], // Simple solid color - no gradients
      ),
      child: const Center(
        child: Icon(
          Icons.video_library_outlined,
          color: Colors.white54,
          size: 32,
        ),
      ),
    );
  }
}
