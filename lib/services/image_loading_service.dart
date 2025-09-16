import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Image Loading Service
/// 
/// Handles robust image loading with fallbacks and error handling
/// to prevent image decoding errors and improve user experience.
class ImageLoadingService {
  
  /// Load a network image with robust error handling
  static Widget loadNetworkImage({
    required String imageUrl,
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
    Widget? placeholder,
    Widget? errorWidget,
    BorderRadius? borderRadius,
    bool enableMemoryCache = true,
    bool enableDiskCache = true,
  }) {
    // Validate URL
    if (imageUrl.isEmpty) {
      return _buildErrorWidget(width, height, fit, borderRadius);
    }
    
    final uri = Uri.tryParse(imageUrl);
    if (uri == null || !uri.hasAbsolutePath) {
      return _buildErrorWidget(width, height, fit, borderRadius);
    }

    return CachedNetworkImage(
      imageUrl: imageUrl,
      width: width,
      height: height,
      fit: fit,
      memCacheWidth: width?.toInt(),
      memCacheHeight: height?.toInt(),
      maxWidthDiskCache: width?.toInt() ?? 800,
      maxHeightDiskCache: height?.toInt() ?? 800,
      placeholder: (context, url) => placeholder ?? _buildPlaceholderWidget(width, height, fit, borderRadius),
      errorWidget: (context, url, error) => errorWidget ?? _buildErrorWidget(width, height, fit, borderRadius),
      fadeInDuration: const Duration(milliseconds: 300),
      fadeOutDuration: const Duration(milliseconds: 100),
      imageBuilder: (context, imageProvider) {
        return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            image: DecorationImage(
              image: imageProvider,
              fit: fit,
            ),
          ),
        );
      },
    );
  }

  /// Load a network image with circular avatar styling
  static Widget loadNetworkAvatar({
    required String imageUrl,
    double radius = 20,
    Widget? placeholder,
    Widget? errorWidget,
  }) {
    if (imageUrl.isEmpty) {
      return _buildCircularErrorWidget(radius);
    }
    
    final uri = Uri.tryParse(imageUrl);
    if (uri == null || !uri.hasAbsolutePath) {
      return _buildCircularErrorWidget(radius);
    }

    return CachedNetworkImage(
      imageUrl: imageUrl,
      imageBuilder: (context, imageProvider) => CircleAvatar(
        radius: radius,
        backgroundImage: imageProvider,
      ),
      placeholder: (context, url) => placeholder ?? _buildCircularPlaceholderWidget(radius),
      errorWidget: (context, url, error) => errorWidget ?? _buildCircularErrorWidget(radius),
      memCacheWidth: (radius * 2).toInt(),
      memCacheHeight: (radius * 2).toInt(),
    );
  }

  /// Load a network image with rounded rectangle styling
  static Widget loadNetworkImageRounded({
    required String imageUrl,
    double? width,
    double? height,
    double borderRadius = 8.0,
    BoxFit fit = BoxFit.cover,
    Widget? placeholder,
    Widget? errorWidget,
  }) {
    return loadNetworkImage(
      imageUrl: imageUrl,
      width: width,
      height: height,
      fit: fit,
      borderRadius: BorderRadius.circular(borderRadius),
      placeholder: placeholder,
      errorWidget: errorWidget,
    );
  }

  /// Build placeholder widget
  static Widget _buildPlaceholderWidget(double? width, double? height, BoxFit fit, BorderRadius? borderRadius) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.1),
        borderRadius: borderRadius,
      ),
      child: const Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.grey),
        ),
      ),
    );
  }

  /// Build error widget
  static Widget _buildErrorWidget(double? width, double? height, BoxFit fit, BorderRadius? borderRadius) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.1),
        borderRadius: borderRadius,
        border: Border.all(
          color: Colors.grey.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.broken_image,
          color: Colors.grey,
          size: 32,
        ),
      ),
    );
  }

  /// Build circular placeholder widget
  static Widget _buildCircularPlaceholderWidget(double radius) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.grey.withValues(alpha: 0.1),
      child: const CircularProgressIndicator(
        strokeWidth: 2,
        valueColor: AlwaysStoppedAnimation<Color>(Colors.grey),
      ),
    );
  }

  /// Build circular error widget
  static Widget _buildCircularErrorWidget(double radius) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.grey.withValues(alpha: 0.1),
      child: const Icon(
        Icons.person,
        color: Colors.grey,
        size: 20,
      ),
    );
  }

  /// Preload images for better performance
  static Future<void> preloadImages(List<String> imageUrls, BuildContext context) async {
    for (final url in imageUrls) {
      if (url.isNotEmpty) {
        final uri = Uri.tryParse(url);
        if (uri != null && uri.hasAbsolutePath) {
          try {
            await precacheImage(
              CachedNetworkImageProvider(url),
              context,
            );
          } catch (e) {
            debugPrint('Failed to preload image: $url - $e');
          }
        }
      }
    }
  }

  /// Clear image cache
  static Future<void> clearCache() async {
    await CachedNetworkImage.evictFromCache('');
  }

  /// Get cache size
  static Future<int> getCacheSize() async {
    // This would require additional implementation
    // For now, return 0
    return 0;
  }
}

/// Image Loading Widget
/// 
/// A reusable widget that handles image loading with built-in error handling
class ImageLoadingWidget extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Widget? placeholder;
  final Widget? errorWidget;
  final bool isAvatar;
  final double avatarRadius;

  const ImageLoadingWidget({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.placeholder,
    this.errorWidget,
    this.isAvatar = false,
    this.avatarRadius = 20,
  });

  @override
  Widget build(BuildContext context) {
    if (isAvatar) {
      return ImageLoadingService.loadNetworkAvatar(
        imageUrl: imageUrl,
        radius: avatarRadius,
        placeholder: placeholder,
        errorWidget: errorWidget,
      );
    }

    return ImageLoadingService.loadNetworkImage(
      imageUrl: imageUrl,
      width: width,
      height: height,
      fit: fit,
      borderRadius: borderRadius,
      placeholder: placeholder,
      errorWidget: errorWidget,
    );
  }
}
