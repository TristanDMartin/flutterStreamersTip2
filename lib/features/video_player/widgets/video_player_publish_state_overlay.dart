import 'package:flutter/material.dart';

/// Full-screen overlay while a video is processing or failed to upload.
class VideoPlayerPublishStateOverlay extends StatelessWidget {
  const VideoPlayerPublishStateOverlay({
    super.key,
    required this.status,
  });

  final String status;

  bool get _isFailed => status.toLowerCase() == 'failed';

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _isFailed
                    ? Icons.error_outline_rounded
                    : Icons.hourglass_top_rounded,
                color: Colors.white,
                size: 36,
              ),
              const SizedBox(height: 14),
              Text(
                _isFailed
                    ? 'Upload failed. Please try again.'
                    : 'Processing your video...',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (!_isFailed) ...[
                const SizedBox(height: 6),
                Text(
                  'This may take a moment.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.72),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
