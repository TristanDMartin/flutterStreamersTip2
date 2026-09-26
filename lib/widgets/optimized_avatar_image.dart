import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class OptimizedAvatarImage extends StatelessWidget {
  final String? imageUrl;
  final double size;
  final Color? backgroundColor;
  final Widget? placeholder;
  final Widget? errorWidget;
  final String? displayName;

  const OptimizedAvatarImage({
    super.key,
    required this.imageUrl,
    required this.size,
    this.backgroundColor,
    this.placeholder,
    this.errorWidget,
    this.displayName,
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
        memCacheWidth: (size * 2).round(),
        memCacheHeight: (size * 2).round(),
        maxWidthDiskCache: (size * 3).round(),
        maxHeightDiskCache: (size * 3).round(),
      ),
    );
  }

  Widget _buildInitialsOrPerson() {
    final String trimmed = (displayName ?? '').trim();
    if (trimmed.isNotEmpty) {
      return Text(
        trimmed.substring(0, 1).toUpperCase(),
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.4,
          fontWeight: FontWeight.w600,
        ),
      );
    }
    return Icon(
      Icons.person,
      color: Colors.white,
      size: size * 0.5,
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      width: size,
      height: size,
      color: backgroundColor ?? Colors.grey[800],
      alignment: Alignment.center,
      child: placeholder ?? _buildInitialsOrPerson(),
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      width: size,
      height: size,
      color: backgroundColor ?? Colors.grey[800],
      alignment: Alignment.center,
      // Never show an error/broken icon for avatars — initials or person mark.
      child: errorWidget ?? _buildInitialsOrPerson(),
    );
  }
}
