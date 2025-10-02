import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import '../models/home_video.dart';

/// TikTok-style video thumbnail with crisp images and proper performance
class TikTokVideoThumbnail extends StatelessWidget {
  final HomeVideo video;
  final VoidCallback onTap;
  final double? width;
  final double? height;

  const TikTokVideoThumbnail({
    super.key,
    required this.video,
    required this.onTap,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final tileWidth =
        (screenWidth - 32 - 32) / 3; // 16px edge padding + 16px gutters
    final tileHeight = tileWidth * (16 / 9); // 9:16 aspect ratio

    // Debug: Show video data
    debugPrint(
        '🎬 TikTokVideoThumbnail build: Video ${video.id} - thumbnailURL: ${video.thumbnailURL}, videoURL: ${video.videoURL}');

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width ?? tileWidth,
        height: height ?? tileHeight,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18), // 16-20px radius
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Main thumbnail image
              _buildThumbnailImage(),

              // Gradient overlay for text legibility
              _buildGradientOverlay(),

              // Duration badge (bottom-left)
              if (_shouldShowDuration()) _buildDurationBadge(),

              // Views badge (bottom-right)
              if (_shouldShowViews()) _buildViewsBadge(),

              // Play icon (center, only on hover/press)
              _buildPlayIcon(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnailImage() {
    // Use the best available thumbnail URL
    final thumbnailUrl = _getBestThumbnailUrl();

    if (thumbnailUrl == null || thumbnailUrl.isEmpty) {
      debugPrint(
          '🎬 TikTokVideoThumbnail: No thumbnail URL, showing generated thumbnail');
      return _buildGeneratedThumbnail();
    }

    // Check if this is a video URL (no thumbnail available)
    if (_isVideoUrl(thumbnailUrl)) {
      debugPrint(
          '🎬 TikTokVideoThumbnail: Using video URL for thumbnail: $thumbnailUrl');
      return _buildVideoThumbnail(thumbnailUrl);
    }

    debugPrint(
        '🎬 TikTokVideoThumbnail: Loading image from URL: $thumbnailUrl');
    return CachedNetworkImage(
      imageUrl: thumbnailUrl,
      fit: BoxFit.cover, // Center-crop to maintain aspect ratio
      memCacheWidth: (width ?? 200).round(), // Optimize for tile size
      memCacheHeight: (height ?? 355).round(), // 9:16 aspect ratio
      placeholder: (context, url) {
        debugPrint('🎬 TikTokVideoThumbnail: Loading placeholder for $url');
        return _buildShimmerPlaceholder();
      },
      errorWidget: (context, url, error) {
        debugPrint('🎬 TikTokVideoThumbnail: Error loading image $url: $error');
        return _buildPlaceholder();
      },
      fadeInDuration: const Duration(milliseconds: 200),
      fadeOutDuration: const Duration(milliseconds: 100),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.grey[800]!,
            Colors.grey[900]!,
          ],
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.videocam_outlined,
          color: Colors.white54,
          size: 32,
        ),
      ),
    );
  }

  Widget _buildTestImage() {
    // TEMPORARY: Show a test image to verify the UI is working
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.blue[400]!,
            Colors.purple[600]!,
          ],
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.play_circle_filled,
          color: Colors.white,
          size: 60,
        ),
      ),
    );
  }

  Widget _buildGeneratedThumbnail() {
    // Generate a proper video thumbnail on-the-fly
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.grey[700]!,
            Colors.grey[900]!,
            Colors.black,
          ],
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[600]!, width: 1),
      ),
      child: Stack(
        children: [
          // Video-like pattern
          Positioned.fill(
            child: CustomPaint(
              painter: VideoThumbnailPainter(),
            ),
          ),
          // Play icon
          const Center(
            child: Icon(
              Icons.play_circle_filled,
              color: Colors.white,
              size: 50,
            ),
          ),
          // Duration badge
          if (video.duration != null && video.duration! > 0)
            Positioned(
              bottom: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _formatDuration(video.duration!),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildShimmerPlaceholder() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.grey[800]!,
            Colors.grey[700]!,
            Colors.grey[800]!,
          ],
        ),
      ),
      child: const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white54),
          ),
        ),
      ),
    );
  }

  Widget _buildGradientOverlay() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.black.withOpacity(0.3),
            Colors.black.withOpacity(0.6),
          ],
          stops: const [0.0, 0.6, 1.0],
        ),
      ),
    );
  }

  Widget _buildDurationBadge() {
    final duration = _formatDuration(video.duration ?? 0);
    return Positioned(
      left: 8,
      bottom: 8,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          duration,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildViewsBadge() {
    return Positioned(
      right: 8,
      bottom: 8,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          _formatViews(video.views),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildPlayIcon() {
    return Center(
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Icon(
          Icons.play_arrow,
          color: Colors.black87,
          size: 24,
        ),
      ),
    );
  }

  String? _getBestThumbnailUrl() {
    debugPrint(
        '🎬 TikTokVideoThumbnail: Video ${video.id} - thumbnailURL: ${video.thumbnailURL}, videoURL: ${video.videoURL}');

    // Priority order for thumbnail URLs
    if (video.thumbnailURL != null && video.thumbnailURL!.isNotEmpty) {
      debugPrint(
          '🎬 TikTokVideoThumbnail: Using thumbnailURL: ${video.thumbnailURL}');
      return video.thumbnailURL;
    }

    // Fallback: use video URL as thumbnail source
    // This will show the first frame of the video as thumbnail
    if (video.videoURL.isNotEmpty) {
      debugPrint(
          '🎬 TikTokVideoThumbnail: Using videoURL as fallback: ${video.videoURL}');
      return video.videoURL;
    }

    debugPrint(
        '🎬 TikTokVideoThumbnail: No valid URL found for video ${video.id}');
    return null;
  }

  bool _isVideoUrl(String url) {
    final videoExtensions = ['.mp4', '.mov', '.avi', '.mkv', '.webm', '.m4v'];
    return videoExtensions.any((ext) => url.toLowerCase().contains(ext));
  }

  Widget _buildVideoThumbnail(String videoUrl) {
    return VideoThumbnailWidget(
      videoUrl: videoUrl,
      width: width ?? 200,
      height: height ?? 355,
    );
  }

  bool _shouldShowDuration() {
    final duration = video.duration ?? 0;
    return duration > 1.0; // Hide for very short clips (<1s)
  }

  bool _shouldShowViews() {
    return video.views > 0;
  }

  String _formatDuration(double seconds) {
    if (seconds < 60) {
      return '${seconds.round()}s';
    } else if (seconds < 3600) {
      final minutes = (seconds / 60).floor();
      final remainingSeconds = (seconds % 60).round();
      return '${minutes}:${remainingSeconds.toString().padLeft(2, '0')}';
    } else {
      final hours = (seconds / 3600).floor();
      final minutes = ((seconds % 3600) / 60).floor();
      return '${hours}:${minutes.toString().padLeft(2, '0')}';
    }
  }

  String _formatViews(int views) {
    if (views < 1000) {
      return views.toString();
    } else if (views < 1000000) {
      return '${(views / 1000).toStringAsFixed(1)}K';
    } else {
      return '${(views / 1000000).toStringAsFixed(1)}M';
    }
  }
}

/// Widget that generates thumbnail from video URL
class VideoThumbnailWidget extends StatefulWidget {
  final String videoUrl;
  final double width;
  final double height;

  const VideoThumbnailWidget({
    super.key,
    required this.videoUrl,
    required this.width,
    required this.height,
  });

  @override
  State<VideoThumbnailWidget> createState() => _VideoThumbnailWidgetState();
}

class _VideoThumbnailWidgetState extends State<VideoThumbnailWidget> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _initializeVideo() async {
    try {
      _controller =
          VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
      await _controller!.initialize();

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      // If video fails to load, we'll show placeholder
      if (mounted) {
        setState(() {
          _isInitialized = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized || _controller == null) {
      return Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.grey[800]!,
              Colors.grey[900]!,
            ],
          ),
        ),
        child: const Center(
          child: Icon(
            Icons.play_circle_outline,
            color: Colors.white,
            size: 40,
          ),
        ),
      );
    }

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: _controller!.value.size.width,
          height: _controller!.value.size.height,
          child: VideoPlayer(_controller!),
        ),
      ),
    );
  }
}

/// Custom painter for video thumbnail pattern
class VideoThumbnailPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();

    // Create a video-like pattern with diagonal lines
    for (int i = 0; i < size.width; i += 20) {
      paint.color = Colors.grey[800]!.withOpacity(0.3);
      canvas.drawLine(
        Offset(i.toDouble(), 0),
        Offset(i.toDouble(), size.height),
        paint,
      );
    }

    // Add some random dots to simulate video content
    final random = Random();
    for (int i = 0; i < 50; i++) {
      paint.color = Colors.grey[600]!.withOpacity(0.4);
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      canvas.drawCircle(Offset(x, y), 2, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
