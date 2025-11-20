import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:io';
import '../models/home_video.dart';
// import '../services/thumbnail_service.dart'; // Removed unused import

/// Single source of truth for all video thumbnail rendering
/// Handles cache busting, fallbacks, and consistent placeholder behavior
class ThumbnailTile extends StatelessWidget {
  final HomeVideo video;
  final VoidCallback? onTap;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final bool showDurationBadge;
  final bool showDraftBadge;
  final bool showViewsBadge;

  const ThumbnailTile({
    super.key,
    required this.video,
    this.onTap,
    this.width,
    this.height,
    this.borderRadius,
    this.showDurationBadge = true,
    this.showDraftBadge = false,
    this.showViewsBadge = false,
  });

  @override
  Widget build(BuildContext context) {
    // Get the best thumbnail URL with cache busting
    final thumbnailUrl = _getBestThumbnailUrl();
    final cacheKey = _getCacheKey();

    debugPrint('🖼️ ThumbnailTile: Video ${video.id}');
    debugPrint('  - thumbnailUrl: "$thumbnailUrl"');
    debugPrint('  - cacheKey: "$cacheKey"');

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors
              .black, // Solid background to prevent gradient bleed-through
          borderRadius: borderRadius,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 0,
              spreadRadius: 1,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: borderRadius ?? BorderRadius.zero,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Main thumbnail image or placeholder
              _buildThumbnailContent(thumbnailUrl, cacheKey),

              // Badges and overlays
              if (showDurationBadge &&
                  video.duration != null &&
                  video.duration! > 0)
                _buildDurationBadge(),

              if (showDraftBadge && video.isDraft == true) _buildDraftBadge(),

              if (showViewsBadge && video.views > 0) _buildViewsBadge(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnailContent(String? thumbnailUrl, String cacheKey) {
    if (thumbnailUrl == null || thumbnailUrl.isEmpty) {
      debugPrint('🖼️ ThumbnailTile: No thumbnail URL, showing placeholder');
      return _buildGradientPlaceholder();
    }

    // Check if this is a local file path (drafts use local paths)
    if (_isLocalFilePath(thumbnailUrl)) {
      debugPrint('🖼️ ThumbnailTile: Loading local file: $thumbnailUrl');
      return _buildLocalFileImage(thumbnailUrl);
    }

    debugPrint('🖼️ ThumbnailTile: Loading image from URL: $thumbnailUrl');

    return CachedNetworkImage(
      imageUrl: thumbnailUrl,
      cacheKey: cacheKey,
      fit: BoxFit.cover,
      memCacheWidth: width?.round(),
      memCacheHeight: height?.round(),
      placeholder: (context, url) {
        debugPrint('🖼️ ThumbnailTile: Loading placeholder for $url');
        return Container(
          color: Colors.grey[900], // Simple solid color - no gradients
          child: const Center(
            child: CircularProgressIndicator(color: Colors.white54),
          ),
        );
      },
      errorWidget: (context, url, error) {
        debugPrint('🖼️ ThumbnailTile: Error loading image $url: $error');
        return Container(
          color: Colors.grey[900], // Simple solid color - no gradients
          child: const Center(
            child: Icon(
              Icons.error_outline,
              color: Colors.red,
              size: 48,
            ),
          ),
        );
      },
      imageBuilder: (context, imageProvider) {
        debugPrint(
            '🖼️ ThumbnailTile: Image loaded successfully: $thumbnailUrl');
        return Image(
          image: imageProvider,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
        );
      },
    );
  }

  bool _isLocalFilePath(String path) {
    // Check if path starts with / (absolute path) or doesn't start with http/https
    return path.startsWith('/') || (!path.startsWith('http://') && !path.startsWith('https://'));
  }

  Widget _buildLocalFileImage(String filePath) {
    try {
      final file = File(filePath);
      if (!file.existsSync()) {
        debugPrint('🖼️ ThumbnailTile: Local file does not exist: $filePath');
        return Container(
          color: Colors.grey[900],
          child: const Center(
            child: Icon(
              Icons.error_outline,
              color: Colors.red,
              size: 48,
            ),
          ),
        );
      }

      return Image.file(
        file,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (context, error, stackTrace) {
          debugPrint('🖼️ ThumbnailTile: Error loading local file $filePath: $error');
          return Container(
            color: Colors.grey[900],
            child: const Center(
              child: Icon(
                Icons.error_outline,
                color: Colors.red,
                size: 48,
              ),
            ),
          );
        },
      );
    } catch (e) {
      debugPrint('🖼️ ThumbnailTile: Exception loading local file $filePath: $e');
      return Container(
        color: Colors.grey[900],
        child: const Center(
          child: Icon(
            Icons.error_outline,
            color: Colors.red,
            size: 48,
          ),
        ),
      );
    }
  }

  Widget _buildGradientPlaceholder() {
    return Container(
      color: Colors.grey[900], // Simple solid color - no gradients
      child: const Center(
        child: Icon(
          Icons.play_circle_outline,
          color: Colors.white54,
          size: 48,
        ),
      ),
    );
  }

  Widget _buildDurationBadge() {
    return Positioned(
      bottom: 8,
      left: 8,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          _formatDuration(video.duration!),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildDraftBadge() {
    return Positioned(
      top: 8,
      right: 8,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Text(
          'Draft',
          style: TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildViewsBadge() {
    return Positioned(
      top: 8,
      left: 8,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          _formatViews(video.views),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  String? _getBestThumbnailUrl() {
    // Priority order for thumbnail URLs
    if (video.thumbnails != null && video.thumbnails!.urls.isNotEmpty) {
      // Use the new VideoThumbnails system
      final urls = video.thumbnails!.urls;
      final width = this.width ?? 200;

      // Choose the best size based on width
      if (width <= 200 && urls.containsKey(360)) {
        return urls[360];
      } else if (width <= 400 && urls.containsKey(540)) {
        return urls[540];
      } else if (urls.containsKey(720)) {
        return urls[720];
      } else {
        // Fallback to any available size
        return urls.values.first;
      }
    }

    // Fallback to legacy thumbnailURL
    if (video.thumbnailURL != null && video.thumbnailURL!.isNotEmpty) {
      return video.thumbnailURL;
    }

    return null;
  }

  String _getCacheKey() {
    final timestamp = video.thumbnails?.generatedAt?.millisecondsSinceEpoch ??
        video.createdAt?.millisecondsSinceEpoch ??
        0;
    return 'video-${video.id}-$timestamp';
  }

  String _formatDuration(double durationSeconds) {
    final minutes = (durationSeconds / 60).floor();
    final seconds = (durationSeconds % 60).floor();
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String _formatViews(int views) {
    if (views >= 1000000) {
      return '${(views / 1000000).toStringAsFixed(1)}M';
    } else if (views >= 1000) {
      return '${(views / 1000).toStringAsFixed(1)}K';
    } else {
      return views.toString();
    }
  }
}
