import 'package:flutter/material.dart';
import '../models/home_video.dart';
import '../services/thumbnail_service.dart';
import 'thumbnail_tile.dart';

/// Optimized thumbnail widget for 3-column grids with crisp, non-blurry images
class OptimizedThumbnail extends StatefulWidget {
  final HomeVideo video;
  final VoidCallback? onTap;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Widget? placeholder;
  final Widget? errorWidget;
  final bool showDraftBadge;
  final bool showDurationBadge;
  final bool showViewsBadge;

  const OptimizedThumbnail({
    super.key,
    required this.video,
    this.onTap,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.placeholder,
    this.errorWidget,
    this.showDraftBadge = true,
    this.showDurationBadge = true,
    this.showViewsBadge = false,
  });

  @override
  State<OptimizedThumbnail> createState() => _OptimizedThumbnailState();
}

class _OptimizedThumbnailState extends State<OptimizedThumbnail>
    with AutomaticKeepAliveClientMixin {
  final ThumbnailService _thumbnailService = ThumbnailService();
  late double _containerWidth;
  late double _containerHeight;
  late double _devicePixelRatio;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    // Initialize with default values, will be updated in didChangeDependencies
    _containerWidth = 100.0;
    _containerHeight = 177.0; // 16:9 aspect ratio
    _devicePixelRatio = 1.0;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateDimensions();
  }

  void _updateDimensions() {
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;

    // Calculate container dimensions for 3-column grid
    _containerWidth = widget.width ??
        (screenWidth - 32 - 32) / 3; // 16px edge padding + 16px gutters
    _containerHeight =
        widget.height ?? _containerWidth * (16 / 9); // 9:16 aspect ratio
    _devicePixelRatio = _thumbnailService.getDevicePixelRatio(context);

    debugPrint(
        '🖼️ OptimizedThumbnail: Container ${_containerWidth}x$_containerHeight, DPR $_devicePixelRatio');
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return GestureDetector(
      onTap: widget.onTap,
      child: AspectRatio(
        aspectRatio: 9 / 16,
        child: Container(
          width: _containerWidth,
          height: _containerHeight,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: widget.borderRadius ?? BorderRadius.circular(12),
          ),
          child: ClipRRect(
            borderRadius: widget.borderRadius ?? BorderRadius.circular(12),
            child: Stack(
              fit: StackFit.expand,
              children: [
                _buildThumbnailImage(),
                _buildGradientOverlay(),
                if (widget.showDurationBadge &&
                    widget.video.duration != null &&
                    widget.video.duration! > 0)
                  _buildDurationBadge(),
                if (widget.showViewsBadge && widget.video.views > 0)
                  _buildViewsBadge(),
                if (widget.showDraftBadge && widget.video.isDraft)
                  _buildDraftBadge(),
                _buildPlayIcon(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnailImage() {
    // Use the thumbnail service to get the optimal image
    return _thumbnailService.buildResponsiveThumbnail(
      thumbnails: widget.video.thumbnails,
      containerWidth: _containerWidth,
      containerHeight: _containerHeight,
      devicePixelRatio: _devicePixelRatio,
      fallbackUrl: widget.video.thumbnailURL, // Legacy fallback
      placeholder: widget.placeholder,
      errorWidget: widget.errorWidget,
      fit: widget.fit,
      borderRadius: widget.borderRadius,
      semanticsLabel: widget.video.caption.isNotEmpty
          ? widget.video.caption
          : 'Video thumbnail',
    );
  }

  Widget _buildGradientOverlay() {
    // No gradient overlay - return empty container
    return const SizedBox.shrink();
  }

  Widget _buildDurationBadge() {
    return Positioned(
      bottom: 8,
      left: 8,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          _formatDuration(widget.video.duration!),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildViewsBadge() {
    return Positioned(
      bottom: 8,
      right: 8,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          _formatViews(widget.video.views),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildDraftBadge() {
    return Positioned(
      top: 8,
      left: 8,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Text(
          'Draft',
          style: TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildPlayIcon() {
    return const Center(
      child: Icon(
        Icons.play_arrow,
        color: Colors.white,
        size: 32,
      ),
    );
  }

  String _formatDuration(double duration) {
    final minutes = (duration / 60).floor();
    final seconds = (duration % 60).floor();
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String _formatViews(int views) {
    if (views >= 1000000) {
      return '${(views / 1000000).toStringAsFixed(1)}M';
    } else if (views >= 1000) {
      return '${(views / 1000).toStringAsFixed(1)}K';
    } else {
      return views.toString();
    }
  }
}

/// Grid-specific thumbnail widget with automatic sizing
class GridThumbnail extends StatelessWidget {
  final HomeVideo video;
  final VoidCallback? onTap;
  final bool showDraftBadge;
  final bool showDurationBadge;
  final double? aspectRatio;

  const GridThumbnail({
    super.key,
    required this.video,
    this.onTap,
    this.showDraftBadge = true,
    this.showDurationBadge = true,
    this.aspectRatio,
  });

  @override
  Widget build(BuildContext context) {
    try {
      final mediaQuery = MediaQuery.of(context);
      final screenWidth = mediaQuery.size.width;
      final tileWidth =
          (screenWidth - 32 - 32) / 3; // 16px edge padding + 16px gutters
      final resolvedAspectRatio =
          (aspectRatio != null && aspectRatio! > 0) ? aspectRatio! : (9 / 16);
      final tileHeight = tileWidth / resolvedAspectRatio;

      return ThumbnailTile(
        video: video,
        onTap: onTap,
        width: tileWidth,
        height: tileHeight,
        borderRadius: BorderRadius.circular(12),
        showDraftBadge: showDraftBadge,
        showDurationBadge: showDurationBadge,
        showViewsBadge: false,
      );
    } catch (e) {
      // Fallback if MediaQuery is not available
      debugPrint('🖼️ GridThumbnail: Error accessing MediaQuery: $e');
      return ThumbnailTile(
        video: video,
        onTap: onTap,
        width: 100,
        height: 177,
        borderRadius: BorderRadius.circular(12),
        showDraftBadge: showDraftBadge,
        showDurationBadge: showDurationBadge,
        showViewsBadge: false,
      );
    }
  }
}
