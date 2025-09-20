import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Image CDN Service
/// 
/// This service provides optimized image delivery using CDN with:
/// - Automatic image resizing
/// - Format optimization (WebP, AVIF)
/// - Caching and compression
/// - Fallback handling
class ImageCDNService {
  static final ImageCDNService _instance = ImageCDNService._internal();
  factory ImageCDNService() => _instance;
  ImageCDNService._internal();

  // CDN configuration
  static const String _cdnBaseUrl = 'https://cdn.streamerstip.com';
  static const String _fallbackBaseUrl = 'https://via.placeholder.com'; // More reliable than picsum.photos
  
  // Image quality settings
  static const int _defaultQuality = 80;
  static const int _thumbnailQuality = 60;
  static const int _avatarQuality = 70;

  /// Get optimized image URL with CDN
  String getOptimizedImageUrl({
    required String originalUrl,
    int? width,
    int? height,
    int quality = _defaultQuality,
    String format = 'webp',
    bool isThumbnail = false,
    bool isAvatar = false,
  }) {
    // If it's already a CDN URL, return as is
    if (originalUrl.contains(_cdnBaseUrl)) {
      return originalUrl;
    }

    // If it's a placeholder or fallback URL, return as is
    if (originalUrl.contains(_fallbackBaseUrl) || originalUrl.isEmpty) {
      return originalUrl;
    }

    // Build CDN URL with parameters
    final cdnUrl = StringBuffer(_cdnBaseUrl);
    cdnUrl.write('/image');
    
    // Add source URL
    cdnUrl.write('?url=${Uri.encodeComponent(originalUrl)}');
    
    // Add dimensions
    if (width != null) cdnUrl.write('&w=$width');
    if (height != null) cdnUrl.write('&h=$height');
    
    // Add quality
    final finalQuality = isThumbnail ? _thumbnailQuality : 
                        isAvatar ? _avatarQuality : quality;
    cdnUrl.write('&q=$finalQuality');
    
    // Add format
    cdnUrl.write('&f=$format');
    
    // Add optimization flags
    cdnUrl.write('&auto=format,compress');
    cdnUrl.write('&fit=crop');
    cdnUrl.write('&crop=faces,center');
    
    return cdnUrl.toString();
  }

  /// Get avatar image URL
  String getAvatarUrl(String? originalUrl, {int size = 100}) {
    if (originalUrl == null || originalUrl.isEmpty) {
      return '$_fallbackBaseUrl/$size/$size/cccccc/000000?text=Avatar'; // More reliable placeholder
    }
    
    return getOptimizedImageUrl(
      originalUrl: originalUrl,
      width: size,
      height: size,
      isAvatar: true,
    );
  }

  /// Get thumbnail image URL
  String getThumbnailUrl(String? originalUrl, {int width = 300, int height = 200}) {
    if (originalUrl == null || originalUrl.isEmpty) {
      return '$_fallbackBaseUrl/$width/$height/cccccc/000000?text=Thumbnail'; // More reliable placeholder
    }
    
    return getOptimizedImageUrl(
      originalUrl: originalUrl,
      width: width,
      height: height,
      isThumbnail: true,
    );
  }

  /// Get video thumbnail URL
  String getVideoThumbnailUrl(String? videoUrl, {int width = 400, int height = 300}) {
    if (videoUrl == null || videoUrl.isEmpty) {
      return '$_fallbackBaseUrl/$width/$height?random=${DateTime.now().millisecondsSinceEpoch}';
    }
    
    // For video thumbnails, we might need to extract the thumbnail
    // This is a simplified implementation
    return getOptimizedImageUrl(
      originalUrl: videoUrl,
      width: width,
      height: height,
      isThumbnail: true,
    );
  }

