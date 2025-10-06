import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import '../models/video_thumbnails.dart';

/// Service for managing video thumbnails with multiple sizes and DPR support
class ThumbnailService {
  static final ThumbnailService _instance = ThumbnailService._internal();
  factory ThumbnailService() => _instance;
  ThumbnailService._internal();

  // Available thumbnail sizes (width in pixels)
  static const List<int> _thumbnailSizes = [360, 540, 720];

  // Cache for thumbnail URLs to avoid repeated computations
  final Map<String, String> _thumbnailCache = {};

  // Cache for device pixel ratio to avoid repeated MediaQuery calls
  double? _cachedDevicePixelRatio;

  /// Get the optimal thumbnail URL for a given container width and device pixel ratio
  String? getOptimalThumbnailUrl({
    required VideoThumbnails? thumbnails,
    required double containerWidth,
    required double devicePixelRatio,
  }) {
    if (thumbnails == null || thumbnails.urls.isEmpty) {
      debugPrint(
          '🖼️ ThumbnailService: No thumbnails available (null: ${thumbnails == null}, empty: ${thumbnails?.urls.isEmpty ?? true})');
      return null;
    }

    // Calculate the effective pixel need
    final effectivePixels = (containerWidth * devicePixelRatio).round();

    // Find the smallest thumbnail that meets or exceeds the effective pixel need
    String? bestUrl;
    int bestSize = 0;

    for (final size in _thumbnailSizes) {
      final url = thumbnails.getUrlForSize(size);
      if (url != null && size >= effectivePixels) {
        bestUrl = url;
        bestSize = size;
        break;
      }
    }

    // If no thumbnail is large enough, use the largest available
    if (bestUrl == null) {
      for (final size in _thumbnailSizes.reversed) {
        final url = thumbnails.getUrlForSize(size);
        if (url != null) {
          bestUrl = url;
          bestSize = size;
          break;
        }
      }
    }

    debugPrint(
        '🖼️ ThumbnailService: Container ${containerWidth}px, DPR $devicePixelRatio, '
        'Effective ${effectivePixels}px, Selected ${bestSize}px: ${bestUrl != null ? 'Found' : 'None'}');

    return bestUrl;
  }

  /// Get optimal thumbnail URL with fallback chain
  String? getOptimalThumbnailUrlWithFallback({
    required VideoThumbnails? thumbnails,
    required double containerWidth,
    required double devicePixelRatio,
    String? fallbackUrl,
  }) {
    debugPrint(
        '🖼️ ThumbnailService: getOptimalThumbnailUrlWithFallback - thumbnails: ${thumbnails != null ? "YES (${thumbnails.urls.length} sizes)" : "NO"}, fallbackUrl: "$fallbackUrl"');

    // Try optimal thumbnail first
    final optimalUrl = getOptimalThumbnailUrl(
      thumbnails: thumbnails,
      containerWidth: containerWidth,
      devicePixelRatio: devicePixelRatio,
    );

    if (optimalUrl != null) {
      debugPrint('🖼️ ThumbnailService: Using optimal URL: $optimalUrl');
      return optimalUrl;
    }

    // Fall back to legacy thumbnailURL if available
    if (fallbackUrl != null && fallbackUrl.isNotEmpty) {
      debugPrint('🖼️ ThumbnailService: Using fallback URL: $fallbackUrl');
      return fallbackUrl;
    }

    debugPrint(
        '🖼️ ThumbnailService: No thumbnail URL available - returning null');
    return null;
  }

