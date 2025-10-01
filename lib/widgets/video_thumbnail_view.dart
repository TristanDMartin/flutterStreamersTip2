import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:path_provider/path_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'tiktok_quality_thumbnail.dart';

/// A widget that displays video thumbnails with proper loading states and caching
class VideoThumbnailView extends StatefulWidget {
  final String videoUrl;
  final double width;
  final double height;
  final double borderRadius;
  final bool showPlayIcon;
  final bool showViewCount;
  final int? viewCount;
  final bool isDraft;
  final int? draftCount;
  final VoidCallback? onTap;
  final Duration thumbnailTime; // Time in video to capture thumbnail

  const VideoThumbnailView({
    super.key,
    required this.videoUrl,
    this.width = 110,
    this.height = 170,
    this.borderRadius = 16,
    this.showPlayIcon = true,
    this.showViewCount = false,
    this.viewCount,
    this.isDraft = false,
    this.draftCount,
    this.onTap,
    this.thumbnailTime = const Duration(seconds: 1),
  });

  @override
  State<VideoThumbnailView> createState() => _VideoThumbnailViewState();
}

class _VideoThumbnailViewState extends State<VideoThumbnailView> {
  String? _thumbnailPath;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _generateThumbnail();
  }

  @override
  void didUpdateWidget(VideoThumbnailView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoUrl != widget.videoUrl) {
      _thumbnailPath = null;
      _isLoading = true;
      _hasError = false;
      _generateThumbnail();
    }
  }

  Future<void> _generateThumbnail() async {
    try {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });

      // For network URLs, try to generate thumbnail
      if (widget.videoUrl.startsWith('http')) {
        final thumbnailPath = await VideoThumbnail.thumbnailFile(
          video: widget.videoUrl,
          thumbnailPath: (await getTemporaryDirectory()).path,
          imageFormat: ImageFormat.JPEG,
          maxWidth: (widget.width * 2).toInt(), // Higher resolution for crisp thumbnails
          maxHeight: (widget.height * 2).toInt(), // Higher resolution for crisp thumbnails
          timeMs: widget.thumbnailTime.inMilliseconds,
          quality: 95, // High quality for crisp images
        );

        if (mounted && thumbnailPath != null) {
          setState(() {
            _thumbnailPath = thumbnailPath;
            _isLoading = false;
          });
        }
      } else {
        // For local file paths
        final file = File(widget.videoUrl);
        if (await file.exists()) {
          final thumbnailPath = await VideoThumbnail.thumbnailFile(
            video: widget.videoUrl,
            thumbnailPath: (await getTemporaryDirectory()).path,
            imageFormat: ImageFormat.JPEG,
            maxWidth: (widget.width * 2).toInt(), // Higher resolution for crisp thumbnails
            maxHeight: (widget.height * 2).toInt(), // Higher resolution for crisp thumbnails
            timeMs: widget.thumbnailTime.inMilliseconds,
            quality: 95, // High quality for crisp images
          );

          if (mounted && thumbnailPath != null) {
            setState(() {
              _thumbnailPath = thumbnailPath;
              _isLoading = false;
            });
          }
        } else {
          setState(() {
            _hasError = true;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error generating thumbnail: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
    }
  }

  String _formatViewCount(int views) {
    if (views < 1000) return views.toString();
    final kValue = views / 1000.0;
    return '${kValue.toStringAsFixed(1)}K';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.25),
              blurRadius: 10,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          child: Stack(
            children: [
              // Thumbnail image
              _buildThumbnailContent(),
              
              // Play icon overlay
              if (widget.showPlayIcon)
                Center(
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.play_arrow,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),

              // Bottom overlay with view count or draft count
              if (widget.showViewCount && widget.viewCount != null)
                _buildViewCountOverlay(),
              
              if (widget.isDraft && widget.draftCount != null)
                _buildDraftCountOverlay(),

              // Loading indicator
              if (_isLoading)
                Container(
                  color: Colors.black.withOpacity(0.3),
                  child: const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      strokeWidth: 2,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnailContent() {
    if (_hasError || _thumbnailPath == null) {
      return Container(
        width: widget.width,
        height: widget.height,
        color: Colors.grey[800],
        child: const Icon(
          Icons.videocam_off,
          color: Colors.grey,
          size: 32,
        ),
      );
    }

    if (_thumbnailPath!.startsWith('http')) {
      // Network image
      return CachedNetworkImage(
        imageUrl: _thumbnailPath!,
        width: widget.width,
        height: widget.height,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          color: Colors.grey[800],
          child: const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              strokeWidth: 2,
            ),
          ),
        ),
        errorWidget: (context, url, error) => Container(
          color: Colors.grey[800],
          child: const Icon(
            Icons.error,
            color: Colors.red,
            size: 32,
          ),
        ),
      );
    } else {
      // Local file
      return Image.file(
        File(_thumbnailPath!),
        width: widget.width,
        height: widget.height,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          color: Colors.grey[800],
          child: const Icon(
            Icons.error,
            color: Colors.red,
            size: 32,
          ),
        ),
      );
    }
  }

  Widget _buildViewCountOverlay() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Colors.black.withOpacity(0.7),
            ],
          ),
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(widget.borderRadius),
            bottomRight: Radius.circular(widget.borderRadius),
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.play_circle_fill,
              color: Colors.white,
              size: 16,
            ),
            const SizedBox(width: 4),
            Text(
              _formatViewCount(widget.viewCount!),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDraftCountOverlay() {
    return Positioned(
      bottom: 10,
      right: 10,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          'Drafts: ${widget.draftCount}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// A specialized thumbnail view for published videos with view counts
class PublishedVideoThumbnail extends StatelessWidget {
  final String videoUrl;
  final int viewCount;
  final VoidCallback? onTap;
  final double width;
  final double height;

  const PublishedVideoThumbnail({
    super.key,
    required this.videoUrl,
    required this.viewCount,
    this.onTap,
    this.width = 110,
    this.height = 170,
  });

  @override
  Widget build(BuildContext context) {
    return VideoThumbnailView(
      videoUrl: videoUrl,
      width: width,
      height: height,
      borderRadius: 16,
      showPlayIcon: true,
      showViewCount: true,
      viewCount: viewCount,
      onTap: onTap,
    );
  }
}

/// A specialized thumbnail view for draft videos with draft count
class DraftVideoThumbnail extends StatelessWidget {
  final String videoUrl;
  final int draftCount;
  final VoidCallback? onTap;
  final double width;
  final double height;

  const DraftVideoThumbnail({
    super.key,
    required this.videoUrl,
    required this.draftCount,
    this.onTap,
    this.width = 110,
    this.height = 170,
  });

  @override
  Widget build(BuildContext context) {
    return VideoThumbnailView(
      videoUrl: videoUrl,
      width: width,
      height: height,
      borderRadius: 28, // More rounded for drafts
      showPlayIcon: true,
      isDraft: true,
      draftCount: draftCount,
      onTap: onTap,
    );
  }
}

/// A compact thumbnail view for categories and lists
class CompactVideoThumbnail extends StatelessWidget {
  final String videoUrl;
  final VoidCallback? onTap;
  final double width;
  final double height;

  const CompactVideoThumbnail({
    super.key,
    required this.videoUrl,
    this.onTap,
    this.width = 80,
    this.height = 120,
  });

  @override
  Widget build(BuildContext context) {
    return TikTokQualityThumbnail(
      videoUrl: videoUrl,
      width: width,
      height: height,
      borderRadius: BorderRadius.circular(12),
      fit: BoxFit.cover,
    );
  }
}
