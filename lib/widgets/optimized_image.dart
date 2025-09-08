import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class OptimizedImage extends StatelessWidget {
  final String? imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;
  final BorderRadius? borderRadius;

  const OptimizedImage({
    Key? key,
    this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
    this.borderRadius,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null || imageUrl!.isEmpty) {
      return _buildPlaceholder();
    }

    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.zero,
      child: CachedNetworkImage(
        imageUrl: imageUrl!,
        width: width,
        height: height,
        fit: fit,
        memCacheWidth: width != null ? (width! * 0.3).toInt() : 150,
        memCacheHeight: height != null ? (height! * 0.3).toInt() : 150,
        maxWidthDiskCache: 150,
        maxHeightDiskCache: 150,
        cacheManager: CacheManager(
          Config(
            'optimized_images',
            stalePeriod: const Duration(days: 7),
            maxNrOfCacheObjects: 50,
            repo: JsonCacheInfoRepository(databaseName: 'optimized_images'),
            fileService: HttpFileService(),
          ),
        ),
        placeholder: (context, url) => _buildPlaceholder(),
        errorWidget: (context, url, error) => _buildErrorWidget(),
        fadeInDuration: const Duration(milliseconds: 200),
        fadeOutDuration: const Duration(milliseconds: 100),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: borderRadius,
      ),
      child: placeholder ?? const Icon(
        Icons.person,
        color: Colors.grey,
        size: 24,
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: borderRadius,
      ),
      child: errorWidget ?? const Icon(
        Icons.error_outline,
        color: Colors.grey,
        size: 24,
      ),
    );
  }
}

class OptimizedAvatar extends StatelessWidget {
  final String? imageUrl;
  final double radius;
  final Color? backgroundColor;
  final Widget? child;

  const OptimizedAvatar({
    Key? key,
    this.imageUrl,
    this.radius = 20,
    this.backgroundColor,
    this.child,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor ?? Colors.grey[300],
      child: imageUrl != null && imageUrl!.isNotEmpty
          ? ClipOval(
              child: CachedNetworkImage(
                imageUrl: imageUrl!,
                width: radius * 2,
                height: radius * 2,
                fit: BoxFit.cover,
                memCacheWidth: (radius * 0.3).toInt(),
                memCacheHeight: (radius * 0.3).toInt(),
                maxWidthDiskCache: 80,
                maxHeightDiskCache: 80,
                cacheManager: CacheManager(
                  Config(
                    'optimized_avatars',
                    stalePeriod: const Duration(days: 7),
                    maxNrOfCacheObjects: 100,
                    repo: JsonCacheInfoRepository(databaseName: 'optimized_avatars'),
                    fileService: HttpFileService(),
                  ),
                ),
                placeholder: (context, url) => _buildPlaceholder(),
                errorWidget: (context, url, error) => _buildErrorWidget(),
                fadeInDuration: const Duration(milliseconds: 200),
                fadeOutDuration: const Duration(milliseconds: 100),
              ),
            )
          : child ?? _buildPlaceholder(),
    );
  }

  Widget _buildPlaceholder() {
    return Icon(
      Icons.person,
      color: Colors.grey[600],
      size: radius * 0.8,
    );
  }

  Widget _buildErrorWidget() {
    return Icon(
      Icons.error_outline,
      color: Colors.grey[600],
      size: radius * 0.8,
    );
  }
}