  /// Build a responsive thumbnail widget with proper sizing and fallbacks
  Widget buildResponsiveThumbnail({
    required VideoThumbnails? thumbnails,
    required double containerWidth,
    required double containerHeight,
    required double devicePixelRatio,
    String? fallbackUrl,
    Widget? placeholder,
    Widget? errorWidget,
    BoxFit fit = BoxFit.cover,
    BorderRadius? borderRadius,
    VoidCallback? onTap,
  }) {
    final optimalUrl = getOptimalThumbnailUrlWithFallback(
      thumbnails: thumbnails,
      containerWidth: containerWidth,
      devicePixelRatio: devicePixelRatio,
      fallbackUrl: fallbackUrl,
    );

    debugPrint(
        '🖼️ ThumbnailService: buildResponsiveThumbnail - optimalUrl: "$optimalUrl"');

    if (optimalUrl == null) {
      debugPrint(
          '🖼️ ThumbnailService: No optimal URL, showing no-thumbnail widget');
      return _buildNoThumbnailWidget(
        containerWidth: containerWidth,
        containerHeight: containerHeight,
        borderRadius: borderRadius,
        placeholder: placeholder,
        onTap: onTap,
      );
    }

    debugPrint(
        '🖼️ ThumbnailService: Creating CachedNetworkImage for URL: $optimalUrl');

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: containerWidth,
        height: containerHeight,
        decoration: borderRadius != null
            ? BoxDecoration(borderRadius: borderRadius)
            : null,
        child: ClipRRect(
          borderRadius: borderRadius ?? BorderRadius.zero,
          child: CachedNetworkImage(
            imageUrl: optimalUrl,
            fit: fit,
            // Optimize memory usage by setting cache dimensions
            memCacheWidth: (containerWidth * devicePixelRatio).round(),
            memCacheHeight: (containerHeight * devicePixelRatio).round(),
            placeholder: (context, url) {
              debugPrint('🖼️ ThumbnailService: Loading placeholder for $url');
              return placeholder ?? _buildShimmerPlaceholder();
            },
            errorWidget: (context, url, error) {
              debugPrint('🖼️ ThumbnailService: Error loading $url: $error');
              debugPrint(
                  '🖼️ ThumbnailService: Error type: ${error.runtimeType}');
              return errorWidget ?? _buildErrorWidget();
            },
            imageBuilder: (context, imageProvider) {
              debugPrint('🖼️ ThumbnailService: Image loaded successfully!');
              return Image(
                image: imageProvider,
                fit: fit,
              );
            },
            // Enable fade-in animation
            fadeInDuration: const Duration(milliseconds: 200),
            // Use high-quality scaling
            filterQuality: FilterQuality.high,
          ),
        ),
      ),
    );
  }

  /// Build a shimmer placeholder for loading states
  Widget _buildShimmerPlaceholder() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.grey[300]!,
            Colors.grey[100]!,
            Colors.grey[300]!,
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
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

  /// Build error widget for failed thumbnail loads
  Widget _buildErrorWidget() {
    return Container(
      color: Colors.grey[800],
      child: const Center(
        child: Icon(
          Icons.broken_image_outlined,
          color: Colors.white54,
          size: 32,
        ),
      ),
    );
  }

  /// Build widget when no thumbnail is available
  Widget _buildNoThumbnailWidget({
    required double containerWidth,
    required double containerHeight,
    BorderRadius? borderRadius,
    Widget? placeholder,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: containerWidth,
        height: containerHeight,
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: borderRadius,
        ),
        child: Center(
          child: placeholder ??
              const Icon(
                Icons.video_library_outlined,
                color: Colors.white54,
                size: 32,
              ),
        ),
      ),
    );
  }

  /// Generate a local thumbnail from video URL (for drafts)
  Future<String?> generateLocalThumbnail({
    required String videoUrl,
    required double timestamp, // in seconds
  }) async {
    try {
      final controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
      await controller.initialize();

      // TODO: Implement actual frame extraction
      // This would require platform-specific implementation
      debugPrint(
          '🖼️ ThumbnailService: Generated local thumbnail for $videoUrl at ${timestamp}s');
      return 'local_thumbnail_${videoUrl.hashCode}';
    } catch (e) {
      debugPrint('🖼️ ThumbnailService: Error generating local thumbnail: $e');
    }
    return null;
  }

  /// Get device pixel ratio (cached for performance)
  double getDevicePixelRatio(BuildContext context) {
    try {
      _cachedDevicePixelRatio ??= MediaQuery.of(context).devicePixelRatio;
      return _cachedDevicePixelRatio!;
    } catch (e) {
      // Fallback if MediaQuery is not available yet
      return _cachedDevicePixelRatio ?? 1.0;
    }
  }

  /// Clear cached device pixel ratio (call when device orientation changes)
  void clearDevicePixelRatioCache() {
    _cachedDevicePixelRatio = null;
  }

  /// Get thumbnail size recommendations for different screen densities
  Map<String, int> getThumbnailSizeRecommendations(double devicePixelRatio) {
    return {
      'low': 360,
      'medium': 540,
      'high': 720,
      'ultra': (720 * devicePixelRatio).round(),
    };
  }

  /// Validate thumbnail URL format
  bool isValidThumbnailUrl(String url) {
    if (url.isEmpty) return false;

    // Check for common image formats
    final imageExtensions = ['.jpg', '.jpeg', '.png', '.webp', '.avif'];
    final lowerUrl = url.toLowerCase();

    return imageExtensions.any((ext) => lowerUrl.contains(ext)) ||
        lowerUrl.startsWith('http') ||
        lowerUrl.startsWith('https');
  }

  /// Build cache key for thumbnail URL
  String buildCacheKey(String url, int width, int height) {
    return '${url}_${width}x$height';
  }

  /// Clear thumbnail cache
  void clearCache() {
    _thumbnailCache.clear();
    clearDevicePixelRatioCache();
    debugPrint('🖼️ ThumbnailService: Cache cleared');
  }
}
