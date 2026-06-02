import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../models/home_video.dart';
import '../../models/optimistic_video.dart';

class HomeFeedProcessingCell extends StatelessWidget {
  final HomeVideo video;
  final OptimisticVideo? optimistic;

  const HomeFeedProcessingCell({
    super.key,
    required this.video,
    this.optimistic,
  });

  bool get _hasFailed {
    final String status = video.status.toLowerCase();
    return status.contains('fail') || optimistic?.status.hasFailed == true;
  }

  double get _uploadProgress {
    final double? progress = optimistic?.uploadProgress;
    if (progress == null) {
      return 0;
    }
    return progress.clamp(0.0, 1.0);
  }

  Widget _buildBackground() {
    final String? localPath = optimistic?.localThumbnailPath;
    if (localPath != null && localPath.isNotEmpty) {
      final File file = File(localPath);
      if (file.existsSync()) {
        return Image.file(file, fit: BoxFit.cover);
      }
    }

    final String networkUrl =
        optimistic?.thumbnailUrl ?? video.thumbnailURL ?? '';
    if (networkUrl.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: networkUrl,
        fit: BoxFit.cover,
        errorWidget: (_, __, ___) => const ColoredBox(color: Colors.black),
      );
    }

    return const ColoredBox(color: Color(0xFF0E0E0E));
  }

  @override
  Widget build(BuildContext context) {
    final String headline =
        _hasFailed ? 'Upload failed' : 'Processing your video...';
    final String subtitle = _hasFailed
        ? (optimistic?.errorMessage ?? 'Tap publish again to retry this clip.')
        : 'Your clip will appear here when ready.';

    return ColoredBox(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _buildBackground(),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.35),
                  Colors.black.withValues(alpha: 0.55),
                  Colors.black.withValues(alpha: 0.82),
                ],
              ),
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _hasFailed
                          ? Icons.error_outline_rounded
                          : Icons.hourglass_top_rounded,
                      color: Colors.white,
                      size: 34,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    headline,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.82),
                      fontSize: 14,
                      height: 1.35,
                    ),
                  ),
                  if (!_hasFailed && _uploadProgress > 0) ...[
                    const SizedBox(height: 18),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        minHeight: 4,
                        value: _uploadProgress,
                        backgroundColor: Colors.white.withValues(alpha: 0.18),
                        color: const Color(0xFF1670DE),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (video.caption.isNotEmpty)
            Positioned(
              left: 16,
              right: 88,
              bottom: 96,
              child: Text(
                video.caption,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
