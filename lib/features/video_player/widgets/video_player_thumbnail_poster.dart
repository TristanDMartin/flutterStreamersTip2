import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../models/home_video.dart';
import '../../../services/thumbnail_service.dart';

/// Resolves poster/thumbnail URLs for feed video cells.
class VideoPlayerThumbnailUrl {
  const VideoPlayerThumbnailUrl._();

  static String? muxFallbackFromVideoUrl(String? videoUrl) {
    if (videoUrl == null || !videoUrl.contains('stream.mux.com')) {
      return null;
    }
    final Uri? uri = Uri.tryParse(videoUrl);
    if (uri == null) return null;
    final List<String> segments = uri.pathSegments;
    if (segments.isEmpty) return null;
    final String playbackId = segments.first.replaceAll('.m3u8', '');
    if (playbackId.isEmpty) return null;
    return 'https://image.mux.com/$playbackId/thumbnail.jpg?time=0';
  }

  static String? resolve({
    required BuildContext context,
    required HomeVideo video,
    ThumbnailService? thumbnailService,
  }) {
    final MediaQueryData? mediaQuery = MediaQuery.maybeOf(context);
    final double containerWidth = mediaQuery?.size.width ?? 393;
    final double devicePixelRatio = mediaQuery?.devicePixelRatio ?? 1.0;
    final String? fallbackUrl =
        muxFallbackFromVideoUrl(video.videoURL);
    final ThumbnailService service = thumbnailService ?? ThumbnailService();
    final String? optimizedUrl = service.getDisplayReadyThumbnailUrl(
      thumbnails: video.thumbnails,
      containerWidth: containerWidth,
      devicePixelRatio: devicePixelRatio,
      fallbackUrl: video.thumbnailURL ?? fallbackUrl,
    );
    if (optimizedUrl != null && optimizedUrl.isNotEmpty) {
      return optimizedUrl;
    }
    final String? thumbnailUrl = video.thumbnailURL;
    if (thumbnailUrl != null && thumbnailUrl.isNotEmpty) {
      return thumbnailUrl;
    }
    return fallbackUrl;
  }
}

/// Cached poster image shown until the first video frame is visible.
class VideoPlayerThumbnailPoster extends StatelessWidget {
  const VideoPlayerThumbnailPoster({
    super.key,
    required this.video,
    this.fit = BoxFit.cover,
    this.thumbnailService,
  });

  final HomeVideo video;
  final BoxFit fit;
  final ThumbnailService? thumbnailService;

  @override
  Widget build(BuildContext context) {
    final String? url = VideoPlayerThumbnailUrl.resolve(
      context: context,
      video: video,
      thumbnailService: thumbnailService,
    );
    if (url == null) return const ColoredBox(color: Colors.black);
    final MediaQueryData? mediaQuery = MediaQuery.maybeOf(context);
    final double containerWidth = mediaQuery?.size.width ?? 393;
    final double containerHeight = mediaQuery?.size.height ?? 852;
    final double devicePixelRatio = mediaQuery?.devicePixelRatio ?? 1.0;
    return CachedNetworkImage(
      imageUrl: url,
      fit: fit,
      width: double.infinity,
      height: double.infinity,
      memCacheWidth: (containerWidth * devicePixelRatio).round(),
      memCacheHeight: (containerHeight * devicePixelRatio).round(),
      filterQuality: FilterQuality.high,
      errorWidget: (_, __, ___) => const ColoredBox(color: Colors.black),
      placeholder: (_, __) => const ColoredBox(color: Colors.black),
    );
  }
}
