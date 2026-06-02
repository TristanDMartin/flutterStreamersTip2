import 'package:flutter/material.dart';
import 'dart:async';
import '../services/ios_memory_service.dart';

class IOSOptimizedImage extends StatefulWidget {
  final String? imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;
  final BorderRadius? borderRadius;

  const IOSOptimizedImage({
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
  State<IOSOptimizedImage> createState() => _IOSOptimizedImageState();
}

class _IOSOptimizedImageState extends State<IOSOptimizedImage> {
  static int _activeImageCount = 0;
  static const int _maxActiveImages = 2; // More conservative for iOS
  bool _shouldLoad = false;
  Timer? _loadTimer;
  static final List<_IOSOptimizedImageState> _pendingImages = [];

  @override
  void initState() {
    super.initState();
    _scheduleLoad();
  }

  void _scheduleLoad() {
    if (_activeImageCount < _maxActiveImages && IOSMemoryService.canLoadImage) {
      setState(() {
        _shouldLoad = true;
        _activeImageCount++;
        IOSMemoryService.registerImageLoad();
      });
    } else {
      // Add to pending queue
      if (!_pendingImages.contains(this)) {
        _pendingImages.add(this);
      }

      // More conservative delay for iOS: 1-3 seconds between images
      _loadTimer = Timer(Duration(seconds: 1 + (_activeImageCount * 2)), () {
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
      IOSMemoryService.registerImageDispose();

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
    // CRITICAL: Disable all image loading to prevent ImageReader_JNI buffer overflow
    return _buildPlaceholder();

    // DISABLED: Image loading causes buffer overflow
    // if (widget.imageUrl == null || widget.imageUrl!.isEmpty) {
    //   return _buildPlaceholder();
    // }
    // if (!_shouldLoad) {
    //   return _buildPlaceholder();
    // }
    // return ClipRRect(
    //   borderRadius: widget.borderRadius ?? BorderRadius.zero,
    //   child: CachedNetworkImage(
    //     imageUrl: widget.imageUrl!,
    //     width: widget.width,
    //     height: widget.height,
    //     fit: widget.fit,
    //     memCacheWidth: widget.width != null ? (widget.width! * 0.8).toInt() : 300,
    //     memCacheHeight: widget.height != null ? (widget.height! * 0.8).toInt() : 200,
    //     maxWidthDiskCache: 600,
    //     maxHeightDiskCache: 600,
    //     cacheManager: CacheManager(
    //       Config(
    //         'ios_optimized_images',
    //         stalePeriod: const Duration(hours: 24),
    //         maxNrOfCacheObjects: 30,
    //         repo: JsonCacheInfoRepository(databaseName: 'ios_optimized_images'),
    //         fileService: HttpFileService(),
    //       ),
    //     ),
    //     placeholder: (context, url) => widget.placeholder ?? _buildPlaceholder(),
    //     errorWidget: (context, url, error) => widget.errorWidget ?? _buildErrorWidget(),
    //     fadeInDuration: const Duration(milliseconds: 300),
    //     fadeOutDuration: const Duration(milliseconds: 200),
    //   ),
    // );
  }

  Widget _buildPlaceholder() {
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: widget.borderRadius ?? BorderRadius.zero,
      ),
      child: widget.placeholder ??
          const Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
            ),
          ),
    );
  }

  // Removed unused _buildErrorWidget method
}
