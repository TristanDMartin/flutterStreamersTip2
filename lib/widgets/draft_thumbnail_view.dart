import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

/// DraftThumbnailView - Generates and displays thumbnails for draft videos
/// 
/// Features:
/// - Generates thumbnails from local video files
/// - Caches thumbnails for performance
/// - Handles error states gracefully
/// - Matches iOS design specifications
class DraftThumbnailView extends StatefulWidget {
  final String videoUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius borderRadius;

  const DraftThumbnailView({
    super.key,
    required this.videoUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
  });

  @override
  State<DraftThumbnailView> createState() => _DraftThumbnailViewState();
}

class _DraftThumbnailViewState extends State<DraftThumbnailView> {
  String? _thumbnailPath;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _generateThumbnail();
  }

  @override
  void didUpdateWidget(covariant DraftThumbnailView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoUrl != widget.videoUrl) {
      _generateThumbnail();
    }
  }

  Future<void> _generateThumbnail() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _thumbnailPath = null;
    });

    if (widget.videoUrl.isEmpty) {
      setState(() {
        _hasError = true;
        _isLoading = false;
      });
      return;
    }

    try {
      // Check if it's a local file
      String videoPath = widget.videoUrl;
      if (videoPath.startsWith('file://')) {
        videoPath = videoPath.replaceFirst('file://', '');
      }

      // Generate thumbnail filename
      final fileName = path.basenameWithoutExtension(videoPath);
      final tempDir = await getTemporaryDirectory();
      final thumbnailPath = await VideoThumbnail.thumbnailFile(
        video: videoPath,
        thumbnailPath: '${tempDir.path}/draft_${fileName}_thumbnail.jpg',
        maxHeight: 400, // Higher resolution for crisp thumbnails
        maxWidth: 400, // Higher resolution for crisp thumbnails
        quality: 95, // High quality for crisp images
      );

      if (mounted) {
        setState(() {
          _thumbnailPath = thumbnailPath;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error generating draft thumbnail for ${widget.videoUrl}: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget content;

    if (_isLoading) {
      content = Container(
        width: widget.width,
        height: widget.height,
        color: Colors.grey[900],
        child: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF9248D2)),
            strokeWidth: 2,
          ),
        ),
      );
    } else if (_hasError || _thumbnailPath == null) {
      content = Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: Colors.grey[800],
          borderRadius: widget.borderRadius,
        ),
        child: const Center(
          child: Icon(
            Icons.videocam_outlined,
            color: Colors.white54,
            size: 40,
          ),
        ),
      );
    } else {
      content = ClipRRect(
        borderRadius: widget.borderRadius,
        child: Image.file(
          File(_thumbnailPath!),
          width: widget.width,
          height: widget.height,
          fit: widget.fit,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              width: widget.width,
              height: widget.height,
              color: Colors.grey[800],
              child: const Center(
                child: Icon(
                  Icons.videocam_off,
                  color: Colors.white54,
                  size: 40,
                ),
              ),
            );
          },
        ),
      );
    }

    return content;
  }
}
