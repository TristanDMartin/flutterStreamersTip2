import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'dart:async';
import '../services/memory_pressure_service.dart';

class OptimizedImage extends StatefulWidget {
  final String? imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;
  final BorderRadius? borderRadius;

  const OptimizedImage({
    super.key,
    this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
    this.borderRadius,
  });

  @override
  State<OptimizedImage> createState() => _OptimizedImageState();
}

class _OptimizedImageState extends State<OptimizedImage> {
  static int _activeImageCount = 0;
  static const int _maxActiveImages = 1; // ULTRA-AGGRESSIVE: Only 1 image at a time
  bool _shouldLoad = false;
  Timer? _loadTimer;
  static final List<_OptimizedImageState> _pendingImages = [];

  @override
  void initState() {
    super.initState();
    _scheduleLoad();
  }

  void _scheduleLoad() {
    if (_activeImageCount < _maxActiveImages && MemoryPressureService.canLoadImage) {
      setState(() {
        _shouldLoad = true;
        _activeImageCount++;
        MemoryPressureService.registerImageLoad();
      });
    } else {
      // Add to pending queue
      if (!_pendingImages.contains(this)) {
        _pendingImages.add(this);
      }
      
      // ULTRA-AGGRESSIVE delay: 3-8 seconds between images to prevent buffer issues
      _loadTimer = Timer(Duration(seconds: 3 + (_activeImageCount * 5)), () {
        if (mounted && _pendingImages.contains(this)) {
          _pendingImages.remove(this);
          _scheduleLoad();
        }
      });
    }
  }

  @override
  void dispose() {
    _loadTimer?.cancel();
    _pendingImages.remove(this);
    if (_shouldLoad) {
      _activeImageCount--;
      MemoryPressureService.registerImageDispose();
      
      // Process next pending image
      if (_pendingImages.isNotEmpty) {
        final nextImage = _pendingImages.removeAt(0);
        if (nextImage.mounted) {
          nextImage._scheduleLoad();
        }
      }
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.imageUrl == null || widget.imageUrl!.isEmpty) {
      return _buildPlaceholder();
    }

    if (!_shouldLoad) {
      return _buildPlaceholder();
    }

    return ClipRRect(
      borderRadius: widget.borderRadius ?? BorderRadius.zero,
      child: CachedNetworkImage(
        imageUrl: widget.imageUrl!,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        memCacheWidth: widget.width != null ? (widget.width! * 0.5).toInt() : 200,
        memCacheHeight: widget.height != null ? (widget.height! * 0.5).toInt() : 200,
        maxWidthDiskCache: 400,
        maxHeightDiskCache: 400,
        cacheManager: CacheManager(
          Config(
            'optimized_images',
            stalePeriod: const Duration(hours: 12),
            maxNrOfCacheObjects: 50,
            repo: JsonCacheInfoRepository(databaseName: 'optimized_images'),
            fileService: HttpFileService(),
          ),
        ),
        placeholder: (context, url) => widget.placeholder ?? _buildPlaceholder(),
        errorWidget: (context, url, error) => widget.errorWidget ?? _buildErrorWidget(),
        fadeInDuration: const Duration(milliseconds: 200),
        fadeOutDuration: const Duration(milliseconds: 100),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: widget.borderRadius,
      ),
      child: widget.placeholder ?? const Icon(
        Icons.person,
        color: Colors.grey,
        size: 20, // Reduced size
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: widget.borderRadius,
      ),
      child: widget.errorWidget ?? const Icon(
        Icons.error_outline,
        color: Colors.grey,
        size: 20, // Reduced size
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
    super.key,
    this.imageUrl,
    this.radius = 20,
    this.backgroundColor,
    this.child,
  });

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
                memCacheWidth: (radius * 0.1).toInt(),
                memCacheHeight: (radius * 0.1).toInt(),
                maxWidthDiskCache: 30,
                maxHeightDiskCache: 30,
                cacheManager: CacheManager(
                  Config(
                    'optimized_avatars',
            stalePeriod: const Duration(hours: 12),
            maxNrOfCacheObjects: 20,
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
