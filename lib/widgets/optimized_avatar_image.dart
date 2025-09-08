import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class OptimizedAvatarImage extends StatelessWidget {
  final String? imageUrl;
  final double size;
  final Color? backgroundColor;
  final Widget? placeholder;
  final Widget? errorWidget;

  const OptimizedAvatarImage({
    super.key,
    required this.imageUrl,
    required this.size,
    this.backgroundColor,
    this.placeholder,
    this.errorWidget,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null || imageUrl!.isEmpty) {
      return _buildPlaceholder();
    }

    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: imageUrl!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        placeholder: (context, url) => _buildPlaceholder(),
        errorWidget: (context, url, error) => _buildErrorWidget(),
        memCacheWidth: (size * 2).round(), // Optimize memory usage
        memCacheHeight: (size * 2).round(),
        maxWidthDiskCache: (size * 3).round(), // Optimize disk cache
        maxHeightDiskCache: (size * 3).round(),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      width: size,
      height: size,
      color: backgroundColor ?? Colors.grey[800],
      child: placeholder ?? const Icon(
        Icons.person,
        color: Colors.white,
        size: 28,
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      width: size,
      height: size,
      color: backgroundColor ?? Colors.grey[800],
      child: errorWidget ?? const Icon(
        Icons.error_outline,
        color: Colors.white,
        size: 28,
      ),
    );
  }
}