  /// Get banner image URL
  String getBannerUrl(String? originalUrl, {int width = 800, int height = 400}) {
    if (originalUrl == null || originalUrl.isEmpty) {
      return '$_fallbackBaseUrl/$width/$height?random=${DateTime.now().millisecondsSinceEpoch}';
    }
    
    return getOptimizedImageUrl(
      originalUrl: originalUrl,
      width: width,
      height: height,
    );
  }

  /// Get profile cover image URL
  String getProfileCoverUrl(String? originalUrl, {int width = 1200, int height = 400}) {
    if (originalUrl == null || originalUrl.isEmpty) {
      return '$_fallbackBaseUrl/$width/$height?random=${DateTime.now().millisecondsSinceEpoch}';
    }
    
    return getOptimizedImageUrl(
      originalUrl: originalUrl,
      width: width,
      height: height,
    );
  }

  /// Create optimized CachedNetworkImage widget
  Widget createOptimizedImage({
    required String imageUrl,
    int? width,
    int? height,
    BoxFit fit = BoxFit.cover,
    Widget? placeholder,
    Widget? errorWidget,
    bool isAvatar = false,
    bool isThumbnail = false,
  }) {
    final optimizedUrl = getOptimizedImageUrl(
      originalUrl: imageUrl,
      width: width,
      height: height,
      isAvatar: isAvatar,
      isThumbnail: isThumbnail,
    );

    return CachedNetworkImage(
      imageUrl: optimizedUrl,
      width: width?.toDouble(),
      height: height?.toDouble(),
      fit: fit,
      placeholder: (context, url) => placeholder ?? _buildDefaultPlaceholder(),
      errorWidget: (context, url, error) => errorWidget ?? _buildDefaultErrorWidget(),
      memCacheWidth: width,
      memCacheHeight: height,
      maxWidthDiskCache: width != null ? width * 2 : null,
      maxHeightDiskCache: height != null ? height * 2 : null,
    );
  }

  /// Create avatar widget
  Widget createAvatar({
    required String? imageUrl,
    double size = 100,
    Widget? placeholder,
    Widget? errorWidget,
  }) {
    return ClipOval(
      child: createOptimizedImage(
        imageUrl: imageUrl ?? '',
        width: size.toInt(),
        height: size.toInt(),
        isAvatar: true,
        placeholder: placeholder,
        errorWidget: errorWidget,
      ),
    );
  }

  /// Create thumbnail widget
  Widget createThumbnail({
    required String? imageUrl,
    double width = 300,
    double height = 200,
    BoxFit fit = BoxFit.cover,
    Widget? placeholder,
    Widget? errorWidget,
  }) {
    return createOptimizedImage(
      imageUrl: imageUrl ?? '',
      width: width.toInt(),
      height: height.toInt(),
      fit: fit,
      isThumbnail: true,
      placeholder: placeholder,
      errorWidget: errorWidget,
    );
  }

  /// Build default placeholder
  Widget _buildDefaultPlaceholder() {
    return Container(
      color: Colors.grey[300],
      child: const Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
        ),
      ),
    );
  }

  /// Build default error widget
  Widget _buildDefaultErrorWidget() {
    return Container(
      color: Colors.grey[300],
      child: const Center(
        child: Icon(
          Icons.error_outline,
          color: Colors.grey,
        ),
      ),
    );
  }

  /// Preload images for better performance
  Future<void> preloadImages(List<String> imageUrls, BuildContext context) async {
    for (final url in imageUrls) {
      try {
        final optimizedUrl = getOptimizedImageUrl(originalUrl: url);
        await precacheImage(
          CachedNetworkImageProvider(optimizedUrl),
          context,
        );
      } catch (e) {
        debugPrint('Failed to preload image: $url - $e');
      }
    }
  }

  /// Clear image cache
  void clearCache() {
    // This would clear the CachedNetworkImage cache
    // In a real implementation, you'd use the cache manager
    debugPrint('Image cache cleared');
  }

  /// Get cache size
  Future<int> getCacheSize() async {
    // This would return the actual cache size
    // For now, return a placeholder
    return 0;
  }
}
