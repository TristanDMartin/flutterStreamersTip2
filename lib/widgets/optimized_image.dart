import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'dart:async';
import 'dart:collection';
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
  bool _shouldLoad = false;
  Timer? _loadTimer;
  static int _activeImageCount = 0;
  static const int _maxActiveImages =
      10; // Allow 10 images for better UX (Instagram/TikTok style)
  static final Queue<String> _imageQueue = Queue<String>();

  @override
  void initState() {
    super.initState();
    _scheduleLoad();
  }

  void _scheduleLoad() {
    // OPTIMIZED: Faster image loading with smart queue management
    _loadTimer?.cancel();

    // Add to queue if not already there
    if (widget.imageUrl != null && !_imageQueue.contains(widget.imageUrl)) {
      _imageQueue.add(widget.imageUrl!);
    }

    // Only load if we're under the limit and it's our turn
    if (_activeImageCount < _maxActiveImages &&
        _imageQueue.isNotEmpty &&
        _imageQueue.first == widget.imageUrl) {
      // OPTIMIZED: Reduced delay from 1000ms to 100ms for faster loading
      _loadTimer = Timer(const Duration(milliseconds: 100), () {
        if (mounted && _activeImageCount < _maxActiveImages) {
          setState(() {
            _shouldLoad = true;
            _activeImageCount++;
          });
          MemoryPressureService.registerImageLoad();
        }
      });
    } else {
      // OPTIMIZED: Reduced retry delay from 3000ms to 500ms
      _loadTimer = Timer(const Duration(milliseconds: 500), () {
        _scheduleLoad(); // Retry
      });
    }
  }

  @override
  void dispose() {
    _loadTimer?.cancel();
    if (_shouldLoad) {
      _activeImageCount--;
      MemoryPressureService.registerImageDispose();

      // Remove from queue and process next
      if (_imageQueue.isNotEmpty) {
        _imageQueue.removeFirst();
      }
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Check memory pressure before loading
    if (!MemoryPressureService.canLoadImage) {
      return _buildPlaceholder();
    }

    if (!_shouldLoad || widget.imageUrl == null || widget.imageUrl!.isEmpty) {
      return _buildPlaceholder();
    }

    return CachedNetworkImage(
      imageUrl: widget.imageUrl!,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      placeholder: (context, url) => _buildPlaceholder(),
      errorWidget: (context, url, error) {
        // Network error recovery: Retry loading on network errors
        final errorString = error.toString().toLowerCase();
        final isNetworkError = errorString.contains('network') ||
            errorString.contains('connection') ||
            errorString.contains('timeout') ||
            errorString.contains('socket') ||
            errorString.contains('failed host lookup');

        if (isNetworkError && mounted) {
          // Retry after a delay
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) {
              setState(() {
                _shouldLoad = false;
              });
              _scheduleLoad(); // Retry loading
            }
          });
        }

        debugPrint('⚠️ OptimizedImage: failed loading $url - $error');
        return widget.errorWidget ?? _buildPlaceholder();
      },
      // OPTIMIZED: Increased cache sizes for better quality while maintaining performance
      memCacheWidth:
          (widget.width ?? 100) > 400 ? 400 : (widget.width ?? 100).toInt(),
      memCacheHeight:
          (widget.height ?? 100) > 400 ? 400 : (widget.height ?? 100).toInt(),
      maxWidthDiskCache: 400, // OPTIMIZED: Increased from 200 to 400
      maxHeightDiskCache: 400, // OPTIMIZED: Increased from 200 to 400
      cacheManager: CacheManager(
        Config(
          'optimized_images',
          stalePeriod: const Duration(hours: 24), // OPTIMIZED: Increased from 6 to 24 hours
          maxNrOfCacheObjects: 50, // OPTIMIZED: Increased from 20 to 50 for better caching
          repo: JsonCacheInfoRepository(databaseName: 'optimized_images'),
          fileService: HttpFileService(),
        ),
      ),
      fadeInDuration: const Duration(milliseconds: 150), // OPTIMIZED: Faster fade-in
      fadeOutDuration: const Duration(milliseconds: 50), // OPTIMIZED: Faster fade-out
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
      child: widget.placeholder ??
          const Icon(
            Icons.person,
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
                    repo: JsonCacheInfoRepository(
                        databaseName: 'optimized_avatars'),
                    fileService: HttpFileService(),
                  ),
                ),
                placeholder: (context, url) => _buildPlaceholder(),
                errorWidget: (context, url, error) => _buildPlaceholder(),
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
}
