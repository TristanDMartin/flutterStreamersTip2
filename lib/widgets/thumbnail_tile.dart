import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:io';
import '../models/home_video.dart';
import '../services/thumbnail_service.dart';
import '../utils/swallow_non_fatal.dart';

const bool _thumbnailTileDiagnosticsEnabled = false;

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

  static final ThumbnailService _thumbnailService = ThumbnailService();

  @override
  Widget build(BuildContext context) {
    // Get the best thumbnail URL with cache busting
    final thumbnailUrl = _getBestThumbnailUrl(context);
    final cacheKey = _getCacheKey();

    if (_thumbnailTileDiagnosticsEnabled) {
      debugPrint('🖼️ ThumbnailTile: Video ${video.id}');
      debugPrint('  - thumbnailUrl: "$thumbnailUrl"');
      debugPrint('  - cacheKey: "$cacheKey"');
    }

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
              _buildThumbnailContent(context, thumbnailUrl, cacheKey),

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

  Widget _buildThumbnailContent(
    BuildContext context,
    String? thumbnailUrl,
    String cacheKey,
  ) {
    if (thumbnailUrl == null || thumbnailUrl.isEmpty) {
      if (_thumbnailTileDiagnosticsEnabled) {
        debugPrint('🖼️ ThumbnailTile: No thumbnail URL, showing placeholder');
      }
      return _buildGradientPlaceholder();
    }

    // Check if this is a local file path (drafts use local paths)
    if (_isLocalFilePath(thumbnailUrl)) {
      if (_thumbnailTileDiagnosticsEnabled) {
        debugPrint('🖼️ ThumbnailTile: Loading local file: $thumbnailUrl');
      }
      return _buildLocalFileImage(thumbnailUrl);
    }

    if (_thumbnailTileDiagnosticsEnabled) {
      debugPrint('🖼️ ThumbnailTile: Loading image from URL: $thumbnailUrl');
    }

    return CachedNetworkImage(
      imageUrl: thumbnailUrl,
      cacheKey: cacheKey,
      fit: BoxFit.cover,
      memCacheWidth:
          ((width ?? 200) * _thumbnailService.getDevicePixelRatio(context))
              .round(),
      memCacheHeight:
          ((height ?? 300) * _thumbnailService.getDevicePixelRatio(context))
              .round(),
      filterQuality: FilterQuality.high,
      placeholder: (context, url) {
        if (_thumbnailTileDiagnosticsEnabled) {
          debugPrint('🖼️ ThumbnailTile: Loading placeholder for $url');
        }
        return Container(
          color: Colors.grey[900], // Simple solid color - no gradients
          child: const Center(
            child: CircularProgressIndicator(color: Colors.white54),
          ),
        );
      },
      errorWidget: (context, url, error) {
        if (_thumbnailTileDiagnosticsEnabled) {
          debugPrint('🖼️ ThumbnailTile: Error loading image $url: $error');
        }
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
        if (_thumbnailTileDiagnosticsEnabled) {
          debugPrint(
              '🖼️ ThumbnailTile: Image loaded successfully: $thumbnailUrl');
        }
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
    final String trimmed = path.trim();
    if (trimmed.isEmpty) {
      return false;
    }
    final String lower = trimmed.toLowerCase();
    if (lower.startsWith('http://') || lower.startsWith('https://')) {
      return false;
    }
    return lower.startsWith('file://') ||
        trimmed.startsWith('/') ||
        trimmed.contains(Platform.pathSeparator);
  }

  String _filesystemPathFromThumbnailUrl(String pathOrUrl) {
    final String trimmed = pathOrUrl.trim();
    if (trimmed.startsWith('file://')) {
      try {
        return Uri.parse(trimmed).toFilePath();
      } catch (_) {
        return trimmed.replaceFirst('file://', '');
      }
    }
    return trimmed;
  }

  Widget _buildLocalFileImage(String filePath) {
    try {
      final file = File(_filesystemPathFromThumbnailUrl(filePath));
      if (!file.existsSync()) {
        if (_thumbnailTileDiagnosticsEnabled) {
          debugPrint('🖼️ ThumbnailTile: Local file does not exist: $filePath');
        }
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
          if (_thumbnailTileDiagnosticsEnabled) {
            debugPrint(
                '🖼️ ThumbnailTile: Error loading local file $filePath: $error');
          }
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
      if (_thumbnailTileDiagnosticsEnabled) {
        debugPrint(
            '🖼️ ThumbnailTile: Exception loading local file $filePath: $e');
      }
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

  String? _getBestThumbnailUrl(BuildContext context) {
    final resolvedWidth = width ?? 200;
    final devicePixelRatio = _thumbnailService.getDevicePixelRatio(context);

    final optimized = _thumbnailService.getDisplayReadyThumbnailUrl(
      thumbnails: video.thumbnails,
      containerWidth: resolvedWidth,
      devicePixelRatio: devicePixelRatio,
      fallbackUrl: video.thumbnailURL,
    );
    if (optimized != null && optimized.isNotEmpty) {
      return optimized;
    }

    final videoUrl = video.videoURL;
    if (videoUrl.contains('stream.mux.com')) {
      try {
        final uri = Uri.parse(videoUrl);
        final segments = uri.pathSegments;
        if (segments.isNotEmpty) {
          final playbackId = segments.first.replaceAll('.m3u8', '');
          final requestedWidth =
              (resolvedWidth * devicePixelRatio).round().clamp(360, 1440);
          return 'https://image.mux.com/$playbackId/thumbnail.jpg?width=$requestedWidth&time=0';
        }
      } catch (e, st) {
        swallowNonFatal('ThumbnailTile.muxThumbnailUrl', e, st);
      }
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
