import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/video_thumbnails.dart';

/// Service for managing video thumbnails with multiple sizes and DPR support
class ThumbnailService {
  static final ThumbnailService _instance = ThumbnailService._internal();
  factory ThumbnailService() => _instance;
  ThumbnailService._internal();

  // Available thumbnail sizes (width in pixels)
  static const List<int> _thumbnailSizes = [360, 540, 720, 1080, 1440];
  static const bool _verboseLogging = false;

  // Cache for device pixel ratio to avoid repeated MediaQuery calls
  double? _cachedDevicePixelRatio;

  void _log(String message) {
    if (kDebugMode && _verboseLogging) {
      debugPrint(message);
    }
  }

  /// Get the optimal thumbnail URL for a given container width and device pixel ratio
  String? getOptimalThumbnailUrl({
    required VideoThumbnails? thumbnails,
    required double containerWidth,
    required double devicePixelRatio,
  }) {
    if (thumbnails == null || thumbnails.urls.isEmpty) {
      _log(
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

    _log(
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
    _log(
        '🖼️ ThumbnailService: getOptimalThumbnailUrlWithFallback - thumbnails: ${thumbnails != null ? "YES (${thumbnails.urls.length} sizes)" : "NO"}, fallbackUrl: "$fallbackUrl"');

    // Try optimal thumbnail first
    final optimalUrl = getOptimalThumbnailUrl(
      thumbnails: thumbnails,
      containerWidth: containerWidth,
      devicePixelRatio: devicePixelRatio,
    );

    if (optimalUrl != null) {
      _log('🖼️ ThumbnailService: Using optimal URL: $optimalUrl');
      return optimalUrl;
    }

    // Fall back to legacy thumbnailURL if available
    if (fallbackUrl != null && fallbackUrl.isNotEmpty) {
      _log('🖼️ ThumbnailService: Using fallback URL: $fallbackUrl');
      return fallbackUrl;
    }

    _log('🖼️ ThumbnailService: No thumbnail URL available - returning null');
    return null;
  }

  /// Get the best display-ready thumbnail URL, upgrading supported providers
  /// like Mux when the fallback URL would otherwise be too soft.
  String? getDisplayReadyThumbnailUrl({
    required VideoThumbnails? thumbnails,
    required double containerWidth,
    required double devicePixelRatio,
    String? fallbackUrl,
  }) {
    final resolvedUrl = getOptimalThumbnailUrlWithFallback(
      thumbnails: thumbnails,
      containerWidth: containerWidth,
      devicePixelRatio: devicePixelRatio,
      fallbackUrl: fallbackUrl,
    );

    if (resolvedUrl == null || resolvedUrl.isEmpty) {
      return null;
    }

    final requestedWidth =
        (containerWidth * devicePixelRatio).round().clamp(360, 1440);
    return _upgradeMuxThumbnailUrl(
      resolvedUrl,
      requestedWidth: requestedWidth,
    );
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
    String? semanticsLabel,
  }) {
    final optimalUrl = getOptimalThumbnailUrlWithFallback(
      thumbnails: thumbnails,
      containerWidth: containerWidth,
      devicePixelRatio: devicePixelRatio,
      fallbackUrl: fallbackUrl,
    );

    _log(
        '🖼️ ThumbnailService: buildResponsiveThumbnail - optimalUrl: "$optimalUrl"');

    if (optimalUrl == null) {
      _log('🖼️ ThumbnailService: No optimal URL, showing no-thumbnail widget');
      return _buildNoThumbnailWidget(
        containerWidth: containerWidth,
        containerHeight: containerHeight,
        borderRadius: borderRadius,
        placeholder: placeholder,
        onTap: onTap,
      );
    }

    _log(
        '🖼️ ThumbnailService: Creating CachedNetworkImage for URL: $optimalUrl');

    final resolvedBorderRadius = borderRadius ?? BorderRadius.circular(12);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: containerWidth,
        height: containerHeight,
        decoration: BoxDecoration(
          borderRadius: resolvedBorderRadius,
          color: Colors.black,
        ),
        child: ClipRRect(
          borderRadius: resolvedBorderRadius,
          child: Semantics(
            label: semanticsLabel,
            child: CachedNetworkImage(
              imageUrl: optimalUrl,
              fit: fit,
              memCacheWidth: (containerWidth * devicePixelRatio).round(),
              memCacheHeight: (containerHeight * devicePixelRatio).round(),
              placeholder: (context, url) {
                _log('🖼️ ThumbnailService: Loading placeholder for $url');
                return placeholder ?? _buildAssetPlaceholder();
              },
              errorWidget: (context, url, error) {
                _log('🖼️ ThumbnailService: Error loading $url: $error');
                return errorWidget ?? _buildAssetPlaceholder();
              },
              imageBuilder: (context, imageProvider) {
                _log('🖼️ ThumbnailService: Image loaded successfully!');
                return Image(
                  image: imageProvider,
                  fit: fit,
                );
              },
              fadeInDuration: const Duration(milliseconds: 150),
              filterQuality: FilterQuality.high,
            ),
          ),
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
          borderRadius: borderRadius ?? BorderRadius.circular(12),
        ),
        child: Center(
          child: placeholder ?? _buildAssetPlaceholder(),
        ),
      ),
    );
  }

  Widget _buildAssetPlaceholder() {
    return Image.asset(
      'assets/background.png',
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        color: Colors.grey[900],
        child: const Center(
          child: Icon(
            Icons.image_outlined,
            color: Colors.white54,
            size: 28,
          ),
        ),
      ),
    );
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

  /// Clear device pixel ratio cache
  void clearCache() {
    clearDevicePixelRatioCache();
    debugPrint('🖼️ ThumbnailService: Cache cleared');
  }

  String _upgradeMuxThumbnailUrl(
    String url, {
    required int requestedWidth,
  }) {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.host != 'image.mux.com') {
      return url;
    }

    final currentWidth = int.tryParse(uri.queryParameters['width'] ?? '');
    final resolvedWidth = currentWidth == null
        ? requestedWidth
        : (currentWidth > requestedWidth ? currentWidth : requestedWidth);

    final updatedParams = Map<String, String>.from(uri.queryParameters);
    updatedParams['width'] = resolvedWidth.toString();
    updatedParams.putIfAbsent('time', () => '0');

    return uri.replace(queryParameters: updatedParams).toString();
  }
}
