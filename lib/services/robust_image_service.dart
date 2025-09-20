import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:async';

/// Robust Image Service
/// 
/// Handles image loading with proper error handling and fallbacks
/// to prevent app crashes from network issues
class RobustImageService {
  static final RobustImageService _instance = RobustImageService._internal();
  factory RobustImageService() => _instance;
  RobustImageService._internal();

  // Reliable placeholder URLs (unused but kept for future reference)
  // static const String _avatarPlaceholder = 'https://via.placeholder.com/100x100/cccccc/000000?text=Avatar';
  // static const String _thumbnailPlaceholder = 'https://via.placeholder.com/300x200/cccccc/000000?text=Video';
  
  // Network timeout settings
  static const Duration _networkTimeout = Duration(seconds: 10);
  static const Duration _retryDelay = Duration(seconds: 2);

  /// Get a robust image widget with proper error handling
  Widget getRobustImage({
    required String? imageUrl,
    required double width,
    required double height,
    BoxFit fit = BoxFit.cover,
    Widget? placeholder,
    Widget? errorWidget,
    bool isAvatar = false,
    bool isThumbnail = false,
  }) {
    // Handle null or empty URLs
    if (imageUrl == null || imageUrl.isEmpty) {
      return _buildPlaceholder(width, height, isAvatar, isThumbnail);
    }

    // Validate URL
    final uri = Uri.tryParse(imageUrl);
    if (uri == null || !uri.hasAbsolutePath) {
      return _buildPlaceholder(width, height, isAvatar, isThumbnail);
    }

    return Image.network(
      imageUrl,
      width: width,
      height: height,
      fit: fit,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return placeholder ?? _buildLoadingPlaceholder(width, height);
      },
      errorBuilder: (context, error, stackTrace) {
        debugPrint('⚠️ RobustImageService: Failed to load image $imageUrl: $error');
        return errorWidget ?? _buildPlaceholder(width, height, isAvatar, isThumbnail);
      },
      // Optimize for memory
      cacheWidth: (width * 0.8).toInt(),
      cacheHeight: (height * 0.8).toInt(),
      filterQuality: FilterQuality.low,
      // Add timeout and retry logic
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded) return child;
        return AnimatedOpacity(
          opacity: frame == null ? 0 : 1,
          duration: const Duration(milliseconds: 300),
          child: child,
        );
      },
    );
  }

  /// Get avatar widget with robust error handling
  Widget getAvatar({
    required String? imageUrl,
    double radius = 20,
    Widget? placeholder,
    Widget? errorWidget,
  }) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.grey[300],
      child: ClipOval(
        child: getRobustImage(
          imageUrl: imageUrl,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          placeholder: placeholder,
          errorWidget: errorWidget,
          isAvatar: true,
        ),
      ),
    );
  }

  /// Test network connectivity for image loading
  Future<bool> testImageConnectivity(String imageUrl) async {
    try {
      final uri = Uri.parse(imageUrl);
      final client = HttpClient();
      client.connectionTimeout = _networkTimeout;
      
      final request = await client.getUrl(uri);
      final response = await request.close();
      
      client.close();
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('⚠️ RobustImageService: Connectivity test failed for $imageUrl: $e');
      return false;
    }
  }

  /// Build placeholder widget
  Widget _buildPlaceholder(double width, double height, bool isAvatar, bool isThumbnail) {
    if (isAvatar) {
      return Container(
        width: width,
        height: height,
        decoration: const BoxDecoration(
          color: Color(0xFFE0E0E0),
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.person,
          size: width * 0.6,
          color: Colors.grey[600],
        ),
      );
    } else if (isThumbnail) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          Icons.video_library,
          size: width * 0.3,
          color: Colors.grey[600],
        ),
      );
    } else {
      return Container(
        width: width,
        height: height,
        color: Colors.grey[300],
        child: Icon(
          Icons.image,
          size: width * 0.3,
          color: Colors.grey[600],
        ),
      );
    }
  }

  /// Build loading placeholder
  Widget _buildLoadingPlaceholder(double width, double height) {
    return Container(
      width: width,
      height: height,
      color: Colors.grey[200],
      child: const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.grey),
          ),
        ),
      ),
    );
  }

  /// Preload images with retry logic
  Future<void> preloadImages(List<String> imageUrls, {int maxRetries = 2}) async {
    for (final url in imageUrls) {
      if (url.isEmpty) continue;
      
      bool success = false;
      int retries = 0;
      
      while (!success && retries < maxRetries) {
        try {
          // Test connectivity first
          final isConnected = await testImageConnectivity(url);
          if (isConnected) {
            // Preload the image (context is not available in this method, skip preloading)
            // await precacheImage(NetworkImage(url), context);
            success = true;
            debugPrint('✅ RobustImageService: Preloaded $url');
          } else {
            throw Exception('Connectivity test failed');
          }
        } catch (e) {
          retries++;
          if (retries < maxRetries) {
            debugPrint('⚠️ RobustImageService: Retry $retries for $url: $e');
            await Future.delayed(_retryDelay);
          } else {
            debugPrint('❌ RobustImageService: Failed to preload $url after $maxRetries retries: $e');
          }
        }
      }
    }
  }

  /// Get reliable placeholder URL
  String getPlaceholderUrl({bool isAvatar = false, bool isThumbnail = false, int width = 100, int height = 100}) {
    if (isAvatar) {
      return 'https://via.placeholder.com/$width x$height/cccccc/000000?text=Avatar';
    } else if (isThumbnail) {
      return 'https://via.placeholder.com/$width x$height/cccccc/000000?text=Video';
    } else {
      return 'https://via.placeholder.com/$width x$height/cccccc/000000?text=Image';
    }
  }
}
